import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/message_model.dart';
import '../models/chat_room_model.dart';
import '../models/user_model.dart';
import '../models/task_model.dart';
import '../models/report_model.dart'; // Add this import
import 'package:flutter/foundation.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Constant for report cooldown duration (24 hours)
  static const Duration _reportCooldown = Duration(hours: 24);

  // ─── USER PROFILE ──────────────────────────────────────────────────────────

  Future<void> createUserProfile(String uid, Map<String, dynamic> data) async {
    await _db.collection('users').doc(uid).set(data, SetOptions(merge: true));
  }

  Future<UserModel?> getUserProfile(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromMap(doc.data()!, doc.id);
  }

  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async {
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

  Future<String> createTask(Map<String, dynamic> taskData) async {
    final ref = await _db.collection('tasks').add(taskData);
    return ref.id;
  }

  Future<void> createTaskWithId(String taskId, Map<String, dynamic> taskData) async {
    await _db.collection('tasks').doc(taskId).set(taskData);
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
      'status': 'Pending',
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
      'status': 'Pending',
      'ratedByBuyer': false,
      'ratedBySeller': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  /// Accept an order request
  Future<void> acceptOrderRequest(String orderId) async {
    await _db.collection('orders').doc(orderId).update({'status': 'Pending'});
  }

  /// Reject an order request
  Future<void> rejectOrderRequest(String orderId) async {
    await _db.collection('orders').doc(orderId).update({'status': 'Rejected'});
  }

  /// Complete an order: update order status + task status
  Future<void> completeOrder(String orderId, String taskId) async {
    final batch = _db.batch();
    batch.update(_db.collection('orders').doc(orderId), {'status': 'Completed'});
    batch.update(_db.collection('tasks').doc(taskId), {'status': 'completed'});
    await batch.commit();
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
      String user1Id, String user2Id, {String? taskId}) async {
    List<String> uids = [user1Id, user2Id];
    uids.sort();
    // If taskId is provided, make chat room unique per task
    String chatId = taskId != null
        ? "${uids[0]}_${uids[1]}_$taskId"
        : "${uids[0]}_${uids[1]}";

    final docRef = _db.collection('chats').doc(chatId);
    final docSnap = await docRef.get();

    if (!docSnap.exists) {
      await docRef.set({
        'participants': [user1Id, user2Id],
        'lastMessage': '',
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
        'unreadCounts': {user1Id: 0, user2Id: 0},
        if (taskId != null) 'taskId': taskId,
        'isAssigned': false,
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

  /// Send a message
  Future<void> sendMessage(
      String chatId, Message message, String receiverId) async {
    final chatRef = _db.collection('chats').doc(chatId);
    final messagesRef = chatRef.collection('messages');

    await messagesRef.add(message.toMap());

    await chatRef.update({
      'lastMessage': message.type == MessageType.text
          ? message.content
          : 'Attachment',
      'lastMessageTimestamp': FieldValue.serverTimestamp(),
      'unreadCounts.$receiverId': FieldValue.increment(1),
    });
  }

  /// Mark messages as read
  Future<void> markMessagesAsRead(String chatId, String userId) async {
    await _db.collection('chats').doc(chatId).update({
      'unreadCounts.$userId': 0,
    });
  }

  // ─── REPORTS ────────────────────────────────────────────────────────────────

  /// Reports a user for inappropriate behavior or content.
  /// Throws an exception if validation fails or if a duplicate report exists within the cooldown period.
  Future<void> reportUser({
    required String reporterId,
    required String reportedUserId,
    required String reason,
    required String description,
    String? evidenceUrl, // Optional: URL to stored evidence (e.g., screenshot)
  }) async {
    debugPrint('FirestoreService.reportUser called: reporterId=$reporterId, reportedUserId=$reportedUserId, reason=$reason');
    // 1. Validate inputs
    if (reporterId == reportedUserId) {
      debugPrint('FirestoreService: Self-report attempt blocked');
      throw Exception('You cannot report yourself.');
    }
    if (reason.trim().isEmpty) {
      debugPrint('FirestoreService: Reason empty');
      throw Exception('Please provide a reason for the report.');
    }
    if (description.trim().isEmpty) {
      debugPrint('FirestoreService: Description empty');
      throw Exception('Please provide a description of the issue.');
    }
    // Optional: validate reason against a list of allowed reasons if desired

    // 2. Check for duplicate report within the cooldown window
    final cutoff = DateTime.now().subtract(_reportCooldown);
    debugPrint('FirestoreService: Checking for recent reports since $cutoff');
    final recentReports = await _db
        .collection('reports')
        .where('reporterId', isEqualTo: reporterId)
        .where('reportedUserId', isEqualTo: reportedUserId)
        .where('createdAt', isGreaterThan: Timestamp.fromDate(cutoff))
        .limit(1)
        .get();

    if (recentReports.docs.isNotEmpty) {
      debugPrint('FirestoreService: Recent report found, blocking duplicate');
      throw Exception(
          'You have already reported this user recently. Please wait before submitting another report.');
    }

    // 3. Create the report document
    // Note: Firestore automatically creates the 'reports' collection if it doesn't exist
    final reportRef = _db.collection('reports').doc();
    debugPrint('FirestoreService: Creating report document with ID ${reportRef.id}');
    final reportData = ReportModel(
      id: reportRef.id,
      reporterId: reporterId,
      reportedUserId: reportedUserId,
      reason: reason.trim(),
      description: description.trim(),
      evidenceUrl: evidenceUrl,
      status: 'Pending', // initial status
      reviewedBy: null,
      reviewedAt: null,
      resolutionNote: null,
    );

    try {
      await reportRef.set(reportData.toMap());
      debugPrint('FirestoreService: Report saved successfully');
    } catch (e) {
      debugPrint('FirestoreService: Error saving report: $e');
      rethrow;
    }
  }

  /// Updates the status of a report (typically called by a moderator/admin).
  /// [reviewedBy] is the ID of the moderator performing the review.
  /// [resolutionNote] is optional notes about the outcome.
  Future<void> updateReportStatus({
    required String reportId,
    required String status, // Expected: 'Pending', 'Under Review', 'Resolved', 'Rejected'
    String? reviewedBy,
    String? resolutionNote,
  }) async {
    // Validate status
    final validStatuses = ['Pending', 'Under Review', 'Resolved', 'Rejected'];
    if (!validStatuses.contains(status)) {
      throw Exception('Invalid status: $status');
    }

    final updateData = {
      'status': status,
      if (reviewedBy != null) 'reviewedBy': reviewedBy,
      if (reviewedBy != null) 'reviewedAt': FieldValue.serverTimestamp(),
      if (resolutionNote != null) 'resolutionNote': resolutionNote,
    };

    await _db.collection('reports').doc(reportId).update(updateData);
  }

  /// Optional: Stream reports for moderation UI (e.g., for admins/mods)
  /// [limit] is optional; if null, no limit.
  Stream<List<ReportModel>> streamReportsModeration({int? limit}) {
    var query = _db.collection('reports').orderBy('createdAt', descending: true);
    if (limit != null) {
      query = query.limit(limit);
    }
    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => ReportModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  /// Optional: Get a single report by ID
  Future<ReportModel?> getReportById(String reportId) async {
    final doc = await _db.collection('reports').doc(reportId).get();
    if (!doc.exists) return null;
    return ReportModel.fromMap(doc.data()!, doc.id);
  }
}