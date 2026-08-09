import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String name;
  final String email;
  final String role; // "Buyer", "Seller", "Both"
  final String currentMode; // "Buyer" or "Seller"
  final String bio;
  final String experienceLevel;
  final List<String> skills;
  final String? photoUrl;
  final String githubUrl;
  final String linkedinUrl;
  final bool isProfilePublic;
  final bool isBlocked; // Whether the user is blocked
  final bool isAdmin; // Whether the user is an admin
  final bool isModerator; // Whether the user is a moderator
  final double avgRating; // Average rating (0-5)
  final int ratingCount; // Total number of ratings received
  // Stage 4: User Management fields
  final String? username; // Unique username/handle
  final bool isVerified; // Whether the user is verified
  final DateTime? verificationDate; // When the user was verified
  // TASK 5: User Data fields
  final DateTime? dateOfBirth; // Date of birth for age calculation
  final String? country; // Country for localization/compliance
  final DateTime? createdAt; // When the user joined
  final DateTime? lastSeen; // Last time the user was active

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.currentMode = 'Buyer',
    this.bio = '',
    this.experienceLevel = 'Beginner',
    this.skills = const [],
    this.photoUrl,
    this.githubUrl = '',
    this.linkedinUrl = '',
    this.isProfilePublic = true,
    this.isBlocked = false,
    this.isAdmin = false,
    this.isModerator = false,
    this.avgRating = 0.0,
    this.ratingCount = 0,
    // Stage 4: User Management fields
    this.username,
    this.isVerified = false,
    this.verificationDate,
    // TASK 5: User Data fields
    this.dateOfBirth,
    this.country,
    this.createdAt,
    this.lastSeen,
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    return UserModel(
      id: id,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      role: map['role'] ?? 'Buyer',
      currentMode: map['currentMode'] ?? map['role'] ?? 'Buyer',
      bio: map['bio'] ?? '',
      experienceLevel: map['experienceLevel'] ?? 'Beginner',
      skills: List<String>.from(map['skills'] ?? []),
      photoUrl: map['photoUrl'],
      githubUrl: map['githubUrl'] ?? '',
      linkedinUrl: map['linkedinUrl'] ?? '',
      isProfilePublic: map['isProfilePublic'] ?? true,
      isBlocked: map['isBlocked'] ?? false,
      isAdmin: map['isAdmin'] ?? false,
      isModerator: map['isModerator'] ?? false,
      avgRating: (map['avgRating'] as num?)?.toDouble() ?? 0.0,
      ratingCount: (map['ratingCount'] as int?) ?? 0,
      // Stage 4: User Management fields
      username: map['username'],
      isVerified: map['isVerified'] ?? false,
      verificationDate: map['verificationDate'] != null
          ? (map['verificationDate'] as Timestamp).toDate()
          : null,
      // TASK 5: User Data fields
      dateOfBirth: map['dateOfBirth'] != null
          ? (map['dateOfBirth'] as Timestamp).toDate()
          : null,
      country: map['country'],
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : null,
      lastSeen: map['lastSeen'] != null
          ? (map['lastSeen'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'role': role,
      'currentMode': currentMode,
      'bio': bio,
      'experienceLevel': experienceLevel,
      'skills': skills,
      'photoUrl': photoUrl,
      'githubUrl': githubUrl,
      'linkedinUrl': linkedinUrl,
      'isProfilePublic': isProfilePublic,
      'isBlocked': isBlocked,
      'isAdmin': isAdmin,
      'isModerator': isModerator,
      'avgRating': avgRating,
      'ratingCount': ratingCount,
      // Stage 4: User Management fields
      'username': username,
      'isVerified': isVerified,
      'verificationDate': verificationDate?.millisecondsSinceEpoch,
      // TASK 5: User Data fields
      'dateOfBirth': dateOfBirth?.millisecondsSinceEpoch,
      'country': country,
      'createdAt': createdAt?.millisecondsSinceEpoch,
      'lastSeen': lastSeen?.millisecondsSinceEpoch,
    };
  }

  UserModel copyWith({
    String? name,
    String? bio,
    String? experienceLevel,
    List<String>? skills,
    String? photoUrl,
    String? githubUrl,
    String? linkedinUrl,
    String? currentMode,
    bool? isProfilePublic,
    bool? isBlocked,
    bool? isAdmin,
    bool? isModerator,
    double? avgRating,
    int? ratingCount,
    // Stage 4: User Management fields
    String? username,
    bool? isVerified,
    DateTime? verificationDate,
    // TASK 5: User Data fields
    DateTime? dateOfBirth,
    String? country,
    DateTime? createdAt,
    DateTime? lastSeen,
  }) {
    return UserModel(
      id: id,
      email: email,
      role: role,
      name: name ?? this.name,
      bio: bio ?? this.bio,
      experienceLevel: experienceLevel ?? this.experienceLevel,
      skills: skills ?? this.skills,
      photoUrl: photoUrl ?? this.photoUrl,
      githubUrl: githubUrl ?? this.githubUrl,
      linkedinUrl: linkedinUrl ?? this.linkedinUrl,
      isProfilePublic: isProfilePublic ?? this.isProfilePublic,
      isBlocked: isBlocked ?? this.isBlocked,
      isAdmin: isAdmin ?? this.isAdmin,
      isModerator: isModerator ?? this.isModerator,
      avgRating: avgRating ?? this.avgRating,
      ratingCount: ratingCount ?? this.ratingCount,
      // Stage 4: User Management fields
      username: username ?? this.username,
      isVerified: isVerified ?? this.isVerified,
      verificationDate: verificationDate ?? this.verificationDate,
      // TASK 5: User Data fields
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      country: country ?? this.country,
      createdAt: createdAt ?? this.createdAt,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }
}