import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
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
  bool _isAssigned = false;      // Tracks if already assigned
  bool _isAssigning = false;     // Tracks assignment in progress
  String _resolvedChatId = '';   // Actual chatId (may be created on the fly)
  bool _isInitialLoadComplete = false;

  // Simplified real-time fields
  List<Message> _messages = [];
  ScrollController _scrollController = ScrollController();
  StreamSubscription<QuerySnapshot>? _messagesSubscription;

  @override
  void initState() {
    super.initState();
    _resolvedChatId = widget.chatId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initChat();
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _messagesSubscription?.cancel();
    super.dispose();
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

      // Mark messages as read
      _firestoreService.markMessagesAsRead(chatId, uid);

      // Set up the real-time listener for all messages
      _setupMessagesListener();
    } catch (e) {
      debugPrint('ChatScreen initChat error: $e');
      if (mounted) {
        setState(() {
          _isInitialLoadComplete = true; // To avoid showing spinner forever on error
        });
      }
    }
  }

  void _setupMessagesListener() {
    if (_resolvedChatId.isEmpty || !mounted) return;

    final messagesStream = _firestoreService.db
        .collection('chats')
        .doc(_resolvedChatId)
        .collection('messages')
        .orderBy('timestamp', descending: false) // ascending order (oldest first)
        .snapshots();

    _messagesSubscription = messagesStream.listen((snapshot) {
      if (!mounted) return;

      final List<Message> messages = snapshot.docs
          .map((doc) => Message.fromMap(doc.data(), doc.id))
          .toList();

      setState(() {
        _messages = messages;
        _isInitialLoadComplete = true;

        // Scroll to bottom to show latest messages
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      });
    });
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _resolvedChatId.isEmpty) return;

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final senderId = userProvider.uid;
    final senderName = userProvider.name;

    if (senderId.isEmpty) return;

    // Create a temporary message ID
    final messageId = _firestoreService.db
        .collection('chats')
        .doc(_resolvedChatId)
        .collection('messages')
        .doc()
        .id;

    final message = Message(
      id: messageId,
      senderId: senderId,
      senderName: senderName,
      content: text,
      type: MessageType.text,
      timestamp: DateTime.now(),
      isRead: false,
    );

    try {
      await _firestoreService.sendMessage(_resolvedChatId, message, widget.otherUserId);
      _messageController.clear();
    } catch (e) {
      debugPrint('Error sending message: $e');
      if (mounted) {
        _showToast('Failed to send message');
      }
    }
  }

  Future<void> _pickAndUploadFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'png', 'pdf', 'doc', 'docx', 'zip'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() => _isUploading = true);
      try {
        final filePath = result.files.single.path!;
        final userProvider = Provider.of<UserProvider>(context, listen: false);

        String fileUrl = await _storageService.uploadChatAttachment(
            _resolvedChatId, filePath);

        final message = Message(
          id: '',
          senderId: userProvider.uid,
          senderName: userProvider.name,
          content: fileUrl,
          type: MessageType.file,
          timestamp: DateTime.now(),
          isRead: false,
        );

        await _firestoreService.sendMessage(
            _resolvedChatId, message, widget.otherUserId);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to upload file: $e')));
        }
      } finally {
        if (mounted) setState(() => _isUploading = false);
      }
    }
  }

  void _showToast(String message) {
    if (!mounted) return;
    try {
      final overlay = Overlay.of(context);
      if (!mounted) return;
      final entry = OverlayEntry(
        builder: (context) => Positioned(
          bottom: MediaQuery.of(context).size.height * 0.1,
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Text(
                  message,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
        ),
      );
      overlay.insert(entry);
      Future.delayed(const Duration(seconds: 2)).then((_) {
        if (mounted) {
          entry.remove();
        }
      });
    } catch (e) {
      // Ignore errors related to overlay
      if (kDebugMode) print('Error showing toast: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = Provider.of<UserProvider>(context).uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: AppTheme.pureWhite,
        foregroundColor: AppTheme.navyBlue,
        titleSpacing: 0,
        elevation: 0,
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
                        color: Colors.blueGrey.shade500,
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
          if (widget.isBuyer && widget.taskId.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _isAssigned
                  ? Container(
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border:
                            Border.all(color: const Color(0xFF10B981), width: 1),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle,
                              size: 14, color: Color(0xFF10B981)),
                          SizedBox(width: 4),
                          Text(
                            'Assigned',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF10B981),
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
          PopupMenuButton(
            icon: const Icon(Icons.more_vert),
            itemBuilder: (context) => [
              const PopupMenuItem(
                  value: 'report', child: Text("Report User")),
              const PopupMenuItem(value: 'block', child: Text("Block User")),
            ],
            onSelected: (value) async {
              if (value == 'report') {
                // Show report dialog
                await _showReportDialog();
              } else if (value == 'block') {
                // TODO: Implement block user functionality
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Block user functionality coming soon')),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (widget.taskId.isNotEmpty)
            Container(
              width: double.infinity,
              color: Colors.white,
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
                        color: Colors.blueGrey.shade600,
                        fontWeight: FontWeight.w500,
                        overflow: TextOverflow.ellipsis,
                      ),
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
          Expanded(
            child: _resolvedChatId.isEmpty
                ? const Center(
                    child: CircularProgressIndicator(
                        color: AppTheme.arahPurple))
                : !_isInitialLoadComplete
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: AppTheme.arahPurple))
                    : Column(
                        children: [
                          // Message list
                          Expanded(
                            child: ListView.builder(
                              controller: _scrollController,
                              itemCount: _messages.length,
                              itemBuilder: (context, index) {
                                final message = _messages[index];
                                final isMe = message.senderId == currentUserId;

                                if (message.type == MessageType.file) {
                                  return _buildFileBubble(
                                      message.content, isMe, message.timestamp);
                                }
                                return _buildTextBubble(
                                    message.content, isMe, message.timestamp, message.senderName);
                              },
                            ),
                          ),
                        ],
                      ),
          ),
          if (_isUploading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 4),
              child:
                  LinearProgressIndicator(color: AppTheme.arahPurple),
            ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildTextBubble(String text, bool isMe, DateTime timestamp, String senderName) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          decoration: BoxDecoration(
            color: isMe ? AppTheme.arahPurple : Colors.white,
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
                color: Colors.black.withOpacity(0.04),
                blurRadius: 4,
                offset: const Offset(0, 2),
              )
            ],
          ),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.8,
          ),
          child: Column(
            crossAxisAlignment:
                isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Text(
                text,
                style: TextStyle(
                  color: isMe ? Colors.white : Colors.black,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment:
                    isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                children: [
                  if (!isMe)
                    Text(
                      senderName,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  Text(
                    DateFormat('hh:mm a').format(timestamp),
                    style: TextStyle(
                      fontSize: 12,
                      color: isMe ? Colors.white70 : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFileBubble(String url, bool isMe, DateTime timestamp) {
    final fileName = url.contains('%2F')
        ? Uri.decodeComponent(url.split('%2F').last.split('?').first)
        : 'Attachment';

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isMe ? AppTheme.arahPurple : Colors.white,
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
                color: Colors.black.withOpacity(0.04),
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
                      : const Color(0xFFF1F5F9),
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
                          color: isMe ? Colors.white : AppTheme.navyBlue,
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
                        color: isMe ? Colors.white70 : Colors.grey.shade600,
                        fontSize: 11,
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 3),
                      const Icon(Icons.done_all,
                          size: 14, color: Colors.white70),
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
        color: Colors.white,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
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
                      icon: const Icon(Icons.attach_file,
                          color: Colors.grey, size: 22),
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

  Future<void> _showReportDialog() async {
    final TextEditingController descriptionController = TextEditingController();
    String? selectedOption;

    final List<String> reportReasons = [
      'Harassment or bullying',
      'Hate speech or discrimination',
      'Scam or fraud',
      'Inappropriate content',
      'Spam',
      'Other'
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report User'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedOption,
                decoration: const InputDecoration(
                  labelText: 'Reason for reporting',
                  border: OutlineInputBorder(),
                ),
                items: reportReasons.map((reason) => DropdownMenuItem(
                  value: reason,
                  child: Text(reason),
                )).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedOption = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Please provide details about the issue...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              debugPrint('[ReportDialog] Submit button pressed');
              if (selectedOption == null) {
                debugPrint('[ReportDialog] No reason selected');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please select a reason')),
                  );
                }
                return;
              }
              debugPrint('[ReportDialog] Reason selected: $selectedOption');
              debugPrint('[ReportDialog] Description: ${descriptionController.text}');

              // Show loading snackbar BEFORE popping the dialog
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Submitting report...')),
                );
              }
              // Close dialog
              if (mounted) {
                Navigator.of(context).pop();
              }

              try {
                debugPrint('[ReportDialog] Calling reportUser...');
                // Report the user using FirestoreService
                await _firestoreService.reportUser(
                  reporterId: Provider.of<UserProvider>(context, listen: false).uid,
                  reportedUserId: widget.otherUserId,
                  reason: selectedOption!, // We know it's not null due to the check above
                  description: descriptionController.text,
                );
                debugPrint('[ReportDialog] reportUser succeeded');

                if (mounted) {
                  _showToast('Report submitted successfully');
                }
              } catch (e, stackTrace) {
                debugPrint('[ReportDialog] reportUser failed: $e');
                debugPrint('[ReportDialog] Stack trace: $stackTrace');
                if (mounted) {
                  _showToast('Failed to submit report: $e');
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.arahPurple,
            ),
            child: const Text('Submit Report'),
          ),
        ],
      ),
    );
  }

  void _assignToSeller() async {
    if (_isAssigned || _isAssigning || widget.taskId.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Assign Task?',
          style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.navyBlue),
        ),
        content: Text(
          'This will assign "${widget.taskTitle}" to ${widget.otherUserName}. '
          'The task will be locked to them and move to your Orders page.',
          style: TextStyle(color: Colors.blueGrey.shade700, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: TextStyle(color: Colors.blueGrey.shade500)),
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
        senderName: buyerName,
        content:
            '✅ Task assigned to $sellerName! Check your Orders page to track progress.',
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
            backgroundColor: const Color(0xFF10B981),
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
}