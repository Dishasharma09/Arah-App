import 'package:cloud_firestore/cloud_firestore.dart';

class ReviewModel {
  final String id;
  final String fromUserId;
  final String toUserId;
  final String taskId;
  final double rating;
  final String review;
  final DateTime createdAt;

  ReviewModel({
    required this.id,
    required this.fromUserId,
    required this.toUserId,
    required this.taskId,
    required this.rating,
    required this.review,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'fromUserId': fromUserId,
      'toUserId': toUserId,
      'taskId': taskId,
      'rating': rating,
      'review': review,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory ReviewModel.fromMap(
    Map<String, dynamic> map,
    String id,
  ) {
    return ReviewModel(
      id: id,
      fromUserId: map['fromUserId'] ?? '',
      toUserId: map['toUserId'] ?? '',
      taskId: map['taskId'] ?? '',
      rating: (map['rating'] as num).toDouble(),
      review: map['review'] ?? '',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }
}