import 'dart:async';
import 'package:flutter/material.dart';
import '../models/task_model.dart';
import '../services/firestore_service.dart';

class HomeProvider with ChangeNotifier {
  String _selectedCategory = "All";
  String _searchQuery = "";
  double? _maxBudget;
  List<TaskModel> _firestoreTasks = [];
  bool _isLoadingTasks = false;
  StreamSubscription<List<TaskModel>>? _taskSubscription;

  final FirestoreService _firestoreService = FirestoreService();

  // ─── Getters ───────────────────────────────────────────────────────────────

  String get selectedCategory => _selectedCategory;
  String get searchQuery => _searchQuery;
  double? get maxBudget => _maxBudget;
  bool get isLoadingTasks => _isLoadingTasks;

  /// All open tasks from Firestore (already filtered by subscribeToOpenTasks)
  List<TaskModel> get allTasks => _firestoreTasks;

  List<TaskModel> get filteredTasks {
    List<TaskModel> result = _firestoreTasks;

    if (_selectedCategory != "All") {
      result = result
          .where((task) => task.category == _selectedCategory)
          .toList();
    }

    if (_searchQuery.isNotEmpty) {
      result = result
          .where((task) =>
              task.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              task.description.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              task.tags.any((tag) => tag.toLowerCase().contains(_searchQuery.toLowerCase())))
          .toList();
    }

    if (_maxBudget != null) {
      result = result.where((task) {
        final priceString = task.price.replaceAll(RegExp(r'[^0-9]'), '');
        if (priceString.isNotEmpty) {
          final price = double.tryParse(priceString) ?? 0;
          return price <= _maxBudget!;
        }
        return true;
      }).toList();
    }

    return result;
  }

  // ─── Load from Firestore ───────────────────────────────────────────────────

  /// Subscribe to open tasks, excluding tasks posted by [excludeUserId].
  /// Pass the current user's UID so buyers/sellers never see their own tasks.
  void subscribeToOpenTasks({String excludeUserId = ''}) {
    _taskSubscription?.cancel();
    _isLoadingTasks = true;
    notifyListeners();

    // Always fetch all open tasks so users can see their own requests on the home feeds
    final stream = _firestoreService.fetchOpenTasksStream();

    _taskSubscription = stream.listen(
      (tasks) {
        _firestoreTasks = tasks;
        _isLoadingTasks = false;
        notifyListeners();
      },
      onError: (e) {
        debugPrint('HomeProvider stream error: $e');
        _isLoadingTasks = false;
        notifyListeners();
      },
    );
  }

  void cancelSubscription() {
    _taskSubscription?.cancel();
  }

  // ─── Filters ───────────────────────────────────────────────────────────────

  void selectCategory(String category) {
    _selectedCategory = category;
    notifyListeners();
  }

  void updateSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void updateMaxBudget(double? budget) {
    _maxBudget = budget;
    notifyListeners();
  }

  void resetFilters() {
    _selectedCategory = "All";
    _searchQuery = "";
    _maxBudget = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _taskSubscription?.cancel();
    super.dispose();
  }
}
