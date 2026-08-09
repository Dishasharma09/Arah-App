import 'package:cloud_firestore/cloud_firestore.dart';

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

  // TASK 6: Escrow & Commission fields
  final double commissionPercentage; // Platform commission percentage (e.g., 15.0 for 15%)
  final double commissionAmount; // Actual commission amount in currency
  final double payoutAmount; // Amount seller receives after commission
  final String escrowStatus; // 'pending', 'held', 'released', 'refunded'
  final String paymentStatus; // 'pending', 'paid', 'failed', 'refunded'
  final String? paymentReference; // Transaction ID from payment processor
  final DateTime? paidAt; // When payment was received
  final DateTime? escrowReleasedAt; // When escrow was released to seller
  final String? refundReason; // If refunded, reason for refund

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
    // TASK 6: Escrow & Commission fields (with defaults)
    this.commissionPercentage = 15.0, // 15% platform commission
    this.commissionAmount = 0.0,
    this.payoutAmount = 0.0,
    this.escrowStatus = 'pending',
    this.paymentStatus = 'pending',
    this.paymentReference,
    this.paidAt,
    this.escrowReleasedAt,
    this.refundReason,
  });

  factory OrderModel.fromMap(Map<String, dynamic> map, String id) {
    final clientName = map['clientName'] ?? 'Unknown';
    return OrderModel(
      id: id,
      title: map['title'] ?? '',
      price: map['price'] ?? '���₹0',
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
      // TASK 6: Escrow & Commission fields
      commissionPercentage: (map['commissionPercentage'] as num?)?.toDouble() ?? 15.0,
      commissionAmount: (map['commissionAmount'] as num?)?.toDouble() ?? 0.0,
      payoutAmount: (map['payoutAmount'] as num?)?.toDouble() ?? 0.0,
      escrowStatus: map['escrowStatus'] ?? 'pending',
      paymentStatus: map['paymentStatus'] ?? 'pending',
      paymentReference: map['paymentReference'],
      paidAt: map['paidAt'] != null ? (map['paidAt'] as Timestamp).toDate() : null,
      escrowReleasedAt: map['escrowReleasedAt'] != null
          ? (map['escrowReleasedAt'] as Timestamp).toDate()
          : null,
      refundReason: map['refundReason'],
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
      // TASK 6: Escrow & Commission fields
      'commissionPercentage': commissionPercentage,
      'commissionAmount': commissionAmount,
      'payoutAmount': payoutAmount,
      'escrowStatus': escrowStatus,
      'paymentStatus': paymentStatus,
      'paymentReference': paymentReference,
      'paidAt': paidAt != null ? Timestamp.fromDate(paidAt!) : null,
      'escrowReleasedAt': escrowReleasedAt != null
          ? Timestamp.fromDate(escrowReleasedAt!)
          : null,
      'refundReason': refundReason,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}