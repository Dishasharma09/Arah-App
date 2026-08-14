import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../../app/theme/app_theme.dart';
import '../../models/message_model.dart';
import '../../provider/user_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/storage_service.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String otherUserId;
  final String otherUserName;
  final String taskId;       // Task being discussed (empty if not task-based)
  final String taskTitle;    // For order creation
  final String taskPrice;    // For order creation
  final bool isBuyer;        // If true, show "Assign to Seller" button

  const ChatScreen({
    super.key,
    this.chatId = '',
    this.otherUserId = '',
    this.otherUserName = 'User',
    this.taskId = '',
    this.taskTitle = '',
    this.taskPrice = '',
    this.isBuyer = false,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FirestoreService _firestoreService = FirestoreService();
  final StorageService _storageService = StorageService();
  bool _isUploading = false;
  double _uploadProgress = 0;
  String? _pendingUploadPath; // kept so a failed upload can be retried
  bool _isAssigned = false;      // Tracks if already assigned
  bool _isAssigning = false;     // Tracks assignment in progress
  String _resolvedChatId = '';   // Actual chatId (may be created on the fly)

  // --- Block / Report state ---
  bool _iBlockedThem = false;    // Current user blocked the other user
  bool _theyBlockedMe = false;   // Other user blocked the current user
  bool _checkingBlockStatus = true;
  bool get _isChatLocked => _iBlockedThem || _theyBlockedMe;

  @override
  void initState() {
    super.initState();
    _resolvedChatId = widget.chatId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initChat();
    });
  }

  Future<void> _initChat() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final uid = userProvider.uid;
    if (uid.isEmpty || widget.otherUserId.isEmpty) return;

    try {
      // Create or retrieve chat room (task-scoped if taskId provided) only if we don't have one
      String chatId = widget.chatId;
      if (chatId.isEmpty) {
        chatId = await _firestoreService.createOrGetChatRoom(
          uid,
          widget.otherUserId,
          taskId: widget.taskId.isNotEmpty ? widget.taskId : null,
        );
      }

      if (mounted) {
        setState(() {
          _resolvedChatId = chatId;
        });
      }

      // Check if already assigned
      if (widget.taskId.isNotEmpty) {
        final assigned = await _firestoreService.isChatAssigned(chatId);
        if (mounted) {
          setState(() => _isAssigned = assigned);
        }
      }

      // Check block status in both directions
      final iBlocked =
          await _firestoreService.hasUserBlocked(uid, widget.otherUserId);
      final theyBlocked =
          await _firestoreService.hasUserBlocked(widget.otherUserId, uid);
      if (mounted) {
        setState(() {
          _iBlockedThem = iBlocked;
          _theyBlockedMe = theyBlocked;
          _checkingBlockStatus = false;
        });
      }

      // Mark messages as read
await _firestoreService.markMessagesAsRead(chatId, uid);    } catch (e) {
      debugPrint('ChatScreen initChat error: $e');
      if (mounted) setState(() => _checkingBlockStatus = false);
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _sendMessage() async {
    if (_isChatLocked) return; // safety net, UI already hides input
    final text = _messageController.text.trim();
    if (text.isEmpty || _resolvedChatId.isEmpty) return;

    final userProvider = Provider.of<UserProvider>(context, listen: false);

    final message = Message(
      id: '',
      senderId: userProvider.uid,
      content: text,
      type: MessageType.text,
      timestamp: DateTime.now(),
      isRead: false,
    );

    _messageController.clear();
    await _firestoreService.sendMessage(
        _resolvedChatId, message, widget.otherUserId);
  }

  void _pickAndUploadFile() async {
    if (_isChatLocked) return;
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'png', 'pdf', 'doc', 'docx', 'zip'],
    );

    if (result != null && result.files.single.path != null) {
      await _uploadFile(result.files.single.path!);
    }
  }

  void _retryUpload() {
    if (_pendingUploadPath != null) {
      _uploadFile(_pendingUploadPath!);
    }
  }

  Future<void> _uploadFile(String filePath) async {
    setState(() {
      _isUploading = true;
      _uploadProgress = 0;
      _pendingUploadPath = filePath;
    });
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);

      String fileUrl = await _storageService.uploadChatAttachment(
        _resolvedChatId,
        filePath,
        onProgress: (progress) {
          if (mounted) setState(() => _uploadProgress = progress);
        },
      );
      final message = Message(
        id: '',
        senderId: userProvider.uid,
        content: fileUrl,
        type: MessageType.file,
        timestamp: DateTime.now(),
        isRead: false,
      );

      await _firestoreService.sendMessage(
          _resolvedChatId, message, widget.otherUserId);

      if (mounted) {
        setState(() => _pendingUploadPath = null);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload file: $e'),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: _retryUpload,
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  /// Buyer taps "Assign to Seller" — shows confirmation then commits
  void _assignToSeller() async {
    if (_isAssigned || _isAssigning || widget.taskId.isEmpty || _isChatLocked) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Assign Task?',
          style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(ctx).textTheme.titleLarge?.color),
        ),
        content: Text(
          'This will assign "${widget.taskTitle}" to ${widget.otherUserName}. '
          'It will move to your Orders page, where you\'ll pay to fund escrow before work begins.',
          style: TextStyle(color: AppTheme.colorsOf(ctx).secondaryText, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: TextStyle(color: AppTheme.colorsOf(ctx).secondaryText)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.arahPurple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Assign'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isAssigning = true);

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final buyerName = userProvider.name;
      final buyerId = userProvider.uid;

      // Get seller's name
      final sellerInfo =
          await _firestoreService.getUserBasicInfo(widget.otherUserId);
      final sellerName = sellerInfo['name'] ?? widget.otherUserName;

      await _firestoreService.assignTaskToSeller(
        taskId: widget.taskId,
        sellerId: widget.otherUserId,
        sellerName: sellerName,
        buyerId: buyerId,
        buyerName: buyerName,
        chatId: _resolvedChatId,
        taskTitle: widget.taskTitle,
        taskPrice: widget.taskPrice,
      );

      // Send a system message in chat
      final systemMsg = Message(
        id: '',
        senderId: buyerId,
        content:
            '✅ Task assigned to $sellerName! Head to your Orders page to fund escrow and track progress.',
        type: MessageType.text,
        timestamp: DateTime.now(),
        isRead: false,
      );
      await _firestoreService.sendMessage(
          _resolvedChatId, systemMsg, widget.otherUserId);

      if (mounted) {
        setState(() {
          _isAssigned = true;
          _isAssigning = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Task assigned to ${widget.otherUserName}! 🎉'),
            backgroundColor: AppTheme.colorsOf(context).success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isAssigning = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Assignment failed: $e')),
        );
      }
    }
  }

  // =====================================================================
  //  BLOCK USER
  // =====================================================================

  void _handleBlockToggle() {
    if (_iBlockedThem) {
      _confirmUnblockUser();
    } else {
      _confirmBlockUser();
    }
  }

  Future<void> _confirmBlockUser() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Block User?',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
          'You and ${widget.otherUserName} won\'t be able to message each other after this. You can unblock them later from your settings.',
          style: TextStyle(color: AppTheme.colorsOf(ctx).secondaryText, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: TextStyle(color: AppTheme.colorsOf(ctx).secondaryText)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Block'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    try {
      await _firestoreService.blockUser(
        blockerId: userProvider.uid,
        blockedId: widget.otherUserId,
      );
      if (mounted) {
        setState(() => _iBlockedThem = true);
        await userProvider.refreshBlockedUsers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${widget.otherUserName} has been blocked')),
          );

          // Offer to also report right after blocking — common flow
          _offerReportAfterBlock();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Block failed: $e')));
      }
    }
  }

  Future<void> _confirmUnblockUser() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Unblock User?',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
          'You\'ll be able to message each other again after unblocking.',
          style: TextStyle(color: AppTheme.colorsOf(ctx).secondaryText, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: TextStyle(color: AppTheme.colorsOf(ctx).secondaryText)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.arahPurple,
              foregroundColor: Colors.white,
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Unblock'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    try {
      await _firestoreService.unblockUser(
        blockerId: userProvider.uid,
        blockedId: widget.otherUserId,
      );
      if (mounted) {
        setState(() => _iBlockedThem = false);
        await userProvider.refreshBlockedUsers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${widget.otherUserName} has been unblocked')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Unblock failed: $e')));
      }
    }
  }

  void _offerReportAfterBlock() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Also report this user?',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
          'If they violated our guidelines, you can also send a report to our support team.',
          style: TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('No, thanks'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _showReportDialog();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.arahPurple,
              foregroundColor: Colors.white,
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Report'),
          ),
        ],
      ),
    );
  }

  // =====================================================================
  //  REPORT USER
  // =====================================================================

  static const List<String> _reportReasons = [
    'Offensive or inappropriate content',
    'Scam or fraud',
    'Spam / repeated messages',
    'Impersonation',
    'Threats or harassment',
    'Other',
  ];

  Future<void> _showReportDialog() async {
    String selectedReason = _reportReasons.first;
    final detailsController = TextEditingController();

    try {
      await _runReportDialog(selectedReason, detailsController);
    } finally {
      detailsController.dispose();
    }
  }

  Future<void> _runReportDialog(
      String selectedReason, TextEditingController detailsController) async {
    await showDialog(
      context: context,
      builder: (ctx) {
        bool isSubmitting = false;
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Report User',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Select a reason for reporting ${widget.otherUserName}:',
                        style: TextStyle(
                            color: AppTheme.colorsOf(ctx).secondaryText,
                            fontSize: 13)),
                    const SizedBox(height: 8),
                    ..._reportReasons.map((reason) => RadioListTile<String>(
                          value: reason,
                          groupValue: selectedReason,
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          activeColor: AppTheme.arahPurple,
                          title: Text(reason, style: const TextStyle(fontSize: 14)),
                          onChanged: (val) {
                            setDialogState(() => selectedReason = val!);
                          },
                        )),
                    const SizedBox(height: 8),
                    TextField(
                      controller: detailsController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Additional details (optional)',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.all(10),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          setDialogState(() => isSubmitting = true);
                          final userProvider = Provider.of<UserProvider>(
                              context,
                              listen: false);
                          try {
                            await _firestoreService.reportUser(
                              reporterId: userProvider.uid,
                              reportedUserId: widget.otherUserId,
                              reason: selectedReason,
                              details: detailsController.text.trim(),
                              chatId: _resolvedChatId,
                            );
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text(
                                      'Your report has been received. Our support team will review it shortly 🙏'),
                                  backgroundColor:
                                      AppTheme.colorsOf(context).success,
                                ),
                              );
                            }
                          } catch (e) {
                            setDialogState(() => isSubmitting = false);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed to send report: $e')),
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.arahPurple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('Submit Report'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = Provider.of<UserProvider>(context).uid;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
     appBar: AppBar(
  automaticallyImplyLeading: false,
  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
  surfaceTintColor: Colors.transparent,
  scrolledUnderElevation: 0,
  elevation: 0,
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppTheme.arahPurple.withOpacity(0.1),
              child: Text(
                widget.otherUserName.isNotEmpty
                    ? widget.otherUserName[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                    color: AppTheme.arahPurple, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.otherUserName,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  if (widget.taskTitle.isNotEmpty)
                    Text(
                      widget.taskTitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.colorsOf(context).secondaryText,
                        overflow: TextOverflow.ellipsis,
                      ),
                    )
                  else
                    Text(
                      'Online',
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.successGreen),
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // BUYER-ONLY: Assign to Seller button
          if (widget.isBuyer && widget.taskId.isNotEmpty && !_isChatLocked)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _isAssigned
                  ? Container(
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.colorsOf(context).successBackground,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: AppTheme.colorsOf(context).success, width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle,
                              size: 14, color: AppTheme.colorsOf(context).success),
                          const SizedBox(width: 4),
                          Text(
                            'Assigned',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.colorsOf(context).success,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ElevatedButton(
                      onPressed: _isAssigning ? null : _assignToSeller,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.arahPurple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        minimumSize: const Size(0, 34),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        elevation: 0,
                      ),
                      child: _isAssigning
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const Text(
                              'Assign to Seller',
                              style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                    ),
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 'report':
                  _showReportDialog();
                  break;
                case 'block':
                case 'unblock':
                  _handleBlockToggle();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'report', child: Text("Report User")),
              PopupMenuItem(
                value: _iBlockedThem ? 'unblock' : 'block',
                child: Text(_iBlockedThem ? 'Unblock User' : 'Block User'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (widget.taskId.isNotEmpty)
            Container(
              width: double.infinity,
              color: Theme.of(context).cardColor,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.assignment_outlined,
                      size: 14, color: AppTheme.arahPurple),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      widget.taskTitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.colorsOf(context).secondaryText,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    widget.taskPrice,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.arahPurple,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          if (!_checkingBlockStatus && _isChatLocked)
            Container(
              width: double.infinity,
              color: Colors.red.withOpacity(0.08),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.block, size: 16, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _iBlockedThem
                          ? 'You blocked ${widget.otherUserName}. No new messages can be sent or received.'
                          : 'You can\'t send messages to this user.',
                      style: const TextStyle(
                          fontSize: 12,
                          color: Colors.red,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                  if (_iBlockedThem)
                    TextButton(
                      onPressed: _confirmUnblockUser,
                      child: const Text('Unblock',
                          style: TextStyle(fontSize: 12)),
                    ),
                ],
              ),
            ),
          Expanded(
            child: _resolvedChatId.isEmpty
                ? const Center(
                    child: CircularProgressIndicator(
                        color: AppTheme.arahPurple))
                : StreamBuilder<List<Message>>(
                    stream:
                        _firestoreService.fetchMessages(_resolvedChatId),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(
                            child: CircularProgressIndicator(
                                color: AppTheme.arahPurple));
                      }
                      if (snapshot.hasError) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.error_outline,
                                    size: 44,
                                    color: AppTheme.colorsOf(context).error),
                                const SizedBox(height: 12),
                                Text(
                                  "Couldn't load messages",
                                  style: TextStyle(
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodyLarge
                                        ?.color,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  "Check your connection and try again.",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: AppTheme.colorsOf(context)
                                        .secondaryText,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      final messages = snapshot.data ?? [];

                      if (messages.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.chat_bubble_outline,
                                  size: 48,
                                  color: AppTheme.colorsOf(context).secondaryText),
                              const SizedBox(height: 12),
                              Text(
                                'Start the conversation!',
                                style: TextStyle(
                                  color: AppTheme.colorsOf(context).secondaryText,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        reverse: true,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 20),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final message =
                              messages[messages.length - 1 - index];
                          final isMe = message.senderId == currentUserId;

                          if (message.type == MessageType.file) {
                            return _buildFileBubble(message, isMe);
                          }
                          return _buildTextBubble(message, isMe);
                        },
                      );
                    },
                  ),
          ),
          if (_isUploading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      color: AppTheme.arahPurple,
                      value: _uploadProgress > 0 ? _uploadProgress : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _uploadProgress > 0
                        ? '${(_uploadProgress * 100).toStringAsFixed(0)}%'
                        : '',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.colorsOf(context).secondaryText,
                    ),
                  ),
                ],
              ),
            ),
          if (_checkingBlockStatus)
            const SizedBox.shrink()
          else if (_isChatLocked)
            const SizedBox.shrink()
          else
            _buildMessageInput(),
        ],
      ),
    );
  }

  /// Messages can only be edited within this window of being sent.
  static const Duration _editWindow = Duration(minutes: 1);

  bool _canEditMessage(Message message, bool isMe) {
    if (!isMe || message.type != MessageType.text) return false;
    return DateTime.now().difference(message.timestamp) < _editWindow;
  }

  void _onBubbleLongPress(Message message, bool isMe) {
    if (_isChatLocked) return;
    if (message.type != MessageType.text || !isMe) return;

    if (_canEditMessage(message, isMe)) {
      _showEditMessageSheet(message);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You can only edit a message within 1 minute of sending it.'),
        ),
      );
    }
  }

  Future<void> _showEditMessageSheet(Message message) async {
    final controller = TextEditingController(text: message.content);
    bool isSaving = false;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: const Text('Edit Message',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              content: TextField(
                controller: controller,
                maxLines: 4,
                minLines: 1,
                autofocus: true,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.all(10),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          final newText = controller.text.trim();
                          if (newText.isEmpty) return;

                          // Re-check the edit window at save time too, in
                          // case the dialog was left open past 1 minute.
                          if (!_canEditMessage(message, true)) {
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'The 1-minute edit window has expired.'),
                                ),
                              );
                            }
                            return;
                          }

                          if (newText == message.content) {
                            Navigator.pop(ctx);
                            return;
                          }

                          setDialogState(() => isSaving = true);
                          try {
                            await _firestoreService.editMessage(
                              chatId: _resolvedChatId,
                              messageId: message.id,
                              newContent: newText,
                            );
                            if (ctx.mounted) Navigator.pop(ctx);
                          } catch (e) {
                            setDialogState(() => isSaving = false);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed to edit message: $e')),
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.arahPurple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    // `showDialog`'s Future resolves as soon as Navigator.pop() is called,
    // but the AlertDialog (and the TextField bound to `controller`) is
    // still mounted and playing its exit/fade transition for a moment
    // after that. Disposing the controller immediately here would throw
    // "A TextEditingController was used after being disposed." while that
    // last frame renders — which is exactly the red error screen this
    // caused. Give the transition time to finish first.
    Future.delayed(const Duration(milliseconds: 300), () {
      controller.dispose();
    });
  }

  Widget _buildTextBubble(Message message, bool isMe) {
    final text = message.content;
    final timestamp = message.timestamp;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: GestureDetector(
          onLongPress: () => _onBubbleLongPress(message, isMe),
          child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isMe ? AppTheme.arahPurple : Theme.of(context).cardColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft:
                  isMe ? const Radius.circular(16) : const Radius.circular(4),
              bottomRight:
                  isMe ? const Radius.circular(4) : const Radius.circular(16),
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.colorsOf(context).shadow,
                blurRadius: 4,
                offset: const Offset(0, 2),
              )
            ],
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 16, right: 40),
                child: Text(
                  text,
                  style: TextStyle(
                    color: isMe
                        ? Colors.white
                        : Theme.of(context).textTheme.bodyLarge?.color,
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (message.isEdited) ...[
                      Text(
                        'edited',
                        style: TextStyle(
                          color: isMe
                              ? Colors.white70
                              : AppTheme.colorsOf(context).secondaryText,
                          fontSize: 10,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      DateFormat('HH:mm').format(timestamp),
                      style: TextStyle(
                        color: isMe
                            ? Colors.white70
                            : AppTheme.colorsOf(context).secondaryText,
                        fontSize: 11,
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 3),
                      _buildReadReceiptIcon(message.isRead),
                    ]
                  ],
                ),
              ),
            ],
          ),
          ),
        ),
      ),
    );
  }

  /// Sent (single check) vs read (double check, tinted) — driven purely by
  /// the message's own `isRead` field, never assumed true.
  ///
  /// `isRead` starts `false` when a message is created and is flipped to
  /// `true` by `FirestoreService.markMessagesAsRead`, which runs whenever
  /// the recipient opens this chat (see `_markAsRead`/`initState` below).
  /// That call updates every unread message sent by the OTHER user in
  /// this chat, so the tick only turns blue once they've actually opened
  /// the conversation — nothing here fakes a "read" state.
  Widget _buildReadReceiptIcon(bool isRead) {
    return Icon(
      isRead ? Icons.done_all : Icons.done,
      size: 14,
      color: isRead ? Colors.lightBlueAccent : Colors.white70,
    );
  }

  Widget _buildFileBubble(Message message, bool isMe) {
    final url = message.content;
    final timestamp = message.timestamp;
    final fileName = url.contains('%2F')
        ? Uri.decodeComponent(url.split('%2F').last.split('?').first)
        : 'Attachment';

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isMe ? AppTheme.arahPurple : Theme.of(context).cardColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft:
                  isMe ? const Radius.circular(16) : const Radius.circular(4),
              bottomRight:
                  isMe ? const Radius.circular(4) : const Radius.circular(16),
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.colorsOf(context).shadow,
                blurRadius: 4,
                offset: const Offset(0, 2),
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isMe
                      ? Colors.white.withOpacity(0.15)
                      : AppTheme.colorsOf(context).border,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.insert_drive_file,
                      color: isMe ? Colors.white : AppTheme.arahPurple,
                      size: 28,
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        fileName,
                        style: TextStyle(
                          color: isMe
                              ? Colors.white
                              : Theme.of(context).textTheme.bodyLarge?.color,
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 4, top: 4, bottom: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      DateFormat('HH:mm').format(timestamp),
                      style: TextStyle(
                        color: isMe
                            ? Colors.white70
                            : AppTheme.colorsOf(context).secondaryText,
                        fontSize: 11,
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 3),
                      _buildReadReceiptIcon(message.isRead),
                    ]
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        color: Theme.of(context).cardColor,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).inputDecorationTheme.fillColor,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const SizedBox(width: 4),
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        maxLines: 6,
                        minLines: 1,
                        decoration: const InputDecoration(
                          hintText: "Message",
                          border: InputBorder.none,
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.attach_file,
                          color: AppTheme.colorsOf(context).secondaryText, size: 22),
                      onPressed: _pickAndUploadFile,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: const BoxDecoration(
                color: AppTheme.arahPurple,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.white, size: 20),
                onPressed: _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }
}