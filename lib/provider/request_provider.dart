import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';
import '../services/storage_service.dart';

class RequestProvider with ChangeNotifier {
  String _budgetType = "Fixed Price";
  List<PlatformFile> _attachedFiles = [];
  bool _isLoading = false;
  String? _error;

  String get budgetType => _budgetType;
  List<PlatformFile> get attachedFiles => _attachedFiles;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void updateBudgetType(String type) {
    _budgetType = type;
    notifyListeners();
  }

  void addFiles(List<PlatformFile> files) {
    _attachedFiles.addAll(files);
    notifyListeners();
  }

  void removeFile(int index) {
    _attachedFiles.removeAt(index);
    notifyListeners();
  }

  void clearFiles() {
    _attachedFiles.clear();
    notifyListeners();
  }

  Future<bool> submitRequest({
    required String buyerId,
    required String buyerName,
    required String title,
    required String category,
    String subCategory = '',
    required String experience,
    required List<String> tags,
    required String price,
    required DateTime? deadline,
    required String notes,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final firestoreService = FirestoreService();
      final storageService = StorageService();

      // Create a document reference first to get the auto-generated ID
      final docRef = FirebaseFirestore.instance.collection('tasks').doc();
      final taskId = docRef.id;

      // Upload files to Firebase Storage
      final List<String> fileUrls = [];
      for (var file in _attachedFiles) {
        if (file.path != null) {
          try {
            final url = await storageService.uploadTaskAttachment(taskId, file.path!);
            fileUrls.add(url);
          } catch (e) {
            debugPrint('Firebase Storage upload failed, falling back to local path: $e');
            fileUrls.add(file.path!);
          }
        }
      }

      // Construct Task Map
      final taskMap = {
        'category': category,
        'subCategory': subCategory,
        'price': price.startsWith('₹') ? price : '₹$price',
        'title': title,
        'description': notes,
        'isBeginnerFriendly': experience == 'Beginner',
        'postedTime': 'Just now',
        'buyerId': buyerId,
        'buyerName': buyerName,
        'status': 'open',
        'createdAt': FieldValue.serverTimestamp(),
        'tags': tags,
        'deadline': deadline != null ? Timestamp.fromDate(deadline) : null,
        'attachments': fileUrls,
        'budgetType': _budgetType,
      };

      // Create Task document
      await firestoreService.createTaskWithId(taskId, taskMap);

      _attachedFiles.clear();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}
