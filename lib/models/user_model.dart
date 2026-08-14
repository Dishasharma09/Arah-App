import 'package:cloud_firestore/cloud_firestore.dart';

/// ARAH user profile model.
///
/// Sprint 2 redesign — fields are grouped below to make the
/// "user-editable vs system-generated" split explicit in code,
/// matching the product agreement with Disha Sharma:
///
///  1) USER-EDITABLE  — entered by the user (registration or Edit Profile).
///  2) SYSTEM-GENERATED — derived from activity. Never written by any
///     screen; only ever updated by backend/aggregation logic
///     (see UserStatsService).
///
/// `dateOfBirth` is a special case: it is user-supplied, but only once,
/// at registration. No screen in this app may write it after creation —
/// see UserProvider.completeRegistration() vs UserProvider.updateProfile().
class UserModel {
  // ── Identity (immutable after creation) ──────────────────────────────────
  final String id;
  final String email;
  final String name;
  final String username;
  final String role; // "Buyer", "Seller", "Both"
  final String currentMode; // "Buyer" or "Seller"

  // ── User-editable: registration-only (set once, never via Edit Profile) ─
  final DateTime? dateOfBirth;

  // ── User-editable: via registration AND/OR Edit Profile ─────────────────
  final String bio;
  final String collegeName;
  final String experienceLevel;
  final List<String> skills;
  
  final String? photoUrl;
  final String githubUrl;
  final String linkedinUrl;
  final String portfolioUrl;
  final String country;
  final bool isProfilePublic;

  // ── Verification inputs (NOT user-editable; set by verification flows) ──
  // Placeholders for future verification pipelines. Deliberately default
  // to false — a user is never verified just by signing up or verifying
  // their email. See UserModel.isVerified below.
  final bool isCollegeIdVerified;
  final bool isGithubVerified;
  final bool isLinkedinVerified;

