import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../app/theme/app_theme.dart';
import '../../models/notification_model.dart';
import '../../provider/notification_provider.dart';
import '../../provider/user_provider.dart';

import '../chat/chat_list_screen.dart';
import '../chat/chat_screen.dart';
import '../orders/my_orders_screen.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  IconData _iconForType(String type) {
    switch (type) {
      case 'opportunity':
        return Icons.work_outline;

      case 'application':
        return Icons.person_add_alt_1_outlined;

      case 'accepted':
        return Icons.check_circle_outline;

      case 'rejected':
        return Icons.cancel_outlined;

      case 'message':
        return Icons.chat_bubble_outline;

      case 'task_update':
        return Icons.update;

      case 'payment':
        return Icons.lock_outline;

      case 'delivered':
        return Icons.local_shipping_outlined;

      case 'released':
        return Icons.payments_outlined;

      case 'refunded':
        return Icons.replay_outlined;

      default:
        return Icons.notifications_none;
    }
  }

  Color _colorForType(
    BuildContext context,
    String type,
  ) {
    final colors = AppTheme.colorsOf(context);

    switch (type) {
      case 'accepted':
        return colors.success;

      case 'rejected':
        return colors.error;

      case 'task_update':
        return colors.warning;

      case 'payment':
        return colors.info;

      case 'delivered':
        return colors.warning;

      case 'released':
        return colors.success;

      case 'refunded':
        return colors.error;

      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) {
      return 'Just now';
    }

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    }

    if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    }

    if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    }

    return DateFormat('MMM d').format(dt);
  }

  void _handleTap(
    BuildContext context,
    NotificationModel notification,
  ) {
    // Mark as read
    context
        .read<NotificationProvider>()
        .readNotification(notification.id);

    final isSeller =
        context.read<UserProvider>().currentMode == 'Seller';

    switch (notification.type) {
      case 'message':
        final chatId = notification.chatId;

        if (chatId == null || chatId.isEmpty) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatListScreen(
                isSeller: isSeller,
              ),
            ),
          );
          return;
        }

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              chatId: chatId,
              otherUserId: notification.senderId ?? '',
              otherUserName:
                  notification.senderName ?? 'User',
            ),
          ),
        );
        break;

      case 'opportunity':
      case 'application':
      case 'accepted':
      case 'rejected':
      case 'task_update':
      case 'payment':
      case 'delivered':
      case 'released':
      case 'refunded':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MyOrdersScreen(
              isSeller: isSeller,
            ),
          ),
        );
        break;

      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider =
        context.watch<NotificationProvider>();

    final colors =
        AppTheme.colorsOf(context);

    return Scaffold(
      backgroundColor:
          Theme.of(context).scaffoldBackgroundColor,

      appBar: AppBar(
        backgroundColor:
            Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,

        title: Text(
          'Notifications',
          style: TextStyle(
            color: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.color,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),

      body: SafeArea(
        child: _buildBody(
          context,
          provider,
          colors,
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    NotificationProvider provider,
    AppColors colors,
  ) {
    if (provider.isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppTheme.arahPurple,
        ),
      );
    }

    if (provider.hasError) {
      return Center(
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 32),

          child: Column(
            mainAxisAlignment:
                MainAxisAlignment.center,

            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: colors.error,
              ),

              const SizedBox(height: 12),

              Text(
                "Couldn't load notifications",
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
                'Check your connection and try again.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.secondaryText,
                  fontSize: 13,
                ),
              ),

              const SizedBox(height: 16),

              ElevatedButton(
                onPressed: provider.retry,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      AppTheme.arahPurple,
                  foregroundColor: Colors.white,
                  shape:
                      RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (provider.notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,

          children: [
            Icon(
              Icons.notifications_none,
              size: 56,
              color: colors.secondaryText,
            ),

            const SizedBox(height: 12),

            Text(
              'No Notifications',
              style: TextStyle(
                color: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.color,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),

            const SizedBox(height: 4),

            Text(
              "You're all caught up.",
              style: TextStyle(
                color: colors.secondaryText,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),

      itemCount: provider.notifications.length,

      itemBuilder: (context, index) {
        final notification =
            provider.notifications[index];

        final typeColor =
            _colorForType(
          context,
          notification.type,
        );

        final isUnread =
            !notification.isRead;

        final isMessage =
            notification.type == 'message';

        String displayMessage;

        if (isMessage) {
          final sender =
              notification.senderName ?? 'User';

          if (notification.messageCount > 1) {
            displayMessage =
                'You have ${notification.messageCount} new messages from $sender';
          } else {
            displayMessage =
                'You have a new message from $sender';
          }
        } else {
          displayMessage =
              notification.message;
        }

        return Container(
          margin:
              const EdgeInsets.only(bottom: 10),

          decoration: BoxDecoration(
            color: isUnread
                ? AppTheme.arahPurple
                    .withOpacity(0.06)
                : Theme.of(context).cardColor,

            borderRadius:
                BorderRadius.circular(14),

            border: Border.all(
              color: isUnread
                  ? AppTheme.arahPurple
                      .withOpacity(0.25)
                  : colors.border,
            ),
          ),

          child: Material(
            color: Colors.transparent,

            borderRadius:
                BorderRadius.circular(14),

            child: InkWell(
              borderRadius:
                  BorderRadius.circular(14),

              onTap: () => _handleTap(
                context,
                notification,
              ),

              child: Padding(
                padding:
                    const EdgeInsets.all(14),

                child: Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,

                  children: [
                    CircleAvatar(
                      radius: 20,

                      backgroundColor:
                          typeColor
                              .withOpacity(0.12),

                      child: Icon(
                        _iconForType(
                          notification.type,
                        ),
                        color: typeColor,
                        size: 20,
                      ),
                    ),

                    const SizedBox(width: 12),

                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,

                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  notification.type ==
                                          'message'
                                      ? 'New Messages'
                                      : notification.title,

                                  style: TextStyle(
                                    color: Theme.of(
                                            context)
                                        .textTheme
                                        .bodyLarge
                                        ?.color,

                                    fontWeight:
                                        isUnread
                                            ? FontWeight.bold
                                            : FontWeight.w500,

                                    fontSize: 14,
                                  ),
                                ),
                              ),

                              if (isUnread)
                                Container(
                                  width: 8,
                                  height: 8,
                                  margin:
                                      const EdgeInsets.only(
                                    left: 8,
                                    top: 4,
                                  ),

                                  decoration:
                                      const BoxDecoration(
                                    color: AppTheme
                                        .arahPurple,
                                    shape:
                                        BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),

                          const SizedBox(height: 4),

                          Text(
                            displayMessage,

                            maxLines: 2,
                            overflow:
                                TextOverflow.ellipsis,

                            style: TextStyle(
                              color:
                                  colors.secondaryText,
                              fontSize: 13,
                              height: 1.35,
                            ),
                          ),

                          const SizedBox(height: 6),

                          Text(
                            _formatTimestamp(
                              notification.createdAt,
                            ),

                            style: TextStyle(
                              color: colors
                                  .secondaryText
                                  .withOpacity(0.8),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}