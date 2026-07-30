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
  final String country;
  final bool isProfilePublic;

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
    this.country = '',
    this.isProfilePublic = true,
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
      country: map['country'] ?? '',
      isProfilePublic: map['isProfilePublic'] ?? true,
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
      'country': country,
      'isProfilePublic': isProfilePublic,
    };
  }

  UserModel copyWith({
    String? country,
    String? name,
    String? bio,
    String? experienceLevel,
    List<String>? skills,
    String? photoUrl,
    String? githubUrl,
    String? linkedinUrl,
    String? currentMode,
    bool? isProfilePublic,
  }) {
    return UserModel(
      id: id,
      email: email,
      role: role,
      name: name ?? this.name,
      country: country ?? this.country,
      bio: bio ?? this.bio,
      experienceLevel: experienceLevel ?? this.experienceLevel,
      skills: skills ?? this.skills,
      photoUrl: photoUrl ?? this.photoUrl,
      githubUrl: githubUrl ?? this.githubUrl,
      linkedinUrl: linkedinUrl ?? this.linkedinUrl,
      currentMode: currentMode ?? this.currentMode,
      isProfilePublic: isProfilePublic ?? this.isProfilePublic,
    );

  }
}
