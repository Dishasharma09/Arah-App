import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';
import '../services/storage_service.dart';

class UserProvider with ChangeNotifier {
  UserModel? _user;
  File? _profileImageFile; // Local file for display before upload
  bool _isLoading = false;

  final ImagePicker _picker = ImagePicker();
  final FirestoreService _firestoreService = FirestoreService();
  final StorageService _storageService = StorageService();

  // ─── Getters ───────────────────────────────────────────────────────────────

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _user != null;

  String get uid => FirebaseAuth.instance.currentUser?.uid ?? '';
  String get name => _user?.name ?? '';
  String get email => _user?.email ?? '';
  String get role => _user?.role ?? 'Buyer';
  String get currentMode => _user?.currentMode ?? 'Buyer';
  String get experienceLevel => _user?.experienceLevel ?? 'Beginner';
  String get bio => _user?.bio ?? '';
  List<String> get skills => _user?.skills ?? [];
  String? get photoUrl => _user?.photoUrl;
  String get githubUrl => _user?.githubUrl ?? '';
  String get linkedinUrl => _user?.linkedinUrl ?? '';
  bool get isProfilePublic => _user?.isProfilePublic ?? true;

  /// Local profile image file (takes priority over photoUrl while set)
  File? get profileImageFile => _profileImageFile;

  // ─── Initialisation ────────────────────────────────────────────────────────

  /// Load user profile from Firestore. Called once after sign-in.
  Future<void> loadUser(String uid) async {
    _isLoading = true;
    notifyListeners();
    try {
      _user = await _firestoreService.getUserProfile(uid);
      // Restore cached mode from SharedPreferences if not in Firestore yet
      if (_user != null) {
        final prefs = await SharedPreferences.getInstance();
        final savedMode = prefs.getString('currentMode_$uid');
        if (savedMode != null && savedMode != _user!.currentMode) {
          _user = _user!.copyWith(currentMode: savedMode);
        }
        // Restore local profile image path
        final imagePath = prefs.getString('profile_image_path_$uid');
        if (imagePath != null) {
          final file = File(imagePath);
          if (await file.exists()) {
            _profileImageFile = file;
          }
        }
      }
    } catch (e) {
      debugPrint('UserProvider.loadUser error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Called during first-time profile setup
  Future<void> setupProfile({
    required String uid,
    required String name,
    required String email,
    required String role,
    required String experienceLevel,
    required List<String> skills,
  }) async {
    final newUser = UserModel(
      id: uid,
      name: name,
      email: email,
      role: role,
      currentMode: role == 'Seller' ? 'Seller' : 'Buyer',
      experienceLevel: experienceLevel,
      skills: skills,
    );
    await _firestoreService.createUserProfile(uid, newUser.toMap());
    _user = newUser;
    notifyListeners();
  }

  /// Clear user data on logout
  void clearUser() {
    _user = null;
    _profileImageFile = null;
    notifyListeners();
  }

  // ─── Mode Switching ────────────────────────────────────────────────────────

  Future<void> switchMode(String mode) async {
    if (_user == null) return;
    _user = _user!.copyWith(currentMode: mode);
    notifyListeners();
    // Persist locally
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('currentMode_$uid', mode);
    // Persist to Firestore
    try {
      await _firestoreService.updateUserProfile(uid, {'currentMode': mode});
    } catch (e) {
      debugPrint('switchMode Firestore error: $e');
    }
  }

  // ─── Profile Updates ───────────────────────────────────────────────────────

  Future<void> updateProfile({
    String? name,
    String? bio,
    String? experienceLevel,
    List<String>? skills,
    String? githubUrl,
    String? linkedinUrl,
  }) async {
    if (_user == null) return;
    _user = _user!.copyWith(
      name: name,
      bio: bio,
      experienceLevel: experienceLevel,
      skills: skills,
      githubUrl: githubUrl,
      linkedinUrl: linkedinUrl,
    );
    notifyListeners();
    try {
      await _firestoreService.updateUserProfile(uid, {
        if (name != null) 'name': name,
        if (bio != null) 'bio': bio,
        if (experienceLevel != null) 'experienceLevel': experienceLevel,
        if (skills != null) 'skills': skills,
        if (githubUrl != null) 'githubUrl': githubUrl,
        if (linkedinUrl != null) 'linkedinUrl': linkedinUrl,
      });
    } catch (e) {
      debugPrint('updateProfile error: $e');
    }
  }

  Future<void> updateProfileVisibility(bool isPublic) async {
    if (_user == null) return;
    _user = _user!.copyWith(isProfilePublic: isPublic);
    notifyListeners();
    try {
      await _firestoreService.updateUserProfile(
          uid, {'isProfilePublic': isPublic});
    } catch (e) {
      debugPrint('updateProfileVisibility error: $e');
    }
  }

  // ─── Profile Image ─────────────────────────────────────────────────────────

  Future<void> pickAndUploadImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 75,
        maxWidth: 512,
      );
      if (pickedFile == null) return;

      _profileImageFile = File(pickedFile.path);
      notifyListeners();

      // Cache path locally
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('profile_image_path_$uid', pickedFile.path);

      // Upload to Firebase Storage
      try {
        final url = await _storageService.uploadProfilePicture(
            uid, pickedFile.path);
        if (_user != null) {
          _user = _user!.copyWith(photoUrl: url);
          await _firestoreService.updateUserProfile(uid, {'photoUrl': url});
          notifyListeners();
        }
      } catch (e) {
        debugPrint('Image upload error: $e');
      }
    } catch (e) {
      debugPrint('pickAndUploadImage error: $e');
    }
  }

  // Legacy compatibility shim
  Future<void> pickImage(ImageSource source) => pickAndUploadImage(source);

  File? get profileImage => _profileImageFile;

  /// Upload an already-picked image file to Firebase Storage
  Future<void> uploadExistingProfileImage(String filePath) async {
    try {
      final url = await _storageService.uploadProfilePicture(uid, filePath);
      if (_user != null) {
        _user = _user!.copyWith(photoUrl: url);
        await _firestoreService.updateUserProfile(uid, {'photoUrl': url});
        notifyListeners();
      }
    } catch (e) {
      debugPrint('uploadExistingProfileImage error: $e');
      rethrow;
    }
  }

  // ─── Skill helper (kept for compatibility) ─────────────────────────────────

  void toggleSkill(String skill) {
    if (_user == null) return;
    final list = List<String>.from(_user!.skills);
    if (list.contains(skill)) {
      list.remove(skill);
    } else {
      list.add(skill);
    }
    _user = _user!.copyWith(skills: list);
    notifyListeners();
  }

  // ─── Block/Unblock User (Secure via Cloud Functions) ─────────────────────────

  /// Block a user via Cloud Function (admin/moderator only)
  /// Prevents the blocked user from accessing most app features
  Future<void> blockUserSecure(String userId) async {
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('blockUser')
          .call(<String, dynamic>{'uid': userId});
      return result.data;
    } on FirebaseFunctionsException catch (e) {
      throw FirebaseException(
        plugin: 'firebase-functions',
        code: e.code,
        message: e.message,
      );
    }
  }

  /// Unblock a user via Cloud Function (admin/moderator only)
  /// Restores access for previously blocked users
  Future<void> unblockUserSecure(String userId) async {
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('unblockUser')
          .call(<String, dynamic>{'uid': userId});
      return result.data;
    } on FirebaseFunctionsException catch (e) {
      throw FirebaseException(
        plugin: 'firebase-functions',
        code: e.code,
        message: e.message,
      );
    }
  }
}
