import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/order_model.dart';
import '../services/firestore_service.dart';

class OrderProvider with ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();

  // Order state management
  List<OrderModel> _userOrders = [];
  List<OrderModel> _sellerOrders = [];
  bool _isLoading = false;
  String? _errorMessage;
  StreamSubscription<QuerySnapshot>? _orderSubscription;

  // Getters
  List<OrderModel> get userOrders => _userOrders;
  List<OrderModel> get sellerOrders => _sellerOrders;
  List<OrderModel> get activeOrders => _userOrders.where((order) =>
      order.status == 'Pending' ||
      order.status == 'in_progress' ||
      order.status == 'Completed').toList();
  List<OrderModel> get completedOrders => _userOrders.where((order) =>
      order.status == 'Completed' ||
      order.status == 'Refunded').toList();
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Fetch orders for the current user (as buyer)
  Future<void> fetchUserOrders(String userId, List<String> statuses) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final querySnapshot = await _firestoreService
          .db
          .collection('orders')
          .where('buyerId', isEqualTo: userId)
          .where('status', whereIn: statuses)
          .get();

      _userOrders = querySnapshot.docs
          .map((doc) => OrderModel.fromMap(doc.data(), doc.id))
          .toList();

      // Sort by creation date (newest first)
      _userOrders.sort((a, b) =>
          (b.paidAt ?? b.escrowReleasedAt ?? DateTime.now())
              .compareTo(a.paidAt ?? a.escrowReleasedAt ?? DateTime.now()));
    } catch (e) {
      _errorMessage = 'Failed to fetch user orders: $e';
      debugPrint('OrderProvider.fetchUserOrders error: $_errorMessage');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Fetch orders for the current user (as seller)
  Future<void> fetchSellerOrders(String userId, List<String> statuses) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final querySnapshot = await _firestoreService
          .db
          .collection('orders')
          .where('sellerId', isEqualTo: userId)
          .where('status', whereIn: statuses)
          .get();

      _sellerOrders = querySnapshot.docs
          .map((doc) => OrderModel.fromMap(doc.data(), doc.id))
          .toList();

      // Sort by creation date (newest first)
      _sellerOrders.sort((a, b) =>
          (b.paidAt ?? b.escrowReleasedAt ?? DateTime.now())
              .compareTo(a.paidAt ?? a.escrowReleasedAt ?? DateTime.now()));
    } catch (e) {
      _errorMessage = 'Failed to fetch seller orders: $e';
      debugPrint('OrderProvider.fetchSellerOrders error: $_errorMessage');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Subscribe to order updates (real-time)
  void subscribeToOrders(String userId, {required bool isSeller}) {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    // Cancel any existing subscription
    _orderSubscription?.cancel();

    try {
      final statuses = ['Pending', 'in_progress', 'Completed', 'Refunded'];
      Stream<QuerySnapshot> stream;
      if (isSeller) {
        stream = _firestoreService.fetchSellerOrders(userId, statuses);
      } else {
        stream = _firestoreService.fetchUserOrders(userId, statuses);
      }

      _orderSubscription = stream.listen(
        (querySnapshot) {
          _updateOrdersFromSnapshot(querySnapshot, isSeller);
        },
        onError: (e) {
          debugPrint('OrderProvider stream error: $e');
          _isLoading = false;
          _errorMessage = 'Failed to listen to orders: $e';
          notifyListeners();
        },
      );
    } catch (e) {
      _errorMessage = 'Failed to subscribe to orders: $e';
      debugPrint('OrderProvider.subscribeToOrders error: $_errorMessage');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Reassign order: delete order + reset task status to "open", clear sellerId
  Future<bool> reassignOrder(String orderId, String taskId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _firestoreService.reassignTask(orderId, taskId);
      return true;
    } catch (e) {
      _errorMessage = 'Failed to reassign order: $e';
      debugPrint('OrderProvider.reassignOrder error: $_errorMessage');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Reject an order
  Future<bool> rejectOrder(String orderId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _firestoreService.updateOrderStatus(orderId, 'Rejected');
      return true;
    } catch (e) {
      _errorMessage = 'Failed to reject order: $e';
      debugPrint('OrderProvider.rejectOrder error: $_errorMessage');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Accept an order
  Future<bool> acceptOrder(String orderId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _firestoreService.updateOrderStatus(orderId, 'Pending');
      return true;
    } catch (e) {
      _errorMessage = 'Failed to accept order: $e';
      debugPrint('OrderProvider.acceptOrder error: $_errorMessage');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Save a rating for an order
  Future<bool> saveRating({
    required String orderId,
    required String ratedUserId,
    required String raterId,
    required double rating,
    required bool isBuyerRating, // true = buyer is rating the seller
    String reviewText = '',
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _firestoreService.saveRating(
        orderId: orderId,
        ratedUserId: ratedUserId,
        raterId: raterId,
        rating: rating,
        isBuyerRating: isBuyerRating,
        reviewText: reviewText,
      );
      return true;
    } catch (e) {
      _errorMessage = 'Failed to save rating: $e';
      debugPrint('OrderProvider.saveRating error: $_errorMessage');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Place a new order (when seller takes a task)
  Future<String?> placeTaskOrder({
    required String taskId,
    required String taskTitle,
    required String taskPrice,
    required String buyerId,
    required String buyerName,
    required String sellerId,
    required String sellerName,
    required String chatId,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Calculate commission and payout
      const double commissionPercentage = 15.0;
      final double priceDouble = double.tryParse(taskPrice.replaceAll('���₹', '')) ?? 0.0;
      final double commissionAmount = (priceDouble * commissionPercentage / 100);
      final double payoutAmount = priceDouble - commissionAmount;

      // Create order document
      final orderRef = await _firestoreService.db.collection('orders').add({
        'title': taskTitle,
        'price': taskPrice,
        'clientName': buyerName, // To the seller, the client is the buyer
        'clientId': buyerId,
        'buyerId': buyerId,
        'buyerName': buyerName,
        'sellerId': sellerId,
        'sellerName': sellerName,
        'taskId': taskId,
        'chatId': chatId,
        'status': 'Pending',
        'ratedByBuyer': false,
        'ratedBySeller': false,
        // TASK 6: Escrow & Commission fields
        'commissionPercentage': commissionPercentage,
        'commissionAmount': commissionAmount,
        'payoutAmount': payoutAmount,
        'escrowStatus': 'held', // Funds are held in escrow initially
        'paymentStatus': 'pending', // Payment pending from buyer
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Update task status to in_progress
      await _firestoreService.db.collection('tasks').doc(taskId).update({
        'status': 'in_progress',
        'sellerId': sellerId,
      });

      return orderRef.id;
    } catch (e) {
      _errorMessage = 'Failed to place order: $e';
      debugPrint('OrderProvider.placeTaskOrder error: $_errorMessage');
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Update order status
  Future<bool> updateOrderStatus(String orderId, String status) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _firestoreService.updateOrderStatus(orderId, status);
      return true;
    } catch (e) {
      _errorMessage = 'Failed to update order status: $e';
      debugPrint('OrderProvider.updateOrderStatus error: $_errorMessage');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Update order fields (for escrow/payment updates)
  Future<bool> updateOrderFields(String orderId, Map<String, dynamic> fields) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _firestoreService.updateOrderFields(orderId, fields);
      return true;
    } catch (e) {
      _errorMessage = 'Failed to update order fields: $e';
      debugPrint('OrderProvider.updateOrderFields error: $_errorMessage');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Complete an order (when payment is received and work is done)
  Future<bool> completeOrder(String orderId, String taskId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final batch = _firestoreService.db.batch();

      // Update order status
      batch.update(_firestoreService.db.collection('orders').doc(orderId), {
        'status': 'Completed',
        'paymentStatus': 'paid',
        'paidAt': FieldValue.serverTimestamp(),
      });

      // Update task status
      batch.update(_firestoreService.db.collection('tasks').doc(taskId), {
        'status': 'completed',
      });

      await batch.commit();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to complete order: $e';
      debugPrint('OrderProvider.completeOrder error: $_errorMessage');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Release escrow to seller (when buyer confirms satisfaction)
  Future<bool> releaseEscrow(String orderId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _firestoreService.db.collection('orders').doc(orderId).update({
        'escrowStatus': 'released',
        'escrowReleasedAt': FieldValue.serverTimestamp(),
        // Note: paymentStatus should already be 'paid' when this is called
      });
      return true;
    } catch (e) {
      _errorMessage = 'Failed to release escrow: $e';
      debugPrint('OrderProvider.releaseEscrow error: $_errorMessage');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Refund an order
  Future<bool> refundOrder(String orderId, String reason) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _firestoreService.db.collection('orders').doc(orderId).update({
        'status': 'Refunded',
        'paymentStatus': 'refunded',
        'escrowStatus': 'refunded',
        'refundReason': reason,
      });
      return true;
    } catch (e) {
      _errorMessage = 'Failed to refund order: $e';
      debugPrint('OrderProvider.refundOrder error: $_errorMessage');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Helper to update orders from a QuerySnapshot
  void _updateOrdersFromSnapshot(QuerySnapshot querySnapshot, bool isSeller) {
    final List<OrderModel> orders = querySnapshot.docs
        .map((doc) => OrderModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .toList();

    // Sort by creation date (newest first)
    orders.sort((a, b) =>
        (b.paidAt ?? b.escrowReleasedAt ?? DateTime.now())
            .compareTo(a.paidAt ?? a.escrowReleasedAt ?? DateTime.now()));

    if (isSeller) {
      _sellerOrders = orders;
    } else {
      _userOrders = orders;
    }

    notifyListeners();
  }

  // Dispose method to cancel subscription (call when no longer needed)
  void dispose() {
    _orderSubscription?.cancel();
    super.dispose();
  }
}