import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';

/// Platform commission taken out of every released payment (9%).
const double kPlatformCommissionRate = 0.09;

/// All statuses an order can be in, in the order they normally occur.
class OrderStatus {
  static const pendingApproval = 'PendingApproval'; // seller applied / buyer needs to accept
  static const rejected = 'Rejected'; // buyer declined the request
  static const awaitingPayment = 'AwaitingPayment'; // accepted, buyer must fund escrow
  static const inEscrow = 'InEscrow'; // paid — funds held, work in progress
  static const delivered = 'Delivered'; // seller marked work delivered, awaiting buyer approval
  static const completed = 'Completed'; // buyer approved — funds released to seller
  static const refunded = 'Refunded'; // order cancelled — funds returned to buyer

  /// Orders that still need attention / are in flight.
  static const active = [pendingApproval, awaitingPayment, inEscrow, delivered];

  /// Orders that have reached a final state.
  static const history = [completed, rejected, refunded];
}

class OrderModel {
  final String id;
  final String title;
  final String price;
  final String clientInitial;
  final String clientName;
  final String clientId; // The other party's UID (seller's buyerId or buyer's sellerId)
  final String status;
  final String buyerId;
  final String buyerName;
  final String sellerId;
  final String sellerName;
  final String taskId;
  final String chatId;
  final bool ratedByBuyer;
  final bool ratedBySeller;
  final DateTime? paidAt;
  final DateTime? deliveredAt;
  final DateTime? releasedAt;
  final DateTime? refundedAt;
  final String refundReason;

  OrderModel({
    this.id = '',
    required this.title,
    required this.price,
    required this.clientInitial,
    required this.clientName,
    this.clientId = '',
    required this.status,
    this.buyerId = '',
    this.buyerName = '',
    this.sellerId = '',
    this.sellerName = '',
    this.taskId = '',
    this.chatId = '',
    this.ratedByBuyer = false,
    this.ratedBySeller = false,
    this.paidAt,
    this.deliveredAt,
    this.releasedAt,
    this.refundedAt,
    this.refundReason = '',
  });

