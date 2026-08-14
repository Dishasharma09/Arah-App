import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app/theme/app_theme.dart';
import '../../provider/user_provider.dart';
import '../../services/auth_service.dart';
import '../auth/login_screen.dart';
import '../home/home_screen.dart';
import '../home/seller_home_screen.dart';
import 'edit_profile_screen.dart';
import '../../provider/theme_provider.dart';
import 'notifications_settings_screen.dart';
import 'privacy_security_screen.dart';
import 'change_password_screen.dart';
import 'privacy_policy_screen.dart';
import 'terms_conditions_screen.dart';
import 'contact_us_screen.dart';
import 'feedback_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    return Scaffold(
backgroundColor: Theme.of(context).scaffoldBackgroundColor,
appBar: AppBar(
  automaticallyImplyLeading: false,
  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
  surfaceTintColor: Colors.transparent,
  scrolledUnderElevation: 0,
  elevation: 0,  foregroundColor: Theme.of(context).appBarTheme.iconTheme?.color,

  title: Text(
    'Settings',
    style: TextStyle(
      fontWeight: FontWeight.bold,
      fontSize: 20,
      color: Theme.of(context).textTheme.titleLarge?.color,
    ),
  ),

  leading: IconButton(
    icon: const Icon(Icons.arrow_back_ios_new, size: 20),
    onPressed: () => Navigator.pop(context),
  ),
),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionLabel('Account'),
            _buildCard([
              _buildTile(
                icon: Icons.person_outline,
                title: 'Edit Profile',
                subtitle: 'Update your name, bio, skills & links',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                ),
              ),
            ]),
            const SizedBox(height: 20),
            _sectionLabel('Security'),
            _buildCard([
              _buildTile(
                icon: Icons.password_outlined,
                title: 'Change Password',
                subtitle: 'Update your account password',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
                ),
              ),
Divider(
  height: 1,
  color: Theme.of(context).dividerColor,
),              _buildTile(
                icon: Icons.lock_outline,
                title: 'Privacy & Security',
                subtitle: 'Password, account visibility',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const PrivacySecurityScreen()),
                ),
              ),
            ]),
            const SizedBox(height: 20),
            _sectionLabel('Preferences'),
            _buildCard([
              _buildTile(
                icon: Icons.notifications_none_outlined,
                title: 'Notifications',
                subtitle: 'Manage alerts and push notifications',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const NotificationsSettingsScreen()),
                ),
              ),
Divider(
  height: 1,
  color: Theme.of(context).dividerColor,
),          _buildSwitchTile(
  icon: Icons.dark_mode_outlined,
  title: 'Dark Mode',
  subtitle: 'Toggle app appearance',
  value: themeProvider.isDarkMode,
  onChanged: (val) {
    context.read<ThemeProvider>().toggleTheme(val);
  },
),
            ]),
            const SizedBox(height: 20),
            _sectionLabel('Support'),
            _buildCard([
              _buildTile(
                icon: Icons.support_agent_outlined,
                title: 'Contact Us',
                subtitle: 'Get in touch with our team',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ContactUsScreen()),
                ),
              ),
Divider(
  height: 1,
  color: Theme.of(context).dividerColor,
),
              _buildTile(
                icon: Icons.feedback_outlined,
                title: 'Send Feedback',
                subtitle: 'Help us improve the app',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const FeedbackScreen()),
                ),
              ),
            ]),
            const SizedBox(height: 20),
            _sectionLabel('Legal'),
            _buildCard([
              _buildTile(
                icon: Icons.privacy_tip_outlined,
                title: 'Privacy Policy',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
                ),
              ),
              ListTile(

leading: const Icon(
Icons.contact_support_outlined,
),

title: const Text(
"Contact Us",
),


onTap: (){

Navigator.push(
context,
MaterialPageRoute(
builder: (_) => const ContactUsScreen(),
),
);

},

),
ListTile(

leading: const Icon(Icons.privacy_tip_outlined),

title: const Text("Privacy Policy"),

onTap: (){

Navigator.push(
context,
MaterialPageRoute(
builder: (_) => const PrivacyPolicyScreen(),
),
);

},

),


ListTile(

leading: const Icon(Icons.description_outlined),

title: const Text("Terms & Conditions"),

onTap: (){

Navigator.push(
context,
MaterialPageRoute(
builder: (_) => const TermsConditionsScreen(),
),
);

},

),
Divider(
  height: 1,
  color: Theme.of(context).dividerColor,
),              _buildTile(
                icon: Icons.description_outlined,
                title: 'Terms & Conditions',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const TermsConditionsScreen()),
                ),
              ),
            ]),
            const SizedBox(height: 20),
            _sectionLabel('About'),
            _buildCard([
              _buildInfoTile(
                icon: Icons.info_outline,
                title: 'App Version',
                value: 'Arah v1.0.0',
              ),
            ]),
            const SizedBox(height: 20),
            _sectionLabel('Developer'),
            _buildCard([
              _buildTile(
                icon: Icons.swap_horiz_rounded,
                title: 'Change Workspace',
                subtitle: 'Switch between Buyer, Seller, or Both — no need to log out',
                onTap: () => _showChangeRoleSheet(context),
              ),
            ]),
            const SizedBox(height: 20),
            _sectionLabel('Danger Zone'),
            _buildCard([
              _buildTile(
                icon: Icons.logout,
                title: 'Log Out',
                isDestructive: true,
                onTap: () => _confirmLogout(context),
              ),
            ]),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 4),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
          color: AppTheme.colorsOf(context).secondaryText,
        ),
      ),
    );
  }
  

