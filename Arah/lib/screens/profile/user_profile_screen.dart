import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../app/theme/app_theme.dart';
import '../../app/widgets/bottom_nav_bar.dart';
import '../../provider/user_provider.dart';
import '../../services/auth_service.dart';
import '../auth/login_screen.dart';
import 'settings_screen.dart';
// NOTE: adjust this path if edit_profile_screen.dart lives somewhere else.
import 'edit_profile_screen.dart';

class UserProfileScreen extends StatefulWidget {
  final bool isSeller;
  const UserProfileScreen({super.key, this.isSeller = false});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  void _showPickerOptions(BuildContext context) {
    final userProvider = context.read<UserProvider>();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
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

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final profileImage = userProvider.profileImageFile;
    final userName = userProvider.name;
    final bio = userProvider.bio;
    final photoUrl = userProvider.photoUrl;
    final hasGithubLink = userProvider.githubUrl.isNotEmpty;
    final hasLinkedinLink = userProvider.linkedinUrl.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          "Profile",
          style: TextStyle(
            color: AppTheme.navyBlue,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(CupertinoIcons.gear_alt, color: Colors.blueGrey),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      bottomNavigationBar:
          ArahBottomNavBar(currentIndex: 3, isSeller: widget.isSeller),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── Top White Card ───────────────────────────────────────
              Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(24),
                    bottomRight: Radius.circular(24),
                  ),
                ),
                padding:
                    const EdgeInsets.only(left: 20, right: 20, bottom: 30),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: () => _showPickerOptions(context),
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: const Color(0xFF6A4BFF),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
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
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: (profileImage == null &&
                                (photoUrl == null || photoUrl.isEmpty))
                            ? Text(
                                userName.isNotEmpty ? userName[0].toUpperCase() : "A",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                userName.isNotEmpty ? userName : 'Your Name',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.navyBlue,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.verified,
                                color: Colors.blueAccent,
                                size: 18,
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            bio.isNotEmpty
                                ? bio
                                : 'No bio added yet. Tap settings to edit.',
                            style: TextStyle(
                              color: Colors.blueGrey.shade400,
                              fontSize: 13,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.blueAccent.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              userProvider.experienceLevel,
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
              ),

              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20.0, vertical: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ─── Metrics ───────────────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricCard(
                              "12", "Tasks Completed", const Color(0xFF10B981)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildMetricCard(
                              "98%", "Trust Score", AppTheme.navyBlue),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricCard(
                              "1h", "Response Rate", AppTheme.navyBlue),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildMetricCard(
                              "100%", "Completion Rate", AppTheme.navyBlue),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // ─── Skills ────────────────────────────────────────
                    const Text(
                      "My Skills",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.navyBlue,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: (userProvider.skills.isEmpty
                              ? ["Python", "Figma", "UI/UX", "Data Analysis", "React"]
                              : userProvider.skills)
                          .map(
                            (skill) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: const Color(0xFFE2E8F0)),
                              ),
                              child: Text(
                                skill,
                                style: TextStyle(
                                  color: Colors.blueGrey.shade600,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),

                    const SizedBox(height: 32),

                    // ─── Portfolio Links ───────────────────────────────
                    // Read-only here — all adding/editing/deleting of links
                    // happens in Edit Profile. The pencil icon just deep-links
                    // there; there is no inline "+" add affordance anymore.
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Portfolio & Links",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.navyBlue,
                            fontSize: 15,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _goToEditProfile(context),
                          child: Icon(
                            Icons.edit_outlined,
                            size: 18,
                            color: Colors.blueGrey.shade400,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (!hasGithubLink && !hasLinkedinLink)
                      Text(
                        "No links added yet.",
                        style: TextStyle(
                            color: Colors.blueGrey.shade400, fontSize: 13),
                      )
                    else ...[
                      if (hasGithubLink)
                        _buildLinkCard(
                          Icons.device_hub_outlined,
                          "GitHub Profile",
                          url: userProvider.githubUrl,
                          onTap: () => _openLink(userProvider.githubUrl),
                        ),
                      if (hasGithubLink && hasLinkedinLink)
                        const SizedBox(height: 12),
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

                    // ─── Reviews ───────────────────────────────────────
                    const Text(
                      "Reviews",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.navyBlue,
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
                        if (!snapshot.hasData) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        final docs = snapshot.data!.docs;
                        if (docs.isEmpty) {
                          return Text(
                            "No reviews yet.",
                            style: TextStyle(color: Colors.blueGrey.shade400),
                          );
                        }
                        return Column(
                          children: docs.map((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            final rating = (data['rating'] as num?)?.toDouble() ?? 0.0;
                            final reviewText = data['reviewText'] as String? ?? '';
                            if (reviewText.isEmpty && rating == 0) return const SizedBox.shrink();
                            
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.star, color: Color(0xFFF59E0B), size: 18),
                                      const SizedBox(width: 4),
                                      Text(
                                        rating.toStringAsFixed(1),
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                  if (reviewText.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      reviewText,
                                      style: TextStyle(color: Colors.blueGrey.shade700, fontSize: 13),
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

                    // ─── Settings ──────────────────────────────────────
                    const Text(
                      "Settings",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.navyBlue,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.01),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          _buildSettingsTile(
                            Icons.settings_outlined,
                            "Advanced Settings",
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const SettingsScreen(),
                              ),
                            ),
                          ),
                          const Divider(
                              height: 1,
                              thickness: 1,
                              color: Color(0xFFF1F5F9)),
                          _buildSettingsTile(
                            Icons.logout,
                            "Log Out",
                            isDestructive: true,
                            onTap: () => _confirmLogout(context),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard(String value, String label, Color valueColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.01),
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
              color: Colors.blueGrey.shade500,
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.01),
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
                      color: Colors.white,
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
                : Icon(icon, color: AppTheme.navyBlue, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppTheme.navyBlue,
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

  Widget _buildSettingsTile(
    IconData icon,
    String title, {
    bool isDestructive = false,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isDestructive ? const Color(0xFFEF4444) : AppTheme.navyBlue,
        size: 22,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isDestructive ? const Color(0xFFEF4444) : AppTheme.navyBlue,
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
      ),
      trailing: isDestructive
          ? null
          : const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
      onTap: onTap,
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Log Out',
            style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.navyBlue)),
        content: const Text(
          'Are you sure you want to log out?',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: TextStyle(color: Colors.blueGrey.shade500)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final authService = FirebaseAuthService();
              await authService.signOut();
              context.read<UserProvider>().clearUser();
              if (!context.mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 40),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
  }
}