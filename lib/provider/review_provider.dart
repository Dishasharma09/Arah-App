import 'package:flutter/material.dart';
import '../models/review_model.dart';
import '../services/review_service.dart';

class ReviewProvider extends ChangeNotifier {
  final ReviewService _reviewService = ReviewService();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  Future<void> addReview(ReviewModel review) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _reviewService.addReview(review);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Stream<List<ReviewModel>> getUserReviews(String userId) {
    return _reviewService.getUserReviews(userId);
  }

  Future<double> getAverageRating(String userId) {
    return _reviewService.getAverageRating(userId);
  }
}