Widget _buildCard(List<Widget> children) {
  return Container(
    decoration: BoxDecoration(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: AppTheme.colorsOf(context).shadow,
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: Column(children: children),
  );
}

  Widget _buildTile({
    required IconData icon,
    required String title,
    String? subtitle,
    bool isDestructive = false,
    required VoidCallback onTap,
  }) {
final color = isDestructive
    ? AppTheme.colorsOf(context).error
    : Theme.of(context).textTheme.bodyLarge!.color!;    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
      leading: Icon(icon, color: color, size: 22),
      title: Text(
        title,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 14.5,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.colorsOf(context).secondaryText,
              ),
            )
          : null,
      trailing: isDestructive
          ? null
          : Icon(Icons.chevron_right, color: AppTheme.colorsOf(context).secondaryText, size: 20),
      onTap: onTap,
    );
  }

  // Same look as _buildTile, but with a Switch instead of a chevron, and
  // no onTap navigation — used for the Dark Mode row.
  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
leading: Icon(
  icon,
  color: Theme.of(context).textTheme.bodyLarge?.color,
  size: 22,
),      title: Text(
        title,
     style: TextStyle(
  color: Theme.of(context).textTheme.bodyLarge?.color,
          fontWeight: FontWeight.w600,
          fontSize: 14.5,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.colorsOf(context).secondaryText,
              ),
            )
          : null,
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: AppTheme.arahPurple,
      ),
      onTap: () => onChanged(!value),
    );
  }

  // Same look as _buildTile, but non-clickable and without a chevron —
  // used for the App Version row.
  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
leading: Icon(
  icon,
  color: Theme.of(context).textTheme.bodyLarge?.color,
  size: 22,
),      title: Text(
        title,
      style: TextStyle(
  color: Theme.of(context).textTheme.bodyLarge?.color,
          fontWeight: FontWeight.w600,
          fontSize: 14.5,
        ),
      ),
      trailing: Text(
        value,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w500,
          color: AppTheme.colorsOf(context).secondaryText,
        ),
      ),
    );
  }

  // Lets the user switch their account's workspace type (Buyer / Seller /
  // Both) right here — no logout, no restart. Updates Firestore via
  // UserProvider.updateRole(), then takes them straight to the matching
  // home screen.
  void _showChangeRoleSheet(BuildContext context) {
    final userProvider = context.read<UserProvider>();
    String selected = userProvider.role;

    const options = [
      {
        'value': 'Buyer',
        'title': 'Buyer - Hire talent',
        'desc': 'Post tasks and find skilled students.',
      },
      {
        'value': 'Seller',
        'title': 'Seller - Offer skills',
        'desc': 'Offer your skills and find freelance tasks.',
      },
      {
        'value': 'Both',
        'title': 'Both',
        'desc': 'Hire and work, switch anytime from the home screen.',
      },
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Change Workspace',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Theme.of(ctx).textTheme.titleLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Switch how you use Arah. You can change this again anytime.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.colorsOf(ctx).secondaryText,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...options.map((opt) {
                    final isSelected = selected == opt['value'];
                    return GestureDetector(
                      onTap: () => setSheetState(() => selected = opt['value']!),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.arahPurple.withOpacity(0.08)
                              : Theme.of(ctx).cardColor,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected
                                ? AppTheme.arahPurple
                                : Theme.of(ctx).dividerColor,
                            width: isSelected ? 2 : 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    opt['title']!,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: isSelected
                                          ? AppTheme.arahPurple
                                          : Theme.of(ctx)
                                              .textTheme
                                              .bodyLarge
                                              ?.color,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    opt['desc']!,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: AppTheme.colorsOf(ctx).secondaryText,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isSelected)
                              Container(
                                width: 20,
                                height: 20,
                                decoration: const BoxDecoration(
                                  color: AppTheme.arahPurple,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.check,
                                    color: Colors.white, size: 13),
                              ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: selected == userProvider.role
                          ? null
                          : () async {
                              Navigator.pop(ctx);
                              try {
                                await userProvider.updateRole(selected);
                              } catch (e) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      e.toString().replaceFirst('Exception: ', ''),
                                    ),
                                    backgroundColor:
                                        AppTheme.colorsOf(context).error,
                                  ),
                                );
                                return;
                              }

                              if (!context.mounted) return;
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => selected == 'Seller'
                                      ? const SellerHomeScreen()
                                      : const BuyerHomeScreen(),
                                ),
                                (route) => false,
                              );
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.arahPurple,
                        disabledBackgroundColor: Theme.of(ctx).dividerColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Save',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Log Out',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(ctx).textTheme.titleLarge?.color)),
        content: Text(
          'Are you sure you want to log out?',
          style: TextStyle(
              fontSize: 14, color: Theme.of(ctx).textTheme.bodyMedium?.color),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: TextStyle(color: AppTheme.colorsOf(ctx).secondaryText)),
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
              backgroundColor: AppTheme.colorsOf(ctx).error,
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