import 'dart:async';

import 'package:flutter/material.dart';

import '../models/notification_model.dart';
import '../services/firestore_service.dart';

class NotificationProvider extends ChangeNotifier {
  final FirestoreService _service = FirestoreService();

  List<NotificationModel> _notifications = [];

  List<NotificationModel> get notifications => _notifications;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  bool _hasError = false;
  bool get hasError => _hasError;

  String? _lastUid;

  StreamSubscription<List<NotificationModel>>? _sub;

  void listenNotifications(String uid) {
    if (uid.isEmpty) return;

    _lastUid = uid;

    // Cancel previous listener
    _sub?.cancel();

    _isLoading = true;
    _hasError = false;

    notifyListeners();

    _sub = _service.fetchNotifications(uid).listen(
      (data) {
        _notifications = data;

        _isLoading = false;
        _hasError = false;

        notifyListeners();
      },
      onError: (error) {
        debugPrint(
          'NotificationProvider stream error: $error',
        );

        _isLoading = false;
        _hasError = true;

        notifyListeners();
      },
    );
  }

  /// Retry after an error using the last authenticated user.
  void retry() {
    final uid = _lastUid;

    if (uid != null && uid.isNotEmpty) {
      listenNotifications(uid);
    }
  }

  /// Number of unread notification cards.
  ///
  /// A grouped message notification counts as ONE notification,
  /// even if it represents multiple messages.
  int get unreadCount {
    return _notifications
        .where((notification) => !notification.isRead)
        .length;
  }

  /// Mark one notification as read.
  Future<void> readNotification(String id) async {
    try {
      // Update local state immediately.
      _notifications = _notifications.map((notification) {
        if (notification.id == id) {
          return NotificationModel(
            id: notification.id,
            userId: notification.userId,
            title: notification.title,
            message: notification.message,
            type: notification.type,
            createdAt: notification.createdAt,
            isRead: true,
            chatId: notification.chatId,
            senderId: notification.senderId,
            senderName: notification.senderName,
            messageCount: notification.messageCount,
          );
        }

        return notification;
      }).toList();

      notifyListeners();

      // Persist to Firestore.
      await _service.markNotificationAsRead(id);
    } catch (e) {
      debugPrint(
        'NotificationProvider readNotification error: $e',
      );

      // The Firestore snapshot will eventually restore the
      // correct state if the write failed.
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}