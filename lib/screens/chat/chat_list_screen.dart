import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../app/theme/app_theme.dart';
import '../../app/widgets/bottom_nav_bar.dart';
import '../../models/chat_room_model.dart';
import '../../provider/user_provider.dart';
import '../../services/firestore_service.dart';
import 'chat_screen.dart';
import 'chatbot_screen.dart';

class ChatListScreen extends StatelessWidget {
  final bool isSeller;
  const ChatListScreen({super.key, this.isSeller = false});

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final uid = userProvider.uid;
    final firestoreService = FirestoreService();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
appBar: AppBar(
  automaticallyImplyLeading: false,
  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
  surfaceTintColor: Colors.transparent,
  scrolledUnderElevation: 0,
  elevation: 0,
        title: Text(
          'Messages',
          style: TextStyle(
            color: Theme.of(context).textTheme.titleLarge?.color,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
      ),
      bottomNavigationBar: ArahBottomNavBar(
        currentIndex: 2,
        isSeller: isSeller,
      ),
      body: StreamBuilder<List<ChatRoom>>(
        stream: firestoreService.fetchChatRooms(uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.arahPurple),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 48, color: AppTheme.colorsOf(context).secondaryText),
                  const SizedBox(height: 12),
                  Text(
                    'Failed to load chats',
                    style: TextStyle(color: AppTheme.colorsOf(context).secondaryText, fontSize: 16),
                  ),
                ],
              ),
            );
          }

          final chats = snapshot.data ?? [];

          if (chats.isEmpty) {
            return _buildEmptyState(context);
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: chats.length + 1,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              indent: 80,
              endIndent: 16,
              color: Theme.of(context).dividerColor,
            ),
            itemBuilder: (context, index) {
              if (index == 0) {
                return InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ChatbotScreen(),
                      ),
                    );
                  },
                  child: Container(
                    color: Theme.of(context).cardColor,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: AppTheme.arahPurple.withOpacity(0.12),
                          child: const Icon(
                            Icons.psychology,
                            color: AppTheme.arahPurple,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Arah Assistant",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: Theme.of(context).textTheme.bodyLarge?.color,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                "Ask me anything! I can assist with Arah App...",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.colorsOf(context).secondaryText,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          "Active",
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.successGreen,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final chat = chats[index - 1];
              final otherUid = chat.participants.firstWhere(
                (p) => p != uid,
                orElse: () => '',
              );

              return FutureBuilder<Map<String, String>>(
                future: firestoreService.getUserBasicInfo(otherUid),
                builder: (context, infoSnap) {
                  final name = infoSnap.data?['name'] ?? '...';
                  final photoUrl = infoSnap.data?['photoUrl'] ?? '';
                  final unread = chat.unreadCounts[uid] ?? 0;

                  return _buildChatTile(
                    
                    context: context,
                    chat: chat,
                    otherUid: otherUid,
                    name: name,
                    photoUrl: photoUrl,
                    unread: unread,
                    currentUid: uid,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

Widget _buildChatTile({
  required BuildContext context,
  required ChatRoom chat,
  required String otherUid,
  required String name,
  required String photoUrl,
  required int unread,
  required String currentUid,
}) {
  final timeString = _formatTime(chat.lastMessageTimestamp);

  String preview = chat.lastMessage;

  if (chat.lastMessageSenderId == currentUid) {
    preview = "You: ${chat.lastMessage}";
  }

  // Current user is the buyer when this screen is not seller mode.
  final hasBuyerContext = !isSeller;

  return InkWell(
    onTap: () async {
      // Mark this chat as read first.
      try {
        await FirestoreService().markMessagesAsRead(
          chat.id,
          currentUid,
        );
      } catch (e) {
        debugPrint(
          'Failed to mark chat messages as read: $e',
        );
      }

      if (!context.mounted) return;

      // Then open the actual selected chat.
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            chatId: chat.id,
            otherUserId: otherUid,
            otherUserName: name,
            isBuyer: hasBuyerContext,
          ),
        ),
      );
    },
    child: Container(
      color: Theme.of(context).cardColor,
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 12,
      ),
      child: Row(
        children: [
          // Avatar
          Stack(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor:
                    AppTheme.arahPurple.withOpacity(0.12),
                backgroundImage: photoUrl.isNotEmpty
                    ? NetworkImage(photoUrl)
                    : null,
                child: photoUrl.isEmpty
                    ? Text(
                        name.isNotEmpty
                            ? name[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: AppTheme.arahPurple,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      )
                    : null,
              ),

              // Unread badge
              if (unread > 0)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: const BoxDecoration(
                      color: AppTheme.arahPurple,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        unread > 9 ? '9+' : '$unread',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(width: 14),

          // Name & last message
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontWeight: unread > 0
                        ? FontWeight.bold
                        : FontWeight.w600,
                    fontSize: 15,
                    color: Theme.of(context)
                        .textTheme
                        .bodyLarge
                        ?.color,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  preview.isNotEmpty
                      ? preview
                      : 'No messages yet',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: unread > 0
                        ? Theme.of(context)
                            .textTheme
                            .bodyLarge
                            ?.color
                        : AppTheme.colorsOf(context)
                            .secondaryText,
                    fontWeight: unread > 0
                        ? FontWeight.w500
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Timestamp
          Text(
            timeString,
            style: TextStyle(
              fontSize: 12,
              color: unread > 0
                  ? AppTheme.arahPurple
                  : AppTheme.colorsOf(context)
                      .secondaryText,
              fontWeight: unread > 0
                  ? FontWeight.w600
                  : FontWeight.normal,
            ),
          ),
        ],
      ),
    ),
  );
}


  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.arahPurple.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.chat_bubble_outline,
              size: 36,
              color: AppTheme.arahPurple,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No conversations yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start a chat by tapping "Message to Bid"\nor "Contact Seller" on a task.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.colorsOf(context).secondaryText,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) {
      return DateFormat('HH:mm').format(dt);
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return DateFormat('EEE').format(dt);
    } else {
      return DateFormat('dd/MM').format(dt);
    }
  }
}
