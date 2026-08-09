import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String id;
  final String recipientId;
  final String? senderId;
  final String type;
  final String title;
  final String body;
  final String? relatedId;
  final String? relatedType;
  final bool isRead;
  final DateTime? createdAt;

  NotificationModel({
    required this.id,
    required this.recipientId,
    this.senderId,
    required this.type,
    required this.title,
    required this.body,
    this.relatedId,
    this.relatedType,
    this.isRead = false,
    this.createdAt,
  });

  factory NotificationModel.fromMap(Map<String, dynamic> map, String id) {
    return NotificationModel(
      id: id,
      recipientId: map['recipientId'] ?? '',
      senderId: map['senderId'],
      type: map['type'] ?? '',
      title: map['title'] ?? '',
      body: map['body'] ?? '',
      relatedId: map['relatedId'],
      relatedType: map['relatedType'],
      isRead: map['isRead'] ?? false,
      createdAt: map['createdAt'] != null ? (map['createdAt'] as Timestamp).toDate() : null,
    );
  }

  Map<String, dynamic> toMap() {
    final map = {
      'recipientId': recipientId,
      'senderId': senderId,
      'type': type,
      'title': title,
      'body': body,
      'relatedId': relatedId,
      'relatedType': relatedType,
      'isRead': isRead,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };

    // Remove null values to keep the document clean
    return Map<String, dynamic>.fromEntries(
        map.entries.where((entry) => entry.value != null),
    );
  }
}