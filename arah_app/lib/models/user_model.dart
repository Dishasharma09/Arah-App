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
  final double avgRating; // Average rating (0-5)
  final int ratingCount; // Total number of ratings received

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
    this.avgRating = 0.0,
    this.ratingCount = 0,
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
      avgRating: (map['avgRating'] as num?)?.toDouble() ?? 0.0,
      ratingCount: (map['ratingCount'] as int?) ?? 0,
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
      'avgRating': avgRating,
      'ratingCount': ratingCount,
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
    double? avgRating,
    int? ratingCount,
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
      currentMode: currentMode ?? this.currentMode,
      isProfilePublic: isProfilePublic ?? this.isProfilePublic,
      avgRating: avgRating ?? this.avgRating,
      ratingCount: ratingCount ?? this.ratingCount,
    );
  }
}
