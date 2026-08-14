import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/message_model.dart';
import '../models/chat_room_model.dart';
import '../models/user_model.dart';
import '../models/task_model.dart';
import 'package:flutter/foundation.dart';
import '../models/notification_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ─── USER PROFILE ──────────────────────────────────────────────────────────

Future<void> createUserProfile(
  String uid,
  Map<String, dynamic> data,
) async {
  data['nameLower'] = (data['name'] ?? '').toString().toLowerCase();

  await _db.collection('users').doc(uid).set(
    data,
    SetOptions(merge: true),
  );
}

  Future<UserModel?> getUserProfile(String uid) async {
  try {
    final doc = await _db.collection('users').doc(uid).get();

    print("Document exists = ${doc.exists}");

    print(doc.data());

    if (!doc.exists) return null;

    return UserModel.fromMap(doc.data()!, doc.id);
  } catch (e, s) {
    print("Firestore error");
    print(e);
    print(s);
    rethrow;
  }
}

Future<void> updateUserProfile(
  String uid,
  Map<String, dynamic> data,
) async {
  if (data.containsKey('name')) {
    data['nameLower'] = data['name'].toString().toLowerCase();
  }

  await _db.collection('users').doc(uid).update(data);
}
  /// Get another user's basic info (name, photoUrl) for chat list display
  Future<Map<String, String>> getUserBasicInfo(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (!doc.exists) return {'name': 'Unknown', 'photoUrl': ''};
      final data = doc.data()!;
      return {
        'name': data['name'] ?? 'Unknown',
        'photoUrl': data['photoUrl'] ?? '',
      };
    } catch (_) {
      return {'name': 'Unknown', 'photoUrl': ''};
    }
  }

  // ─── TASKS ─────────────────────────────────────────────────────────────────

  /// Stream all open tasks (used internally)
  Stream<List<TaskModel>> fetchOpenTasksStream() {
    return _db
        .collection('tasks')
        .where('status', isEqualTo: 'open')
        .snapshots()
        .map((snap) {
          final list = snap.docs.map((d) => TaskModel.fromMap(d.data(), d.id)).toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  /// Stream open tasks, excluding tasks posted by [excludeBuyerId].
  /// Used for the Buyer home feed (so buyers don't see their own tasks).
  /// Also used for Seller feed (sellers never see own tasks).
  Stream<List<TaskModel>> fetchOpenTasksExcluding(String excludeUserId) {
    return _db
        .collection('tasks')
        .where('status', isEqualTo: 'open')
        .snapshots()
        .map((snap) {
          final list = snap.docs
              .map((d) => TaskModel.fromMap(d.data(), d.id))
              .where((task) => task.buyerId != excludeUserId)
              .toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  /// Stream tasks posted by a specific buyer (for Buyer's own task management)
  Stream<List<TaskModel>> fetchBuyerTasksStream(String buyerId) {
    return _db
        .collection('tasks')
        .where('buyerId', isEqualTo: buyerId)
        .snapshots()
        .map((snap) {
          final list = snap.docs.map((d) => TaskModel.fromMap(d.data(), d.id)).toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

// ─── NOTIFICATIONS ───────────────────────────────
Future<void> createOrUpdateMessageNotification({
  required String userId,
  required String senderId,
  required String senderName,
  required String chatId,
  required String body,
}) async {
  final notificationsRef = _db.collection('notifications');

  final existingSnapshot = await notificationsRef
      .where('userId', isEqualTo: userId)
      .where('senderId', isEqualTo: senderId)
      .where('chatId', isEqualTo: chatId)
      .where('type', isEqualTo: 'message')
      .where('isRead', isEqualTo: false)
      .limit(1)
      .get();

  if (existingSnapshot.docs.isNotEmpty) {
    final doc = existingSnapshot.docs.first;
    final data = doc.data();

    final currentCount =
        (data['messageCount'] as num?)?.toInt() ?? 1;

    await doc.reference.update({
      'messageCount': currentCount + 1,
      'body': body,
      'senderName': senderName,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return;
  }

  await notificationsRef.add({
    'userId': userId,
    'senderId': senderId,
    'senderName': senderName,
    'chatId': chatId,
    'title': 'New Messages',
    'body': body,
    'type': 'message',
    'messageCount': 1,
    'isRead': false,
    'createdAt': FieldValue.serverTimestamp(),
  });
}
Future<void> createNotification({
  required String userId,
  required String title,
  required String body,
  required String type,
  String? chatId,
  String? senderId,
}) async {
  await _db.collection('notifications').add({
    'userId': userId,
    'title': title,
    'body': body,
    'type': type,
    'isRead': false,
    'createdAt': FieldValue.serverTimestamp(),

    if (chatId != null) 'chatId': chatId,
    if (senderId != null) 'senderId': senderId,
  });
}

Stream<List<NotificationModel>> fetchNotifications(String userId) {
  return _db
      .collection('notifications')
      .where('userId', isEqualTo: userId)
      .snapshots()
      .map((snapshot) {
        final notifications = snapshot.docs
            .map(
              (doc) => NotificationModel.fromMap(
                doc.data(),
                doc.id,
              ),
            )
            .toList();

        notifications.sort(
          (a, b) => b.createdAt.compareTo(a.createdAt),
        );

        return notifications;
      });
}

Future<void> markNotificationAsRead(String id) async {

  await _db
      .collection('notifications')
      .doc(id)
      .update({
        'isRead': true,
      });

}

/// Notify every Seller (or dual-role "Both") user that a new task was
/// posted, so they can see it as a new opportunity.
/// NOTE: for Sprint 2 scope this loops over matching users and writes one
/// notification doc per user via the existing createNotification() call —
/// no new batching/queueing architecture is introduced.
Future<void> _notifyNewOpportunity(Map<String, dynamic> taskData) async {
  final taskTitle = taskData['title'] ?? 'A new task';
  final excludeBuyerId = taskData['buyerId'] ?? '';

  final sellersSnap = await _db
      .collection('users')
      .where('role', whereIn: ['Seller', 'Both'])
      .get();

  for (final doc in sellersSnap.docs) {
    if (doc.id == excludeBuyerId) continue;
    await createNotification(
      userId: doc.id,
      title: 'New Opportunity',
      body: 'A new task "$taskTitle" was just posted.',
      type: 'opportunity',
    );
  }
}







// Block user
Future<void> blockUser({
  required String blockerId,
  required String blockedId,
}) async {
  await _db
      .collection('users')
      .doc(blockerId)
      .collection('blockedUsers')
      .doc(blockedId)
      .set({
        'blockedUserId': blockedId,
        'createdAt': FieldValue.serverTimestamp(),
      });
}


// Unblock user
Future<void> unblockUser({
  required String blockerId,
  required String blockedId,
}) async {
  await _db
      .collection('users')
      .doc(blockerId)
      .collection('blockedUsers')
      .doc(blockedId)
      .delete();
}


// Check if blocked
Future<bool> hasUserBlocked(
  String blockerId,
  String blockedId,
) async {
  final doc = await _db
      .collection('users')
      .doc(blockerId)
      .collection('blockedUsers')
      .doc(blockedId)
      .get();

  return doc.exists;
}

// List everyone [blockerId] has blocked, most recently blocked first.
// Used by the standalone "Blocked Users" management screen and to filter
// blocked people out of the task feed / user search on the home screens.
Future<List<String>> getBlockedUserIds(String blockerId) async {
  final snapshot = await _db
      .collection('users')
      .doc(blockerId)
      .collection('blockedUsers')
      .orderBy('createdAt', descending: true)
      .get();

  return snapshot.docs.map((d) => d.id).toList();
}

  Future<String> createTask(Map<String, dynamic> taskData) async {
    final ref = await _db.collection('tasks').add(taskData);
    await _notifyNewOpportunity(taskData);
    return ref.id;
  }

  Future<void> createTaskWithId(String taskId, Map<String, dynamic> taskData) async {
    await _db.collection('tasks').doc(taskId).set(taskData);
    await _notifyNewOpportunity(taskData);
  }

  Future<void> updateTaskStatus(String taskId, String status) async {
    await _db.collection('tasks').doc(taskId).update({'status': status});
  }

  // ─── ORDERS ────────────────────────────────────────────────────────────────

  Stream<QuerySnapshot> fetchUserOrders(String uid, List<String> statuses) {
    return _db
        .collection('orders')
        .where('buyerId', isEqualTo: uid)
        .where('status', whereIn: statuses)
        .snapshots();
  }

  Stream<QuerySnapshot> fetchSellerOrders(String uid, List<String> statuses) {
    return _db
        .collection('orders')
        .where('sellerId', isEqualTo: uid)
        .where('status', whereIn: statuses)
        .snapshots();
  }

  Future<String> createOrder(Map<String, dynamic> orderData) async {
    final ref = await _db.collection('orders').add(orderData);
    return ref.id;
  }

  Future<void> updateOrderStatus(String orderId, String status) async {
    await _db.collection('orders').doc(orderId).update({'status': status});
  }

  /// Atomic: assign task to seller → creates order + updates task status
  Future<void> assignTaskToSeller({
    required String taskId,
    required String sellerId,
    required String sellerName,
    required String buyerId,
    required String buyerName,
    required String chatId,
    required String taskTitle,
    required String taskPrice,
  }) async {
    final batch = _db.batch();

    // Update task: set status to in_progress and record sellerId
    final taskRef = _db.collection('tasks').doc(taskId);
    batch.update(taskRef, {
      'status': 'in_progress',
      'sellerId': sellerId,
    });

    // Create order document
    final orderRef = _db.collection('orders').doc();
    batch.set(orderRef, {
      'title': taskTitle,
      'price': taskPrice,
      'clientName': sellerName,   // from Buyer's perspective: seller is the client/worker
      'clientId': sellerId,
      'buyerId': buyerId,
      'buyerName': buyerName,
      'sellerId': sellerId,
      'sellerName': sellerName,
      'taskId': taskId,
      'chatId': chatId,
      'status': 'AwaitingPayment',
      'ratedByBuyer': false,
      'ratedBySeller': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Update chat room with assignment context
    final chatRef = _db.collection('chats').doc(chatId);
    batch.update(chatRef, {
      'taskId': taskId,
      'isAssigned': true,
    });

    await batch.commit();
  }

  /// Seller takes an order on a buyer's task
  Future<void> placeTaskOrder({
    required TaskModel task,
    required String sellerId,
    required String sellerName,
  }) async {
    final batch = _db.batch();

    // Add seller to orderTakers list in task and mark as in_progress
    final taskRef = _db.collection('tasks').doc(task.id);
    batch.update(taskRef, {
      'orderTakers': FieldValue.arrayUnion([sellerId]),
      'orderTakerNames': FieldValue.arrayUnion([sellerName]),
      'status': 'in_progress',
      'sellerId': sellerId,
    });

    // Create order document
    // In this workflow:
    // The buyer is the person who created the task (task.buyerId)
    // The seller is the person taking the order (sellerId)
    final orderRef = _db.collection('orders').doc();
    batch.set(orderRef, {
      'title': task.title,
      'price': task.price,
      'clientName': task.buyerName, // To the seller, the client is the task creator (buyer)
      'clientId': task.buyerId,
      'buyerId': task.buyerId, // Task creator is the buyer
      'buyerName': task.buyerName,
      'sellerId': sellerId, // The person taking the order is the seller
      'sellerName': sellerName,
      'taskId': task.id,
      'chatId': '', // No chat associated initially
      'status': 'PendingApproval',
      'ratedByBuyer': false,
      'ratedBySeller': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();

    // Notify the task owner/buyer that someone applied to their task.
    await createNotification(
      userId: task.buyerId,
      title: 'New Application',
      body: '$sellerName applied to your task "${task.title}"',
      type: 'application',
    );
  }

  /// Accept an order request
Future<void> acceptOrderRequest(String orderId) async {
  final orderRef = _db.collection('orders').doc(orderId);
  final orderSnap = await orderRef.get();
  final orderData = orderSnap.data();

  await orderRef.update({
    'status': 'AwaitingPayment',
  });

  // Notify the applicant/seller that their request was accepted.
  if (orderData != null) {
    final sellerId = orderData['sellerId'] ?? '';
    final title = orderData['title'] ?? 'your task';
    if (sellerId.toString().isNotEmpty) {
      await createNotification(
        userId: sellerId,
        title: 'Request Accepted',
        body:
            'Your request for "$title" has been accepted. Waiting for buyer payment.',
        type: 'accepted',
      );
    }
  }
}

  /// Buyer pays for the order: funds move into escrow.
  Future<void> payOrder(String orderId) async {
    final orderRef = _db.collection('orders').doc(orderId);
    final orderSnap = await orderRef.get();
    final orderData = orderSnap.data();

    await orderRef.update({
      'status': 'InEscrow',
      'paidAt': FieldValue.serverTimestamp(),
    });

    if (orderData != null) {
      final sellerId = orderData['sellerId'] ?? '';
      final title = orderData['title'] ?? 'your task';
      if (sellerId.toString().isNotEmpty) {
        await createNotification(
          userId: sellerId,
          title: 'Payment Received',
          body:
              'Payment for "$title" is now held in escrow. You can start work.',
          type: 'payment',
        );
      }
    }
  }

  /// Seller marks the order as delivered — awaiting buyer approval to release funds.
  Future<void> markOrderDelivered(String orderId) async {
    final orderRef = _db.collection('orders').doc(orderId);
    final orderSnap = await orderRef.get();
    final orderData = orderSnap.data();

    await orderRef.update({
      'status': 'Delivered',
      'deliveredAt': FieldValue.serverTimestamp(),
    });

    if (orderData != null) {
      final buyerId = orderData['buyerId'] ?? '';
      final title = orderData['title'] ?? 'your task';
      if (buyerId.toString().isNotEmpty) {
        await createNotification(
          userId: buyerId,
          title: 'Work Delivered',
          body:
              '"$title" has been marked as delivered. Review and approve to release payment.',
          type: 'delivered',
        );
      }
    }
  }

  /// Buyer approves delivered work: releases escrowed funds (minus platform commission)
  /// to the seller and marks the order + task as completed.
  Future<void> releaseOrderPayment(String orderId, String taskId) async {
    final orderSnap = await _db.collection('orders').doc(orderId).get();
    final orderData = orderSnap.data();

    final batch = _db.batch();
    batch.update(_db.collection('orders').doc(orderId), {
      'status': 'Completed',
      'releasedAt': FieldValue.serverTimestamp(),
      'completedAt': FieldValue.serverTimestamp(),
    });
    batch.update(_db.collection('tasks').doc(taskId), {'status': 'completed'});
    await batch.commit();

    if (orderData != null) {
      final sellerId = orderData['sellerId'] ?? '';
      final title = orderData['title'] ?? 'your task';
      if (sellerId.toString().isNotEmpty) {
        await createNotification(
          userId: sellerId,
          title: 'Payment Released',
          body:
              'Payment for "$title" has been released to you (after 9% platform commission).',
          type: 'released',
        );
      }
    }
  }

  /// Refunds the buyer: returns escrowed funds and frees up the task for reassignment.
  Future<void> refundOrder(String orderId, String taskId,
      {String reason = ''}) async {
    final orderSnap = await _db.collection('orders').doc(orderId).get();
    final orderData = orderSnap.data();

    final batch = _db.batch();
    batch.update(_db.collection('orders').doc(orderId), {
      'status': 'Refunded',
      'refundedAt': FieldValue.serverTimestamp(),
      'refundReason': reason,
    });
    batch.update(_db.collection('tasks').doc(taskId), {
      'status': 'open',
      'sellerId': '',
    });
    await batch.commit();

    if (orderData != null) {
      final sellerId = orderData['sellerId'] ?? '';
      final buyerId = orderData['buyerId'] ?? '';
      final title = orderData['title'] ?? 'your task';
      if (sellerId.toString().isNotEmpty) {
        await createNotification(
          userId: sellerId,
          title: 'Order Refunded',
          body: 'The order for "$title" was refunded to the buyer.',
          type: 'refunded',
        );
      }
      if (buyerId.toString().isNotEmpty) {
        await createNotification(
          userId: buyerId,
          title: 'Refund Processed',
          body: 'Your payment for "$title" has been refunded.',
          type: 'refunded',
        );
      }
    }
  }



  /// Reject an order request
  Future<void> rejectOrderRequest(String orderId) async {
    final orderRef = _db.collection('orders').doc(orderId);
    final orderSnap = await orderRef.get();
    final orderData = orderSnap.data();

    await orderRef.update({'status': 'Rejected'});

    // Notify the applicant/seller that their request was rejected.
    if (orderData != null) {
      final sellerId = orderData['sellerId'] ?? '';
      final title = orderData['title'] ?? 'your task';
      if (sellerId.toString().isNotEmpty) {
        await createNotification(
          userId: sellerId,
          title: 'Request Rejected',
          body: 'Your request for "$title" has been rejected.',
          type: 'rejected',
        );
      }
    }
  }

  /// Complete an order: update order status + task status.
  /// Also stamps `completedAt` so UserStatsService can compute a real
  /// average completion time later (createdAt -> completedAt delta).
  Future<void> completeOrder(String orderId, String taskId) async {
    final orderSnap = await _db.collection('orders').doc(orderId).get();
    final orderData = orderSnap.data();

    final batch = _db.batch();
    batch.update(_db.collection('orders').doc(orderId), {
      'status': 'Completed',
      'completedAt': FieldValue.serverTimestamp(),
    });
    batch.update(_db.collection('tasks').doc(taskId), {'status': 'completed'});
    await batch.commit();

    // Notify the other involved user (the seller) that the task was updated.
    if (orderData != null) {
      final sellerId = orderData['sellerId'] ?? '';
      final title = orderData['title'] ?? 'your task';
      if (sellerId.toString().isNotEmpty) {
        await createNotification(
          userId: sellerId,
          title: 'Task Updated',
          body: 'The task "$title" has been marked as completed.',
          type: 'task_update',
        );
      }
    }
  }

Future<List<UserModel>> searchUsers(String query) async {
  if (query.isEmpty) return [];

  final search = query.toLowerCase();

  print("Searching for: $search");

  final snapshot = await _db
      .collection('users')
      .orderBy('nameLower')
      .startAt([search])
      .endAt(['$search\uf8ff'])
      .limit(10)
      .get();

  print("Found: ${snapshot.docs.length}");

  var results = snapshot.docs
      .map((doc) => UserModel.fromMap(doc.data(), doc.id))
      .toList();

  if (results.isNotEmpty) return results;

  final fallbackSnapshot = await _db.collection('users').limit(200).get();

  print("All users: ${fallbackSnapshot.docs.length}");

  for (var doc in fallbackSnapshot.docs) {
    print(doc.data());
  }

  results = fallbackSnapshot.docs
      .map((doc) => UserModel.fromMap(doc.data(), doc.id))
      .where((user) => user.name.toLowerCase().contains(search))
      .take(10)
      .toList();

  print("Fallback found: ${results.length}");

  return results;
}
  /// Reassign: delete order + reset task status to "open", clear sellerId
  Future<void> reassignTask(String orderId, String taskId) async {
    final batch = _db.batch();
    batch.delete(_db.collection('orders').doc(orderId));
    batch.update(_db.collection('tasks').doc(taskId), {
      'status': 'open',
      'sellerId': '',
    });
    await batch.commit();
  }

  /// Save a rating and review, update the rated user's average rating
  Future<void> saveRating({
    required String orderId,
    required String ratedUserId,
    required String raterId,
    required double rating,
    required bool isBuyerRating, // true = buyer is rating the seller
    String reviewText = '',
  }) async {
    final batch = _db.batch();

    // Mark the order as rated
    final orderField = isBuyerRating ? 'ratedByBuyer' : 'ratedBySeller';
    batch.update(_db.collection('orders').doc(orderId), {orderField: true});

    // Add rating to the rated user's ratings subcollection
    final ratingRef = _db
        .collection('users')
        .doc(ratedUserId)
        .collection('ratings')
        .doc();
    batch.set(ratingRef, {
      'rating': rating,
      'reviewText': reviewText,
      'raterId': raterId,
      'orderId': orderId,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();

    // Update average rating (not in batch — needs a read first)
    try {
      final ratingsSnap = await _db
          .collection('users')
          .doc(ratedUserId)
          .collection('ratings')
          .get();
      if (ratingsSnap.docs.isNotEmpty) {
        final avg = ratingsSnap.docs
                .map((d) => (d.data()['rating'] as num).toDouble())
                .reduce((a, b) => a + b) /
            ratingsSnap.docs.length;
        await _db.collection('users').doc(ratedUserId).update({
          'avgRating': avg,
          'ratingCount': ratingsSnap.docs.length,
        });
      }
    } catch (e) {
      // Non-critical — rating saved, average update failed
    }
  }

  // ─── CHAT ──────────────────────────────────────────────────────────────────

  /// Stream chat rooms for a user (for ChatListScreen)
  Stream<List<ChatRoom>> fetchChatRooms(String userId) {
    return _db
        .collection('chats')
        .where('participants', arrayContains: userId)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .map((doc) => ChatRoom.fromMap(doc.data(), doc.id))
              .toList();
          list.sort((a, b) => b.lastMessageTimestamp.compareTo(a.lastMessageTimestamp));
          return list;
        });
  }

  /// Create or retrieve a chat room, returns chatId
Future<String> createOrGetChatRoom(
  String currentUid,
  String otherUid, {
  String? taskId,
}) async {
  final chatId = currentUid.compareTo(otherUid) < 0
      ? '${currentUid}_$otherUid'
      : '${otherUid}_$currentUid';

  final chatRef = FirebaseFirestore.instance
      .collection('chats')
      .doc(chatId);

  final snapshot = await chatRef.get();

  if (!snapshot.exists) {
await chatRef.set({
  'participants': [
    currentUid,
    otherUid,
  ],
  'createdAt': FieldValue.serverTimestamp(),
  'lastMessage': '',
  'lastMessageSenderId': '',
  'lastMessageTimestamp': FieldValue.serverTimestamp(),
  'unreadCounts': {
    currentUid: 0,
    otherUid: 0,
  },
  if (taskId != null) 'taskId': taskId,
});
  }

  return chatId;
}









  /// Check if a chat room is already assigned
  Future<bool> isChatAssigned(String chatId) async {
    try {
      final doc = await _db.collection('chats').doc(chatId).get();
      if (!doc.exists) return false;
      return doc.data()?['isAssigned'] == true;
    } catch (_) {
      return false;
    }
  }

  /// Stream messages for a chat
  Stream<List<Message>> fetchMessages(String chatId) {
    return _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Message.fromMap(doc.data(), doc.id))
            .toList());
  }

Future<void> reportUser({
  required String reporterId,
  required String reportedUserId,
  required String reason,
  required String details,
  required String chatId,
}) async {
  await FirebaseFirestore.instance.collection('reports').add({
    'reporterId': reporterId,
    'reportedUserId': reportedUserId,
    'reason': reason,
    'details': details,
    'chatId': chatId,
    'createdAt': FieldValue.serverTimestamp(),
    'status': 'pending',
  });
}





















  /// Send a message
Future<void> sendMessage(
  String chatId,
  Message message,
  String receiverId,
) async {
  final chatRef = _db.collection('chats').doc(chatId);
  final messagesRef = chatRef.collection('messages');

  // Add message
  await messagesRef.add(message.toMap());

  // Update chat metadata
  await chatRef.update({
    'lastMessage': message.type == MessageType.text
        ? message.content
        : 'Attachment',
    'lastMessageSenderId': message.senderId,
    'lastMessageTimestamp': FieldValue.serverTimestamp(),
    'unreadCounts.$receiverId': FieldValue.increment(1),
  });

  // Get sender name
  final senderDoc = await _db
      .collection('users')
      .doc(message.senderId)
      .get();

  final senderName =
      senderDoc.data()?['name']?.toString() ?? 'User';

  // Create/update ONE grouped notification
  await createOrUpdateMessageNotification(
    userId: receiverId,
    senderId: message.senderId,
    senderName: senderName,
    chatId: chatId,
    body: message.type == MessageType.text
        ? message.content
        : 'Sent you an attachment',
  );
}

  

  /// Mark messages as read
/// Mark messages as read
/// Mark all messages in a chat as read for the current user.
Future<void> markMessagesAsRead(
  String chatId,
  String userId,
) async {
  try {
    final chatRef = _db.collection('chats').doc(chatId);

    // Reset the unread badge for this user.
    await chatRef.update({
      'unreadCounts.$userId': 0,
    });

    debugPrint(
      'Unread count reset for user $userId in chat $chatId',
    );

    // Flip the per-message read flag for every message the OTHER user
    // sent that this user hasn't seen yet. This is what drives the
    // sent/read (single-check vs double-check) receipt in ChatScreen —
    // without this, isRead stayed false forever and every message
    // looked "sent" even after being opened.
    final unreadMessagesSnapshot = await chatRef
        .collection('messages')
        .where('isRead', isEqualTo: false)
        .get();

    final theirUnreadDocs = unreadMessagesSnapshot.docs
        .where((doc) => doc.data()['senderId'] != userId);

    if (theirUnreadDocs.isNotEmpty) {
      final messagesBatch = _db.batch();

      for (final doc in theirUnreadDocs) {
        messagesBatch.update(doc.reference, {'isRead': true});
      }

      await messagesBatch.commit();
    }

    // Mark the grouped message notification as read.
    final notificationsSnapshot = await _db
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('type', isEqualTo: 'message')
        .where('chatId', isEqualTo: chatId)
        .where('isRead', isEqualTo: false)
        .get();

    if (notificationsSnapshot.docs.isNotEmpty) {
      final batch = _db.batch();

      for (final doc in notificationsSnapshot.docs) {
        batch.update(doc.reference, {
          'isRead': true,
        });
      }

      await batch.commit();
    }

    debugPrint(
      'Messages marked as read successfully for $userId in $chatId',
    );
  } catch (e, stack) {
    debugPrint('markMessagesAsRead ERROR: $e');
    debugPrint('$stack');
    rethrow;
  }
}

  /// Edit a text message's content. Callers are responsible for enforcing
  /// the 1-minute edit window client-side (using the message's existing
  /// `timestamp`) before calling this — this method does not re-check it,
  /// same as the rest of this service's write methods.
  Future<void> editMessage({
    required String chatId,
    required String messageId,
    required String newContent,
  }) async {
    await _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .update({
      'content': newContent,
      'isEdited': true,
    });
  }
Future<void> sendFeedback({
  required String userId,
  required String subject,
  required String message,
}) async {
  await _db.collection('feedback').add({
    'userId': userId,
    'subject': subject,
    'message': message,
    'timestamp': FieldValue.serverTimestamp(),
    'appVersion': '1.0.0',
  });
}

}

