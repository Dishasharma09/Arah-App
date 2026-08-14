import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';
import '../services/storage_service.dart';
import '../services/user_stats_service.dart';

class UserProvider with ChangeNotifier {
  UserModel? _user;
  File? _profileImageFile; // Local file for display before upload
  bool _isLoading = false;
  bool _isLoadingStats = false;
  Set<String> _blockedUserIds = {}; // People the current user has blocked

  final ImagePicker _picker = ImagePicker();
  final FirestoreService _firestoreService = FirestoreService();
  final StorageService _storageService = StorageService();
  final UserStatsService _statsService = UserStatsService();

  // ─── Getters ───────────────────────────────────────────────────────────────

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  bool get isLoadingStats => _isLoadingStats;
  bool get isLoggedIn => _user != null;
  Set<String> get blockedUserIds => _blockedUserIds;
  bool isUserBlocked(String otherUid) => _blockedUserIds.contains(otherUid);

  String get uid => FirebaseAuth.instance.currentUser?.uid ?? '';
  String get name => _user?.name ?? '';
  String get username => _user?.username ?? '';
  String get email => _user?.email ?? '';
  String get role => _user?.role ?? 'Buyer';
  String get currentMode => _user?.currentMode ?? 'Buyer';
  String get experienceLevel => _user?.experienceLevel ?? 'Beginner';
  String get bio => _user?.bio ?? '';
  String get collegeName => _user?.collegeName ?? '';
  DateTime? get dateOfBirth => _user?.dateOfBirth;
  int? get age => _user?.age;
  List<String> get skills => _user?.skills ?? [];
  String? get photoUrl => _user?.photoUrl;
  String get githubUrl => _user?.githubUrl ?? '';
  String get linkedinUrl => _user?.linkedinUrl ?? '';
  String get portfolioUrl => _user?.portfolioUrl ?? '';
  String get country => _user?.country ?? '';
  bool get isProfilePublic => _user?.isProfilePublic ?? true;

  /// Verified badge — never just email verification. See UserModel.isVerified.
  bool get isVerified => _user?.isVerified ?? false;

  // System-generated (read-only) stats — see UserStatsService.
  int get tasksCompleted => _user?.tasksCompleted ?? 0;
  double get avgRating => _user?.avgRating ?? 0.0;
  int get ratingCount => _user?.ratingCount ?? 0;
  int get trustScore => _user?.trustScore ?? 0;
  double? get avgCompletionTimeMinutes => _user?.avgCompletionTimeMinutes;
  double? get responseRate => _user?.responseRate;

  // ─── Profile Completion & Verification ────────────────────────────────────

  /// Percentage of profile information completed by the user.
  /// Returns value between 0.0 and 1.0
  double get profileCompletion {
    if (_user == null) return 0;

    final fields = [
      username.isNotEmpty,
      collegeName.isNotEmpty,
      dateOfBirth != null,
      experienceLevel.isNotEmpty,
      bio.isNotEmpty,
      skills.isNotEmpty,
      githubUrl.isNotEmpty,
      linkedinUrl.isNotEmpty,
      portfolioUrl.isNotEmpty,
      photoUrl != null,
    ];

    final completed = fields.where((field) => field).length;

    return completed / fields.length;
  }

bool get isProfileComplete {
  if (_user == null) return false;

  return
      photoUrl!.isNotEmpty &&
      bio.isNotEmpty &&
      skills.isNotEmpty &&
      githubUrl.isNotEmpty;
}
  /// Controls the verified badge shown beside username.
bool get showVerifiedBadge {
  print("photoUrl = $photoUrl");
  print("bio = $bio");
  print("skills = $skills");
  print("github = $githubUrl");

  return
      username.isNotEmpty &&
      bio.isNotEmpty &&
      skills.isNotEmpty &&
      githubUrl.isNotEmpty;
}
  /// Shows which profile parts are still missing.
  List<String> get missingProfileFields {
    if (_user == null) return [];

    final missing = <String>[];

    if (username.isEmpty) missing.add('Username');
    if (collegeName.isEmpty) missing.add('College Name');
    if (dateOfBirth == null) missing.add('Date of Birth');
    if (experienceLevel.isEmpty) missing.add('Experience Level');
    if (bio.isEmpty) missing.add('Bio');
    if (skills.isEmpty) missing.add('Skills');

    return missing;
  }
  /// Local profile image file (takes priority over photoUrl while set)
  File? get profileImageFile => _profileImageFile;

  // ─── Initialisation ────────────────────────────────────────────────────────