  factory OrderModel.fromMap(Map<String, dynamic> map, String id) {
    final clientName = map['clientName'] ?? 'Unknown';
    return OrderModel(
      id: id,
      title: map['title'] ?? '',
      price: map['price'] ?? '₹0',
      clientInitial:
          clientName.isNotEmpty ? clientName[0].toUpperCase() : '?',
      clientName: clientName,
      clientId: map['clientId'] ?? '',
      status: map['status'] ?? 'Pending',
      buyerId: map['buyerId'] ?? '',
      buyerName: map['buyerName'] ?? '',
      sellerId: map['sellerId'] ?? '',
      sellerName: map['sellerName'] ?? '',
      taskId: map['taskId'] ?? '',
      chatId: map['chatId'] ?? '',
      ratedByBuyer: map['ratedByBuyer'] ?? false,
      ratedBySeller: map['ratedBySeller'] ?? false,
      paidAt: (map['paidAt'] as Timestamp?)?.toDate(),
      deliveredAt: (map['deliveredAt'] as Timestamp?)?.toDate(),
      releasedAt: (map['releasedAt'] as Timestamp?)?.toDate(),
      refundedAt: (map['refundedAt'] as Timestamp?)?.toDate(),
      refundReason: map['refundReason'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'price': price,
      'clientName': clientName,
      'clientId': clientId,
      'status': status,
      'buyerId': buyerId,
      'buyerName': buyerName,
      'sellerId': sellerId,
      'sellerName': sellerName,
      'taskId': taskId,
      'chatId': chatId,
      'ratedByBuyer': ratedByBuyer,
      'ratedBySeller': ratedBySeller,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  /// Numeric order amount parsed out of the display price (e.g. "₹1,200" -> 1200.0)
  double get amountValue {
    final digits = price.replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(digits) ?? 0;
  }

  double get commissionAmount => amountValue * kPlatformCommissionRate;

  double get sellerNetAmount => amountValue - commissionAmount;

  bool get isAwaitingPayment => status == OrderStatus.awaitingPayment;
  bool get isInEscrow => status == OrderStatus.inEscrow;
  bool get isDelivered => status == OrderStatus.delivered;
  bool get isCompleted => status == OrderStatus.completed;
  bool get isRefunded => status == OrderStatus.refunded;
  bool get isRejected => status == OrderStatus.rejected;
  bool get isPendingApproval => status == OrderStatus.pendingApproval;

  /// Whether funds are currently being held for this order (paid, not yet released/refunded).
  bool get fundsHeld => isInEscrow || isDelivered;
}

/// Formats a numeric amount as a ₹ string with thousands separators,
/// e.g. 125000 -> "₹1,25,000" (Indian digit grouping).
String formatCurrency(double value) {
  final isNegative = value < 0;
  final digits = value.abs().round().toString();

  String grouped;
  if (digits.length <= 3) {
    grouped = digits;
  } else {
    final last3 = digits.substring(digits.length - 3);
    var rest = digits.substring(0, digits.length - 3);
    final parts = <String>[];
    while (rest.length > 2) {
      parts.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) parts.insert(0, rest);
    grouped = '${parts.join(',')},$last3';
  }
  return '₹${isNegative ? '-' : ''}$grouped';
}

class OrderProvider with ChangeNotifier {
  List<OrderModel> _activeOrders = [];
  List<OrderModel> _completedOrders = [];
  bool _isLoading = false;

  // Set when either orders stream errors out, so the UI can show
  // an error state with a retry option instead of a silently stale list.
  bool _hasError = false;
  bool get hasError => _hasError;

  String? _lastUid;
  bool _lastIsSeller = false;

  final FirestoreService _firestoreService = FirestoreService();

  bool get isLoading => _isLoading;
  List<OrderModel> get activeOrders => _activeOrders;
  List<OrderModel> get completedOrders => _completedOrders;

  /// Subscribe to orders from Firestore for the given user
  void subscribeToOrders(String uid, {bool isSeller = false}) {
    _lastUid = uid;
    _lastIsSeller = isSeller;

    _isLoading = true;
    _hasError = false;
    notifyListeners();

    final activeStream = isSeller
        ? _firestoreService.fetchSellerOrders(uid, OrderStatus.active)
        : _firestoreService.fetchUserOrders(uid, OrderStatus.active);

    final completedStream = isSeller
        ? _firestoreService.fetchSellerOrders(uid, OrderStatus.history)
        : _firestoreService.fetchUserOrders(uid, OrderStatus.history);

    activeStream.listen((snap) {
      _activeOrders = snap.docs
          .map((d) =>
              OrderModel.fromMap(d.data() as Map<String, dynamic>, d.id))
          .toList();
      _isLoading = false;
      _hasError = false;
      notifyListeners();
    }, onError: (e) {
      debugPrint('OrderProvider active stream error: $e');
      _isLoading = false;
      _hasError = true;
      notifyListeners();
    });

    completedStream.listen((snap) {
      _completedOrders = snap.docs
          .map((d) =>
              OrderModel.fromMap(d.data() as Map<String, dynamic>, d.id))
          .toList();
      notifyListeners();
    }, onError: (e) {
      debugPrint('OrderProvider completed stream error: $e');
      _hasError = true;
      notifyListeners();
    });
  }

  /// Retry after an error — re-subscribes using the last known uid/mode.
  void retry() {
    if (_lastUid != null && _lastUid!.isNotEmpty) {
      subscribeToOrders(_lastUid!, isSeller: _lastIsSeller);
    }
  }

  /// Buyer pays for the order: moves funds into escrow (status -> InEscrow).
  Future<void> payOrder(String orderId) async {
    try {
      await _firestoreService.payOrder(orderId);
    } catch (e) {
      debugPrint('payOrder error: $e');
      rethrow;
    }
  }

  /// Seller marks the work as delivered, awaiting buyer approval.
  Future<void> markDelivered(String orderId) async {
    try {
      await _firestoreService.markOrderDelivered(orderId);
    } catch (e) {
      debugPrint('markDelivered error: $e');
      rethrow;
    }
  }

  /// Buyer approves delivered work: releases escrowed funds (minus commission) to the seller.
  Future<void> releaseOrder(String orderId, String taskId) async {
    try {
      await _firestoreService.releaseOrderPayment(orderId, taskId);
    } catch (e) {
      debugPrint('releaseOrder error: $e');
      rethrow;
    }
  }

  /// Refund the buyer: returns escrowed funds and frees up the task.
  Future<void> requestRefund(String orderId, String taskId,
      {String reason = ''}) async {
    try {
      await _firestoreService.refundOrder(orderId, taskId, reason: reason);
    } catch (e) {
      debugPrint('requestRefund error: $e');
      rethrow;
    }
  }

  /// Mark order as completed: updates order status + task status
  Future<void> completeOrder(String orderId, String taskId) async {
    try {
      await _firestoreService.completeOrder(orderId, taskId);
    } catch (e) {
      debugPrint('completeOrder error: $e');
    }
  }

  /// Accept an order request
  Future<void> acceptOrder(String orderId) async {
    try {
      await _firestoreService.acceptOrderRequest(orderId);
    } catch (e) {
      debugPrint('acceptOrder error: $e');
    }
  }

  /// Reject an order request
  Future<void> rejectOrder(String orderId) async {
    try {
      await _firestoreService.rejectOrderRequest(orderId);
    } catch (e) {
      debugPrint('rejectOrder error: $e');
    }
  }

  /// Reassign: delete order + reset task to "open"
  Future<void> reassignOrder(String orderId, String taskId) async {
    try {
      await _firestoreService.reassignTask(orderId, taskId);
    } catch (e) {
      debugPrint('reassignOrder error: $e');
    }
  }

  /// Save a rating for the other party
  Future<void> saveRating({
    required String orderId,
    required String ratedUserId,
    required String raterId,
    required double rating,
    required bool isBuyerRating,
    String reviewText = '',
  }) async {
    try {
      await _firestoreService.saveRating(
        orderId: orderId,
        ratedUserId: ratedUserId,
        raterId: raterId,
        rating: rating,
        isBuyerRating: isBuyerRating,
        reviewText: reviewText,
      );
    } catch (e) {
      debugPrint('saveRating error: $e');
    }
  }
}
