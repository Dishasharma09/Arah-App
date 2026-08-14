import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String id;
  final String userId;
  final String title;
  final String message;
  final String type;
  final DateTime createdAt;
  final bool isRead;

  final String? chatId;
  final String? senderId;
  final String? senderName;

  final int messageCount;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.type,
    required this.createdAt,
    required this.isRead,
    this.chatId,
    this.senderId,
    this.senderName,
    this.messageCount = 1,
  });

  factory NotificationModel.fromMap(
    Map<String, dynamic> map,
    String id,
  ) {
    final rawCount = map['messageCount'];

    return NotificationModel(
      id: id,
      userId: map['userId']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      message: map['body']?.toString() ?? '',
      type: map['type']?.toString() ?? '',
      isRead: map['isRead'] == true,

      chatId: map['chatId']?.toString(),
      senderId: map['senderId']?.toString(),
      senderName: map['senderName']?.toString(),

      messageCount: rawCount is num
          ? rawCount.toInt()
          : 1,

      createdAt:
          (map['createdAt'] as Timestamp?)?.toDate() ??
          DateTime.now(),
    );
  }
}