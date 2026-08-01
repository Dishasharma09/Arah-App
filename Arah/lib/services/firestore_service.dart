import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/message_model.dart';
import '../models/chat_room_model.dart';
import '../models/user_model.dart';
import '../models/task_model.dart';
import '../models/report_model.dart';
import 'package:flutter/foundation.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  FirebaseFirestore get db => _db;

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

  // ─── TASKS ─────────────────────────────────────────────────────────────

  /// Stream all open tasks (used internally)
  Stream<List<TaskModel>> fetchOpenTasksStream() {
    return _db
        .collection('tasks')
        .where('status', isEqualTo: 'open')
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((d) => TaskModel.fromMap(d.data(), d.id))
          .toList();
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
      final list = snap.docs
          .map((d) => TaskModel.fromMap(d.data(), d.id))
          .toList();
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

  // ─── ORDERS ────────────────────────────────────────────────────────────

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
  /// Uses a transaction to ensure atomicity and prevent duplicate ratings
  Future<void> saveRating({
    required String orderId,
    required String ratedUserId,
    required String raterId,
    required double rating,
    required bool isBuyerRating, // true = buyer is rating the seller
    String reviewText = '',
  }) async {
    debugPrint('FirestoreService.saveRating called: orderId=$orderId, ratedUserId=$ratedUserId, raterId=$raterId, rating=$rating, isBuyerRating=$isBuyerRating');

    // 1. Validate inputs
    if (orderId.trim().isEmpty) {
      throw Exception('Order ID is required');
    }
    if (ratedUserId.trim().isEmpty) {
      throw Exception('Rated user ID is required');
    }
    if (raterId.trim().isEmpty) {
      throw Exception('Rater ID is required');
    }
    if (raterId == ratedUserId) {
      throw Exception('You cannot rate yourself');
    }
    if (rating < 1 || rating > 5) {
      throw Exception('Rating must be between 1 and 5');
    }
    if (reviewText.length > 500) {
      throw Exception('Review text cannot exceed 500 characters');
    }

    // 2. Use a transaction to ensure atomicity and prevent duplicate ratings
    try {
      await _db.runTransaction((transaction) async {
        // Get the order document to check if already rated by this user
        final orderDoc = await transaction.get(_db.collection('orders').doc(orderId));
        if (!orderDoc.exists) {
          throw Exception('Order not found');
        }

        final orderData = orderDoc.data() as Map<String, dynamic>;
        final orderRaterField = isBuyerRating ? 'ratedByBuyer' : 'ratedBySeller';

        // Check if already rated by this user
        if (orderData[orderRaterField] == true) {
          throw Exception('You have already rated this order');
        }

        // Mark the order as rated
        transaction.update(orderDoc.reference, {orderRaterField: true});

        // Add rating to the rated user's ratings subcollection
        final ratingRef = _db
            .collection('users')
            .doc(ratedUserId)
            .collection('ratings')
            .doc();

        transaction.set(ratingRef, {
          'rating': rating,
          'reviewText': reviewText.trim(),
          'raterId': raterId,
          'orderId': orderId,
          'isBuyerRating': isBuyerRating, // Track who gave the rating
          'createdAt': FieldValue.serverTimestamp(),
        });

        debugPrint('FirestoreService: Rating saved successfully for user $ratedUserId');
      });
    } catch (e) {
      debugPrint('FirestoreService: Error saving rating: $e');
      rethrow;
    }

    // 3. Update average rating outside the transaction (requires reading all ratings)
    try {
      final ratingsSnap = await _db
          .collection('users')
          .doc(ratedUserId)
          .collection('ratings')
          .get();

      if (ratingsSnap.docs.isNotEmpty) {
        // Filter out any null or invalid ratings
        final validRatings = ratingsSnap.docs
            .map((doc) => doc.data())
            .where((data) => data['rating'] != null)
            .map((data) => (data['rating'] as num).toDouble())
            .toList();

        if (validRatings.isNotEmpty) {
          final avg = validRatings.reduce((a, b) => a + b) / validRatings.length;
          await _db
              .collection('users')
              .doc(ratedUserId)
              .update({
                'avgRating': avg,
                'ratingCount': validRatings.length,
              });
        }
      }
    } catch (e) {
      debugPrint('Warning: Failed to update average rating for user $ratedUserId: $e');
      // Non-critical — rating saved, average update failed
      // We don't rethrow because the rating itself was saved successfully
    }
  }

  // ─── CHAT ────────────────────────────────────────────────────────────────

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

  /// Stream messages for a chat (for real-time updates)
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

  /// Fetch a page of messages for a chat, ordered by timestamp (oldest first)
  /// [limit] is the number of messages to fetch
  /// [startAfterDocument] is the document to start after (for pagination)
  Future<QuerySnapshot> fetchMessagesPage(String chatId, int limit,
      {DocumentSnapshot? startAfterDocument}) async {
    Query query = _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .limit(limit);

    if (startAfterDocument != null) {
      query = query.startAfterDocument(startAfterDocument);
    }

    return query.get();
  }

  /// Send a message
  Future<void> sendMessage(
      String chatId, Message message, String receiverId) async {
    final chatRef = _db.collection('chats').doc(chatId);
    final messagesRef = chatRef.collection('messages');

    // Get sender's name for denormalization
    final senderInfo = await getUserBasicInfo(message.senderId);
    final messageWithSenderName = Message(
      id: message.id,
      senderId: message.senderId,
      senderName: senderInfo['name'] ?? 'Unknown User',
      content: message.content,
      type: message.type,
      timestamp: message.timestamp,
      isRead: message.isRead,
    );

    await messagesRef.add(messageWithSenderName.toMap());

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

  /// Fetch messages that come after the given document (in ascending order by timestamp)
  /// Used for listening to new messages
  Future<QuerySnapshot> fetchMessagesAfter({
    required String chatId,
    required int limit,
    required DocumentSnapshot afterDocument,
  }) async {
    Query query = _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: false) // ascending
        .startAfterDocument(afterDocument);
    return query.limit(limit).get();
  }

  /// Fetch messages that come before the given document (in ascending order by timestamp)
  /// Used for loading older messages
  Future<QuerySnapshot> fetchMessagesBefore({
    required String chatId,
    required int limit,
    required DocumentSnapshot beforeDocument,
  }) async {
    Query query = _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: false) // ascending
        .endBeforeDocument(beforeDocument);
    return query.limit(limit).get();
  }

  // ─── REPORTS ─────────────────────────────────────────────────────────────

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

    // Validate reason against allowed values
    final validReasons = [
      'harassment',
      'hate_speech',
      'fake_profile',
      'spam',
      'inappropriate_content',
      'illegal_activities',
      'other'
    ];

    // Normalize reason: trim, lowercase, and standardize format
    String normalizedReason = reason.trim().toLowerCase();

    // Map common UI reason phrases to internal values
    final reasonMap = {
      'harassment': 'harassment',
      'hate speech': 'hate_speech',
      'hate speech or discrimination': 'hate_speech',
      'hate speech/discrimination': 'hate_speech',
      'hate speech and discrimination': 'hate_speech',
      'fake profile': 'fake_profile',
      'spam': 'spam',
      'inappropriate content': 'inappropriate_content',
      'illegal activities': 'illegal_activities',
      'other': 'other'
    };

    // Try direct mapping first
    if (reasonMap.containsKey(normalizedReason)) {
      normalizedReason = reasonMap[normalizedReason]!;
    } else {
      // Fallback: convert spaces/hyphens to underscores
      normalizedReason = normalizedReason
          .replaceAll(RegExp(r'[-\s]+'), '_')
          .replaceAll(RegExp(r'_+'), '_');
    }

    if (!validReasons.contains(normalizedReason)) {
      debugPrint('FirestoreService: Invalid reason provided: $reason');
      throw Exception('Invalid reason provided: "$reason". Valid reasons are: harassment, hate_speech, fake_profile, spam, inappropriate_content, illegal_activities, other');
    }

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
      reason: normalizedReason, // Store normalized reason
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

  /// Optional: Get a report by ID
  Future<ReportModel?> getReportById(String reportId) async {
    final doc = await _db.collection('reports').doc(reportId).get();
    if (!doc.exists) return null;
    return ReportModel.fromMap(doc.data()!, doc.id);
  }

  // ─── BLOCK/UNBLOCK USER ────────────────────────────────────────────────

  /// Block a user by setting isBlocked to true
  /// Only admins/moderators should be able to call this
  Future<void> blockUser(String userId) async {
    // Validate that the user exists
    final userDoc = await _db.collection('users').doc(userId).get();
    if (!userDoc.exists) {
      throw Exception('User not found: $userId');
    }

    // Update the user's isBlocked field
    await _db.collection('users').doc(userId).update({
      'isBlocked': true,
      'blockedAt': FieldValue.serverTimestamp(), // Optional: track when blocked
    });
  }

  /// Block a user securely via Cloud Function (admin/moderator only)
  Future<void> blockUserSecure(String userId) async {
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('blockUser')
          .call(<String, dynamic>{'uid': userId});
      return result.data;
    } on FirebaseFunctionsException catch (e) {
      throw FirebaseException(
        plugin: 'firebase-functions',
        code: e.code,
        message: e.message,
      );
    }
  }

  /// Unblock a user by setting isBlocked to false
  /// Only admins/moderators should be able to call this
  Future<void> unblockUser(String userId) async {
    // Validate that the user exists
    final userDoc = await _db.collection('users').doc(userId).get();
    if (!userDoc.exists) {
      throw Exception('User not found: $userId');
    }

    // Update the user's isBlocked field
    await _db.collection('users').doc(userId).update({
      'isBlocked': false,
      'unblockedAt': FieldValue.serverTimestamp(), // Optional: track when unblocked
      // Optionally clear the blockedAt timestamp
      'blockedAt': FieldValue.delete(),
    });
  }

  /// Unblock a user securely via Cloud Function (admin/moderator only)
  Future<void> unblockUserSecure(String userId) async {
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('unblockUser')
          .call(<String, dynamic>{'uid': userId});
      return result.data;
    } on FirebaseFunctionsException catch (e) {
      throw FirebaseException(
        plugin: 'firebase-functions',
        code: e.code,
        message: e.message,
      );
    }
  }
}