  /// Load user profile from Firestore. Called once after sign-in.
  ///
  /// IMPORTANT: this can throw. Callers must distinguish "profile fetch
  /// failed" (rethrow / show retry) from "profile genuinely doesn't exist"
  /// (`user == null` with no exception) — conflating the two was the root
  /// cause of the app landing on Profile Setup unexpectedly. See main.dart.
  Future<void> loadUser(String uid) async {
    _isLoading = true;
    notifyListeners();
    try {
      _user = await _firestoreService.getUserProfile(uid);
      if (_user != null) {
        final prefs = await SharedPreferences.getInstance();
        final savedMode = prefs.getString('currentMode_$uid');
        if (savedMode != null && savedMode != _user!.currentMode) {
          _user = _user!.copyWith(currentMode: savedMode);
        }
        final imagePath = prefs.getString('profile_image_path_$uid');
        if (imagePath != null) {
          final file = File(imagePath);
          if (await file.exists()) {
            _profileImageFile = file;
          }
        }
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    // Fire-and-forget: don't hold up login on this, but get it populated
    // as soon as possible so the home feeds can filter blocked users out.
    unawaited(refreshBlockedUsers());
  }

  /// Re-fetches the current user's blocked-user list from Firestore.
  /// Call this after any block/unblock action so cached UI (task feeds,
  /// user search, the Blocked Users screen) stays in sync immediately
  /// rather than waiting for the next login.
  Future<void> refreshBlockedUsers() async {
    if (uid.isEmpty) return;
    try {
      final ids = await _firestoreService.getBlockedUserIds(uid);
      _blockedUserIds = ids.toSet();
      notifyListeners();
    } catch (e) {
      debugPrint('refreshBlockedUsers error: $e');
    }
  }

  /// Refreshes ONLY the system-generated stats (Trust Score, Tasks
  /// Completed, etc.) from real activity data. Safe to call repeatedly
  /// (e.g. every time the Profile screen is opened) — never touches any
  /// user-editable field.
  Future<void> loadStats() async {
    if (_user == null || uid.isEmpty) return;
    _isLoadingStats = true;
    notifyListeners();
    try {
      final stats = await _statsService.computeStats(uid);
      _user = _user!.copyWith(
        tasksCompleted: stats.tasksCompleted,
        avgRating: stats.avgRating,
        ratingCount: stats.ratingCount,
        trustScore: stats.trustScore,
        avgCompletionTimeMinutes: stats.avgCompletionTimeMinutes,
        responseRate: stats.responseRate,
      );
    } catch (e) {
      debugPrint('UserProvider.loadStats error: $e');
    } finally {
      _isLoadingStats = false;
      notifyListeners();
    }
  }


  /// Called once, right after account creation (sign-up), before the user
  /// has a Firestore profile document yet.
  Future<void> setupProfile({
    required String uid,
    required String name,
    required String email,
    required String role,
    required String experienceLevel,
    required List<String> skills,
    required String country,
  }) async {
    final newUser = UserModel(
      id: uid,
      name: name,
      email: email,
      role: role,
      currentMode: role == 'Seller' ? 'Seller' : 'Buyer',
      experienceLevel: experienceLevel,
      skills: skills,
      country: country,
    );
    await _firestoreService.createUserProfile(uid, newUser.toMap());
    _user = newUser;
    notifyListeners();
  }

  /// Completes REGISTRATION (the Profile Setup screen) — the one and only
  /// place `username`, `collegeName`, and `dateOfBirth` are ever written.
  ///
  /// `dateOfBirth` is intentionally NOT a parameter of [updateProfile]
  /// below: once this call succeeds, the value is permanent for the
  /// lifetime of the account.
Future<void> completeRegistration({
  required String username,
  required String collegeName,
  required DateTime dateOfBirth,
  required String experienceLevel,
  required List<String> skills,
  File? profileImage,
}) async {

  print("USER BEFORE COMPLETE: $_user");

  if (_user == null) {
  throw Exception("User is null");
}

  notifyListeners();

print("Before Firestore update");

await _firestoreService.updateUserProfile(uid, {
  'username': username,
  'collegeName': collegeName,
  'dateOfBirth': Timestamp.fromDate(dateOfBirth),
  'experienceLevel': experienceLevel,
  'skills': skills,
});
_user = _user!.copyWith(
  username: username,
  collegeName: collegeName,
  dateOfBirth: dateOfBirth,
  experienceLevel: experienceLevel,
  skills: skills,
);

notifyListeners();

print("After Firestore update");

print("Firestore updated successfully");

if (profileImage != null) {
  try {
    print("Uploading image from Edit Profile...");
    print("Uploading image from Registration...");
    final url = await _storageService.uploadProfilePicture(
      uid,
      profileImage.path,
    );

    _user = _user!.copyWith(photoUrl: url);

    await _firestoreService.updateUserProfile(uid, {
      'photoUrl': url,
    });

    notifyListeners();
} catch (e, s) {
  print("========== REGISTRATION IMAGE ERROR ==========");
  print(e);
  print(s);
}
}
}



  /// Clear user data on logout
  void clearUser() {
    _user = null;
    _profileImageFile = null;
    _blockedUserIds = {};
    notifyListeners();
  }

  // ─── Mode Switching ────────────────────────────────────────────────────────

  // ─── Role Switching (account type, not just active view) ──────────────────
  //
  // Different from switchMode() above: switchMode() only flips which HOME
  // SCREEN a "Both" user is currently looking at. updateRole() changes the
  // account's actual workspace type (Buyer / Seller / Both) — used by the
  // "Change Workspace" option in Settings so ANY user can switch, not just
  // ones who signed up as "Both".
  //
  // SECURITY: this is the second (and previously unguarded) place a user
  // can gain selling ability, alongside Profile Setup at registration.
  // Without a check here, a user who registered as "Buyer" (and so was
  // never subjected to the 23+ selling check, since it only ever ran for
  // Seller/Both at sign-up) could switch to "Seller"/"Both" from Settings
  // and bypass the age restriction entirely. This mirrors the same
  // `age < 23` rule enforced in ProfileSetupScreen._completeSetup — keep
  // both in sync if the business rule ever changes.
  Future<void> updateRole(String newRole) async {
    if (_user == null) return;

    final isSellingRole = newRole == 'Seller' || newRole == 'Both';
    if (isSellingRole) {
      final currentAge = age; // derived from stored dateOfBirth — see UserModel.age
      if (currentAge == null || currentAge < 23) {
        throw Exception('You must be 23 or older to sell on ARAH.');
      }
    }

    // Keep currentMode in sync so the correct home screen shows right away.
    final newMode = newRole == 'Seller' ? 'Seller' : 'Buyer';

    _user = _user!.copyWith(role: newRole, currentMode: newMode);
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('currentMode_$uid', newMode);

    try {
      await _firestoreService.updateUserProfile(uid, {
        'role': newRole,
        'currentMode': newMode,
      });
    } catch (e) {
      debugPrint('updateRole Firestore error: $e');
    }
  }

  Future<void> switchMode(String mode) async {
    if (_user == null) return;
    _user = _user!.copyWith(currentMode: mode);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('currentMode_$uid', mode);
    try {
      await _firestoreService.updateUserProfile(uid, {'currentMode': mode});
    } catch (e) {
      debugPrint('switchMode Firestore error: $e');
    }
  }

  // ─── Profile Updates (Edit Profile screen ONLY) ─────────────────────────────
  //
  // This is deliberately the only write path Edit Profile is allowed to use.
  // It intentionally has NO `dateOfBirth` and NO `experienceLevel` parameter:
  // per the agreed Edit Profile scope, only username, bio, college, skills,
  // github, linkedin, and portfolio may be edited after registration.

  Future<void> updateProfile({
    String? name,
    String? username,
    String? bio,
    String? collegeName,
    List<String>? skills,
    String? githubUrl,
    String? linkedinUrl,
    String? portfolioUrl,
  }) async {
   if (_user == null) return;

try {
  await _firestoreService.updateUserProfile(uid, {
    if (name != null) 'name': name,
    if (username != null) 'username': username,
    if (bio != null) 'bio': bio,
    if (collegeName != null) 'collegeName': collegeName,
    if (skills != null) 'skills': skills,
    if (githubUrl != null) 'githubUrl': githubUrl,
    if (linkedinUrl != null) 'linkedinUrl': linkedinUrl,
    if (portfolioUrl != null) 'portfolioUrl': portfolioUrl,
  });

  _user = _user!.copyWith(
    name: name,
    username: username,
    bio: bio,
    collegeName: collegeName,
    skills: skills,
    githubUrl: githubUrl,
    linkedinUrl: linkedinUrl,
    portfolioUrl: portfolioUrl,
  );

  notifyListeners();
} catch (e) {
  debugPrint('updateProfile error: $e');
  rethrow;
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

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('profile_image_path_$uid', pickedFile.path);
print("Uploading image from Edit Profile...");
    print("Uploading image...");
print("Uploading image from Registration...");
    final url = await _storageService.uploadProfilePicture(
      uid,
      pickedFile.path,
    );

    print("Download URL = $url");

    if (_user != null) {
      _user = _user!.copyWith(photoUrl: url);

      await _firestoreService.updateUserProfile(uid, {
        'photoUrl': url,
      });

      print("Firestore updated with image URL");
      notifyListeners();
    }
  } catch (e, s) {
    print("UPLOAD ERROR:");
    print(e);
    print(s);
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
}