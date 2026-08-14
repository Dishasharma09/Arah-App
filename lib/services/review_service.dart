import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/review_model.dart';

class ReviewService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Add Review
  Future<void> addReview(ReviewModel review) async {
    await _firestore
        .collection('reviews')
        .doc(review.id)
        .set(review.toMap());
  }

  /// Get Reviews for a User
  Stream<List<ReviewModel>> getUserReviews(String userId) {
    return _firestore
        .collection('reviews')
        .where('toUserId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              return ReviewModel.fromMap(doc.data(), doc.id);
            }).toList());
  }

  /// Calculate Average Rating
  Future<double> getAverageRating(String userId) async {
    final snapshot = await _firestore
        .collection('reviews')
        .where('toUserId', isEqualTo: userId)
        .get();

    if (snapshot.docs.isEmpty) return 0.0;

    double total = 0;

    for (var doc in snapshot.docs) {
      total += (doc['rating'] as num).toDouble();
    }

    return total / snapshot.docs.length;
  }
}