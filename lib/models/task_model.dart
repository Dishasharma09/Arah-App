import 'package:cloud_firestore/cloud_firestore.dart';

class TaskModel {
  final String id;
  final String category;
  final String subCategory;
  final String price;
  final String title;
  final String description;
  final bool isBeginnerFriendly;
  final String postedTime;
  final String buyerId;
  final String buyerName;
  final String sellerId; // UID of assigned seller (empty when open)
  final String status; // "open", "in_progress", "completed"
  final DateTime createdAt;
  final List<String> tags;
  final DateTime? deadline;
  final List<String> attachments;
  final String budgetType;
  final List<String> orderTakers;
  final List<String> orderTakerNames;
  

  TaskModel({
    this.id = '',
    required this.category,
    this.subCategory = '',
    required this.price,
    required this.title,
    this.description = '',
    this.isBeginnerFriendly = false,
    this.postedTime = '',
    this.buyerId = '',
    this.buyerName = '',
    this.sellerId = '',
    this.status = 'open',
    DateTime? createdAt,
    this.tags = const [],
    this.deadline,
    this.attachments = const [],
    this.budgetType = 'Fixed Price',
    this.orderTakers = const [],
    this.orderTakerNames = const [],
  }) : createdAt = createdAt ?? DateTime.now();

  factory TaskModel.fromMap(Map<String, dynamic> map, String id) {
    return TaskModel(
      id: id,
      category: map['category'] ?? 'General',
      subCategory: map['subCategory'] ?? '',
      price: map['price'] ?? '₹0',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      isBeginnerFriendly: map['isBeginnerFriendly'] ?? false,
      postedTime: map['postedTime'] ?? '',
      buyerId: map['buyerId'] ?? '',
      buyerName: map['buyerName'] ?? '',
      sellerId: map['sellerId'] ?? '',
      status: map['status'] ?? 'open',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      tags: List<String>.from(map['tags'] ?? []),
      deadline: (map['deadline'] as Timestamp?)?.toDate(),
      attachments: List<String>.from(map['attachments'] ?? []),
      budgetType: map['budgetType'] ?? 'Fixed Price',
      orderTakers: List<String>.from(map['orderTakers'] ?? []),
      orderTakerNames: List<String>.from(map['orderTakerNames'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'category': category,
      'subCategory': subCategory,
      'price': price,
      'title': title,
      'description': description,
      'isBeginnerFriendly': isBeginnerFriendly,
      'postedTime': postedTime,
      'buyerId': buyerId,
      'buyerName': buyerName,
      'sellerId': sellerId,
      'status': status,
      'createdAt': FieldValue.serverTimestamp(),
      'tags': tags,
      'deadline': deadline != null ? Timestamp.fromDate(deadline!) : null,
      'attachments': attachments,
      'budgetType': budgetType,
      'orderTakers': orderTakers,
      'orderTakerNames': orderTakerNames,
    };
  }
}