  // ── System-generated (read-only; written only by UserStatsService /
  //    backend aggregation — never by any user-facing form) ───────────────
  final int tasksCompleted;
  final double avgRating;
  final int ratingCount;
  final int trustScore; // 0-100, computed — see UserStatsService
  final double? avgCompletionTimeMinutes; // null = not enough data yet
  final double? responseRate; // 0-1, null = not enough data yet

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.currentMode = 'Buyer',
    this.username = '',
    this.bio = '',
    this.collegeName = '',
    this.dateOfBirth,
    this.experienceLevel = 'Beginner',
    this.skills = const [],
    this.photoUrl,
    this.githubUrl = '',
    this.linkedinUrl = '',
    this.portfolioUrl = '',
    this.country = '',
    this.isProfilePublic = true,
    this.isCollegeIdVerified = false,
    this.isGithubVerified = false,
    this.isLinkedinVerified = false,
    this.tasksCompleted = 0,
    this.avgRating = 0.0,
    this.ratingCount = 0,
    this.trustScore = 0,
    this.avgCompletionTimeMinutes,
    this.responseRate,
  });

  // ── Derived, read-only values ────────────────────────────────────────────

  /// Age is ALWAYS derived from [dateOfBirth] — there is no stored "age"
  /// field, so it can never drift out of sync with the birth date.
  int? get age {
    final dob = dateOfBirth;
    if (dob == null) return null;
    final now = DateTime.now();
    int age = now.year - dob.year;
    if (now.month < dob.month ||
        (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age;
  }

  /// Verified badge is EARNED, not assumed. It never depends on Firebase
  /// email verification — only on the actual verification requirements
  /// completed so far. Today that's "College ID + at least one of
  /// GitHub/LinkedIn"; extend this rule here (in one place) as the
  /// verification program grows.
  bool get isVerified =>
      isCollegeIdVerified && (isGithubVerified || isLinkedinVerified);

  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    return UserModel(
      id: id,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      role: map['role'] ?? 'Buyer',
      currentMode: map['currentMode'] ?? map['role'] ?? 'Buyer',
      username: map['username'] ?? '',
      bio: map['bio'] ?? '',
      collegeName: map['collegeName'] ?? '',
      dateOfBirth: _parseDate(map['dateOfBirth']),
      experienceLevel: map['experienceLevel'] ?? 'Beginner',
      skills: List<String>.from(map['skills'] ?? []),
      photoUrl: map['photoUrl'],
      githubUrl: map['githubUrl'] ?? '',
      linkedinUrl: map['linkedinUrl'] ?? '',
      portfolioUrl: map['portfolioUrl'] ?? '',
      country: map['country'] ?? '',
      isProfilePublic: map['isProfilePublic'] ?? true,
      isCollegeIdVerified: map['isCollegeIdVerified'] ?? false,
      isGithubVerified: map['isGithubVerified'] ?? false,
      isLinkedinVerified: map['isLinkedinVerified'] ?? false,
      tasksCompleted: (map['tasksCompleted'] ?? 0) as int,
      avgRating: ((map['avgRating'] ?? 0.0) as num).toDouble(),
      ratingCount: (map['ratingCount'] ?? 0) as int,
      trustScore: (map['trustScore'] ?? 0) as int,
      avgCompletionTimeMinutes:
          (map['avgCompletionTimeMinutes'] as num?)?.toDouble(),
      responseRate: (map['responseRate'] as num?)?.toDouble(),
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  /// Full document map — used only by createUserProfile (registration).
  /// Deliberately includes every field, including system-generated ones
  /// at their initial zero/default value, since this only ever runs once.
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'nameLower': name.toLowerCase(),
      'email': email,
      'role': role,
      'currentMode': currentMode,
      'username': username,
      'bio': bio,
      'collegeName': collegeName,
      'dateOfBirth':
          dateOfBirth != null ? Timestamp.fromDate(dateOfBirth!) : null,
      'experienceLevel': experienceLevel,
      'skills': skills,
      'photoUrl': photoUrl,
      'githubUrl': githubUrl,
      'linkedinUrl': linkedinUrl,
      'portfolioUrl': portfolioUrl,
      'country': country,
      'isProfilePublic': isProfilePublic,
      'isCollegeIdVerified': isCollegeIdVerified,
      'isGithubVerified': isGithubVerified,
      'isLinkedinVerified': isLinkedinVerified,
      'tasksCompleted': tasksCompleted,
      'avgRating': avgRating,
      'ratingCount': ratingCount,
      'trustScore': trustScore,
      'avgCompletionTimeMinutes': avgCompletionTimeMinutes,
      'responseRate': responseRate,
    };
  }

  UserModel copyWith({
    String? role,
    String? name,
    String? username,
    String? country,
    String? bio,
    String? collegeName,
    DateTime? dateOfBirth,
    String? experienceLevel,
    List<String>? skills,
    String? photoUrl,
    String? githubUrl,
    String? linkedinUrl,
    String? portfolioUrl,
    String? currentMode,
    bool? isProfilePublic,
    bool? isCollegeIdVerified,
    bool? isGithubVerified,
    bool? isLinkedinVerified,
    int? tasksCompleted,
    double? avgRating,
    int? ratingCount,
    int? trustScore,
    double? avgCompletionTimeMinutes,
    double? responseRate,
  }) {
    return UserModel(
      id: id,
      email: email,
      role: role ?? this.role,
      name: name ?? this.name,
      username: username ?? this.username,
      country: country ?? this.country,
      bio: bio ?? this.bio,
      collegeName: collegeName ?? this.collegeName,
      // NOTE: dateOfBirth deliberately has no "current value" fallback path
      // in any call site outside of registration — see UserProvider.
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      experienceLevel: experienceLevel ?? this.experienceLevel,
      skills: skills ?? this.skills,
      photoUrl: photoUrl ?? this.photoUrl,
      githubUrl: githubUrl ?? this.githubUrl,
      linkedinUrl: linkedinUrl ?? this.linkedinUrl,
      portfolioUrl: portfolioUrl ?? this.portfolioUrl,
      currentMode: currentMode ?? this.currentMode,
      isProfilePublic: isProfilePublic ?? this.isProfilePublic,
      isCollegeIdVerified: isCollegeIdVerified ?? this.isCollegeIdVerified,
      isGithubVerified: isGithubVerified ?? this.isGithubVerified,
      isLinkedinVerified: isLinkedinVerified ?? this.isLinkedinVerified,
      tasksCompleted: tasksCompleted ?? this.tasksCompleted,
      avgRating: avgRating ?? this.avgRating,
      ratingCount: ratingCount ?? this.ratingCount,
      trustScore: trustScore ?? this.trustScore,
      avgCompletionTimeMinutes:
          avgCompletionTimeMinutes ?? this.avgCompletionTimeMinutes,
      responseRate: responseRate ?? this.responseRate,
    );
  }
}