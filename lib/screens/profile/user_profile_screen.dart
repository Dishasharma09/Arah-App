import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../app/theme/app_theme.dart';
import '../../app/widgets/bottom_nav_bar.dart';
import 'package:flutter/services.dart';
import '../../provider/user_provider.dart';
import 'settings_screen.dart';
import 'profile_image_viewer.dart';
import 'edit_profile_screen.dart';

/// ARAH Profile screen — Sprint 2 redesign.
///
/// Section order (per the agreement with Disha Sharma):
///   1. Header      — avatar, full name, username, verified badge,
///                     experience level, bio, Edit Profile button
///   2. Skills
///   3. Statistics  — Trust Score, Response Rate, Avg. Completion Time,
///                     Tasks Completed (ALL system-generated, read-only)
///   4. Portfolio & Links
///   5. Reviews
///
/// The old "Settings" section at the bottom of this screen has been
/// removed — Settings already lives in the AppBar (gear icon) and having
/// it twice was redundant with the new, more marketplace-like layout.
class UserProfileScreen extends StatefulWidget {
  final bool isSeller;
  const UserProfileScreen({super.key, this.isSeller = false});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  @override
  void initState() {
    super.initState();
    // Refresh system-generated stats every time the Profile tab is opened.
    // Cheap and safe to repeat — see UserStatsService.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<UserProvider>().loadStats();
    });
  }

  void _showPickerOptions(BuildContext context) {
    final userProvider = context.read<UserProvider>();
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Photo Gallery'),
                onTap: () {
                  userProvider.pickAndUploadImage(ImageSource.gallery);
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Camera'),
                onTap: () {
                  userProvider.pickAndUploadImage(ImageSource.camera);
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openLink(String url) async {
    if (url.isEmpty) return;
    final uri = Uri.tryParse(
      url.startsWith('http') ? url : 'https://$url',
    );
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open link')),
        );
      }
    }
  }

  void _goToEditProfile(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const EditProfileScreen()),
    );
  }

  /// Formats minutes as a friendly duration, or a "not enough data" label
  /// when the underlying stat hasn't been computed yet. Never a fake number.
  String _formatCompletionTime(double? minutes) {
    if (minutes == null) return '—';
    if (minutes < 60) return '${minutes.round()}m';
    final hours = minutes / 60;
    if (hours < 24) return '${hours.toStringAsFixed(hours < 10 ? 1 : 0)}h';
    return '${(hours / 24).toStringAsFixed(1)}d';
  }

  String _formatResponseRate(double? rate) {
    if (rate == null) return '—';
    return '${(rate * 100).round()}%';
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
      print("photo = ${userProvider.photoUrl}");
  print("bio = ${userProvider.bio}");
  print("skills = ${userProvider.skills}");
  print("github = ${userProvider.githubUrl}");
  print("badge = ${userProvider.showVerifiedBadge}");
    final profileImage = userProvider.profileImageFile;
    final userName = userProvider.name;
    final username = userProvider.username;
    final bio = userProvider.bio;
    final age = userProvider.age;
    final country = userProvider.country;
    final photoUrl = userProvider.photoUrl;
    final hasGithubLink = userProvider.githubUrl.isNotEmpty;
    final hasLinkedinLink = userProvider.linkedinUrl.isNotEmpty;
    final hasPortfolioLink = userProvider.portfolioUrl.isNotEmpty;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          "Profile",
          style: TextStyle(
            color: Theme.of(context).textTheme.bodyLarge?.color,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        actions: [
          // Settings lives here — intentionally not duplicated below.
          IconButton(
            icon: Icon(CupertinoIcons.gear_alt,
                color: Theme.of(context).textTheme.bodyMedium?.color),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      bottomNavigationBar:
          ArahBottomNavBar(currentIndex: 3, isSeller: widget.isSeller),
      body: Container(
  color: Theme.of(context).scaffoldBackgroundColor,
  child: SafeArea(
    child: SingleChildScrollView(
    
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              
              // ═══ 1. HEADER ═══════════════════════════════════════════
        
        
_buildHeader(
  context,
  profileImage: profileImage,
  photoUrl: photoUrl,
  userName: userName,
  username: username,
  bio: bio,
  isVerified: userProvider.showVerifiedBadge,
  experienceLevel: userProvider.experienceLevel,
  age: age,
  country: country,
),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20.0, vertical: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ═══ 2. SKILLS ═══════════════════════════════════════
                    Text(
                      "Skills",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (userProvider.skills.isEmpty)
                      Text(
                        "No skills added yet.",
                        style: TextStyle(
                            color: Theme.of(context).textTheme.bodyMedium?.color,
                            fontSize: 13),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: userProvider.skills
                            .map(
                              (skill) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).cardColor,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: Theme.of(context).dividerColor),
                                ),
                                child: Text(
                                  skill,
                                  style: TextStyle(
                                    color: Theme.of(context).textTheme.bodyMedium?.color,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),

                    const SizedBox(height: 32),

                    // ═══ 3. STATISTICS (system-generated, read-only) ═══════
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Statistics",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                            fontSize: 15,
                          ),
                        ),
                        if (userProvider.isLoadingStats)
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricCard(
                            "${userProvider.trustScore}",
                            "Trust Score",
                            Theme.of(context).textTheme.bodyLarge?.color ?? AppTheme.navyBlue,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildMetricCard(
                            "${userProvider.tasksCompleted}",
                            "Tasks Completed",
                            AppTheme.colorsOf(context).success,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricCard(
                            _formatResponseRate(userProvider.responseRate),
                            "Response Rate",
                            Theme.of(context).textTheme.bodyLarge?.color ?? AppTheme.navyBlue,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildMetricCard(
                            _formatCompletionTime(
                                userProvider.avgCompletionTimeMinutes),
                            "Avg. Completion Time",
                            Theme.of(context).textTheme.bodyLarge?.color ?? AppTheme.navyBlue,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // ═══ 4. PORTFOLIO & LINKS ═══════════════════════════
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Portfolio & Links",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                            fontSize: 15,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _goToEditProfile(context),
                          child: Icon(
                            Icons.edit_outlined,
                            size: 18,
                            color: Theme.of(context).textTheme.bodyMedium?.color,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (!hasPortfolioLink && !hasGithubLink && !hasLinkedinLink)
                      Text(
                        "No links added yet.",
                        style: TextStyle(
                            color: Theme.of(context).textTheme.bodyMedium?.color,
                            fontSize: 13),
                      )
                    else ...[
                      if (hasPortfolioLink) ...[
                        _buildLinkCard(
                          Icons.language_rounded,
                          "Portfolio",
                          url: userProvider.portfolioUrl,
                          onTap: () => _openLink(userProvider.portfolioUrl),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (hasGithubLink) ...[
                        _buildLinkCard(
                          Icons.device_hub_outlined,
                          "GitHub Profile",
                          url: userProvider.githubUrl,
                          onTap: () => _openLink(userProvider.githubUrl),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (hasLinkedinLink)
                        _buildLinkCard(
                          Icons.business_center_outlined,
                          "LinkedIn Profile",
                          isLinkedIn: true,
                          url: userProvider.linkedinUrl,
                          onTap: () => _openLink(userProvider.linkedinUrl),
                        ),
                    ],

                    const SizedBox(height: 32),

                    // ═══ 5. REVIEWS ══════════════════════════════════════
                    Text(
                      "Reviews",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (userProvider.uid.isEmpty)
                      const Center(child: CircularProgressIndicator())
                    else
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('users')
                            .doc(userProvider.uid)
                            .collection('ratings')
                            .orderBy('createdAt', descending: true)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
  return Text(
    "Loading reviews...",
    style: TextStyle(
      color: Theme.of(context).textTheme.bodyMedium?.color,
      fontSize: 13,
    ),
  );
}

if (snapshot.hasError) {
  return Text(
    "Unable to load reviews.",
    style: TextStyle(
      color: Theme.of(context).textTheme.bodyMedium?.color,
      fontSize: 13,
    ),
  );
}
                          final docs = snapshot.data!.docs;
                          if (docs.isEmpty) {
                            return Text(
                              "No reviews yet.",
                              style: TextStyle(
                                  color: Theme.of(context).textTheme.bodyMedium?.color),
                            );
                          }
                          return Column(
                            children: docs.map((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              final rating =
                                  (data['rating'] as num?)?.toDouble() ?? 0.0;
                              final reviewText =
                                  data['reviewText'] as String? ?? '';
                              if (reviewText.isEmpty && rating == 0) {
                                return const SizedBox.shrink();
                              }

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).cardColor,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                      color: Theme.of(context).dividerColor),
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.star,
                                            color: AppTheme.colorsOf(context).warning,
                                            size: 18),
                                        const SizedBox(width: 4),
                                        Text(
                                          rating.toStringAsFixed(1),
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Theme.of(context).textTheme.bodyLarge?.color),
                                        ),
                                      ],
                                    ),
                                    if (reviewText.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        reviewText,
                                        style: TextStyle(
                                            color: Theme.of(context).textTheme.bodyMedium?.color,
                                            fontSize: 13),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
Widget _buildHeader(
  BuildContext context, {
  required File? profileImage,
  required String? photoUrl,
  required String userName,
  required String username,
  required String bio,
  required bool isVerified,
  required String experienceLevel,
  required int? age,
  required String country, 
}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      padding: const EdgeInsets.only(
          left: 20, right: 20, top: 8, bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
  onTap: () {
    if (profileImage == null &&
        (photoUrl == null || photoUrl.isEmpty)) {
      _showPickerOptions(context);
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileImageViewer(
          profileImage: profileImage,
          photoUrl: photoUrl,
          onChangePhoto: () {
            _showPickerOptions(context);
          },
        ),
      ),
    );
  },
  child: Hero(
    tag: "profile_photo",
    child: Container(
      width: 80,
      height: 80,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        shape: BoxShape.circle,
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white.withOpacity(0.12)
              : Colors.black.withOpacity(0.08),
          width: 2,
        ),
        image: profileImage != null
            ? DecorationImage(
                image: FileImage(profileImage),
                fit: BoxFit.cover,
              )
            : (photoUrl != null && photoUrl.isNotEmpty
                ? DecorationImage(
                    image: NetworkImage(photoUrl),
                    fit: BoxFit.cover,
                  )
                : null),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(
              Theme.of(context).brightness == Brightness.dark
                  ? 0.25
                  : 0.08,
            ),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: (profileImage == null &&
              (photoUrl == null || photoUrl.isEmpty))
          ? Text(
              userName.isNotEmpty
                  ? userName[0].toUpperCase()
                  : "A",
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyLarge?.color,
                fontSize: 36,
                fontWeight: FontWeight.bold,
              ),
            )
          : null,
    ),
  ),
),
 const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            userName.isNotEmpty ? userName : 'Your Name',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).textTheme.bodyLarge?.color,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Verified badge is EARNED — see UserModel.isVerified.
                        // It is never shown just because Firebase email
                        // verification succeeded.
                        if (isVerified) ...[
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.verified,
                            color: Colors.blueAccent,
                            size: 18,
                          ),
                        ],
                      ],
                    ),
                    if (username.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        '@$username',
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        experienceLevel,
                        
                        style: const TextStyle(
                          color: Colors.blueAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

if (age != null || country.isNotEmpty)
  Padding(
    padding: const EdgeInsets.only(top: 2),
    child: Row(
      children: [
        if (age != null)
          Text(
            "Age: $age",
            style: TextStyle(
              color: Theme.of(context).textTheme.bodyMedium?.color,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        if (age != null && country.isNotEmpty)
          Text(
            "  ·  ",
            style: TextStyle(
              color: Theme.of(context).textTheme.bodyMedium?.color,
              fontSize: 13,
            ),
          ),
        if (country.isNotEmpty)
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 14,
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
                const SizedBox(width: 2),
                Flexible(
                  child: Text(
                    country,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  ),
          const SizedBox(height: 14),
          Text(
            bio.isNotEmpty ? bio : 'No bio added yet. Tap Edit Profile to add one.',
            style: TextStyle(
              color: Theme.of(context).textTheme.bodyMedium?.color,
              fontSize: 13,

              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),

        ],
      ),
    );
  }

  Widget _buildMetricCard(String value, String label, Color valueColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
        boxShadow: [
          BoxShadow(
            color: AppTheme.colorsOf(context).shadow,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).textTheme.bodyMedium?.color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// Renders a single existing link. Only called for links that are already
  /// set, so this always shows the "open" affordance — no add/"+" state.
  Widget _buildLinkCard(
    IconData icon,
    String title, {
    bool isLinkedIn = false,
    String url = '',
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Theme.of(context).dividerColor),
          boxShadow: [
            BoxShadow(
              color: AppTheme.colorsOf(context).shadow,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            isLinkedIn
                ? Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      "in",
                      style: TextStyle(
                        color: Color(0xFF0077B5),
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  )
                : Icon(icon,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                    size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    url,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.arahPurple,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.open_in_new,
              color: AppTheme.arahPurple,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

}
