// ============================================================================
// ARAH — Edit Profile Screen (Sprint 2 redesign)
// ----------------------------------------------------------------------------
// Per the agreement with Disha Sharma, this screen edits EXACTLY these
// fields and no others:
//   Username · Bio · College · Skills · GitHub · LinkedIn · Portfolio
//
// Explicitly NOT here (by design, not oversight):
//   • Date of Birth     — set once at registration, never editable again.
//   • Experience Level  — collected at registration; not part of the
//                          agreed Edit Profile scope.
//   • Trust Score / Response Rate / Tasks Completed / Reviews / Verification
//     — system-generated, never a form field anywhere in the app.
// ============================================================================
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:arah_app/provider/user_provider.dart';
import '../../app/theme/app_theme.dart';

class _Palette {
  static const Color primary = AppTheme.arahPurple;
  static Color background(BuildContext context) =>
      Theme.of(context).scaffoldBackgroundColor;
  static Color card(BuildContext context) => Theme.of(context).cardColor;
  static Color textPrimary(BuildContext context) =>
      Theme.of(context).textTheme.bodyLarge?.color ?? AppTheme.navyBlue;
  static Color textSecondary(BuildContext context) =>
      Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black54;
  static const Color error = AppTheme.alertRed;
  static const Color success = AppTheme.successGreen;
}

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _usernameController;
  late TextEditingController _bioController;
  late TextEditingController _collegeController;
  late TextEditingController _githubController;
  late TextEditingController _linkedinController;
  late TextEditingController _portfolioController;
  late TextEditingController _skillInputController;

  static const int _bioMaxLength = 250;

  List<String> _skills = [];
  bool _showOtherSkillInput = false;

  bool _isSaving = false;
  bool _isUploadingImage = false;

  static const List<String> _predefinedSkills = [
   'Flutter',
  'Dart',
  'Firebase',
  'Android Development',
  'iOS Development',
  'Mobile Development',
  'Web Development',
  'React',
  'JavaScript',
  'UI/UX Design',
  'Figma',
  'Graphic Design',
  'Content Writing',
  'Digital Marketing',
  'Data Analysis',
  'Machine Learning',
  'Artificial Intelligence',
  'Python',
  'Java',
  'C++',
  'SQL',
  'Git/GitHub',
  'Backend Development',
  'Node.js',
  'Project Management',
  'Video Editing',
  'Photography',
  ];

  @override
  void initState() {
    super.initState();
    _initializeFromProvider();
  }

  void _initializeFromProvider() {
    final provider = context.read<UserProvider>();

    _usernameController = TextEditingController(text: provider.username);
    _bioController = TextEditingController(text: provider.bio);
    _collegeController = TextEditingController(text: provider.collegeName);
    _githubController = TextEditingController(text: provider.githubUrl);
    _linkedinController = TextEditingController(text: provider.linkedinUrl);
    _portfolioController = TextEditingController(text: provider.portfolioUrl);
    _skillInputController = TextEditingController();

    _skills = List<String>.from(provider.skills);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _bioController.dispose();
    _collegeController.dispose();
    _githubController.dispose();
    _linkedinController.dispose();
    _portfolioController.dispose();
    _skillInputController.dispose();
    super.dispose();
  }

  double _profileCompletion(UserProvider provider) {
    final hasPhoto = provider.profileImageFile != null ||
        (provider.photoUrl?.isNotEmpty ?? false);
    final checks = <bool>[
      hasPhoto,
      _bioController.text.trim().isNotEmpty,
      _collegeController.text.trim().isNotEmpty,
      _skills.isNotEmpty,
      _githubController.text.trim().isNotEmpty ||
          _linkedinController.text.trim().isNotEmpty ||
          _portfolioController.text.trim().isNotEmpty,
    ];
    final completed = checks.where((c) => c).length;
    return completed / checks.length;
  }

  Future<void> _handleEditPhoto() async {
    setState(() => _isUploadingImage = true);
    try {
      await context.read<UserProvider>().pickAndUploadImage(ImageSource.gallery);
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  void _toggleSkill(String skill) {
    setState(() {
      if (_skills.contains(skill)) {
        _skills.remove(skill);
      } else {
        _skills.add(skill);
      }
    });
  }

  void _toggleOtherSkillInput() {
    setState(() => _showOtherSkillInput = !_showOtherSkillInput);
  }

  void _addCustomSkill(String rawValue) {
    final value = rawValue.trim();
    if (value.isEmpty) return;
    if (_skills.any((s) => s.toLowerCase() == value.toLowerCase())) {
      _skillInputController.clear();
      setState(() => _showOtherSkillInput = false);
      return;
    }
    setState(() {
      _skills.add(value);
      _skillInputController.clear();
      _showOtherSkillInput = false;
    });
  }

  String? _validateUrl(String? value) {
    if (value == null || value.trim().isEmpty) return null; // optional fields
    final uri = Uri.tryParse(value.trim());
    final isValid =
        uri != null && uri.hasAbsolutePath && uri.scheme.startsWith('http');
    return isValid ? null : 'Enter a valid URL (starting with https://)';
  }

  String? _validateUsername(String? value) {
    if (value == null || value.trim().isEmpty) return 'Enter a username';
    if (value.trim().length < 3) return 'Username must be at least 3 characters';
    return null;
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() => _isSaving = true);

    try {
      // Only the 7 agreed fields are ever sent from this screen.
      await context.read<UserProvider>().updateProfile(
            username: _usernameController.text.trim(),
            bio: _bioController.text.trim(),
            collegeName: _collegeController.text.trim(),
            skills: _skills,
            githubUrl: _githubController.text.trim(),
            linkedinUrl: _linkedinController.text.trim(),
            portfolioUrl: _portfolioController.text.trim(),
          );

      if (!mounted) return;
      _showSnackBar('Profile updated successfully.');
      Navigator.of(context).maybePop();
    } catch (e) {
      _showSnackBar('Something went wrong while saving. Please try again.',
          isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? _Palette.error : _Palette.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<UserProvider>();

    return Scaffold(
      backgroundColor: _Palette.background(context),
      appBar: AppBar(
        title: const Text('Edit Profile'),
        automaticallyImplyLeading: false,
  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
  surfaceTintColor: Colors.transparent,
  scrolledUnderElevation: 0,
  elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              ProfileHeaderSection(
                photoFile: provider.profileImageFile,
                photoUrl: provider.photoUrl,
                name: provider.name,
                isVerified: provider.isVerified,
                isUploading: _isUploadingImage,
                onEditPhoto: _handleEditPhoto,
              ),
              const SizedBox(height: 20),
              ProfileCompletionCard(completion: _profileCompletion(provider)),
              const SizedBox(height: 20),
              SectionCard(
                title: 'Username',
                child: TextFormField(
                  controller: _usernameController,
                  validator: _validateUsername,
                  style: TextStyle(fontSize: 14, color: _Palette.textPrimary(context)),
                  decoration: _fieldDecoration('e.g. jordan_dev'),
                ),
              ),
              const SizedBox(height: 20),
              AboutSectionCard(
                controller: _bioController,
                maxLength: _bioMaxLength,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 20),
              SectionCard(
                title: 'College',
                child: TextFormField(
                  controller: _collegeController,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Enter your college name'
                      : null,
                  style: TextStyle(fontSize: 14, color: _Palette.textPrimary(context)),
                  decoration: _fieldDecoration('e.g. XYZ University'),
                ),
              ),
              const SizedBox(height: 20),
              ProfessionalLinksCard(
                githubController: _githubController,
                linkedinController: _linkedinController,
                portfolioController: _portfolioController,
                validator: _validateUrl,
                onChanged: () => setState(() {}),
              ),
              const SizedBox(height: 20),
              SkillsCard(
                predefinedSkills: _predefinedSkills,
                selectedSkills: _skills,
                showOtherInput: _showOtherSkillInput,
                inputController: _skillInputController,
                onToggleSkill: _toggleSkill,
                onToggleOtherInput: _toggleOtherSkillInput,
                onAddCustomSkill: _addCustomSkill,
              ),
              const SizedBox(height: 28),
              SaveProfileButton(
                isSaving: _isSaving,
                onPressed: _isSaving ? null : _handleSave,
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: _Palette.textSecondary(context).withOpacity(0.7)),
        filled: true,
        fillColor: _Palette.background(context),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.all(14),
      );
}

// =============================================================================
// SHARED CARD WRAPPER
// =============================================================================

class SectionCard extends StatelessWidget {
  const SectionCard({super.key, required this.child, this.title, this.trailing});

  final Widget child;
  final String? title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _Palette.card(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.colorsOf(context).shadow,
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title!,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _Palette.textPrimary(context),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 14),
          ],
          child,
        ],
      ),
    );
  }
}

// =============================================================================
// PROFILE HEADER (photo only — name/verified are read-only display)
// =============================================================================

class ProfileHeaderSection extends StatelessWidget {
  const ProfileHeaderSection({
    super.key,
    required this.photoFile,
    required this.photoUrl,
    required this.name,
    required this.isVerified,
    required this.isUploading,
    required this.onEditPhoto,
  });

  final File? photoFile;
  final String? photoUrl;
  final String name;
  final bool isVerified;
  final bool isUploading;
  final VoidCallback onEditPhoto;

  ImageProvider? _resolveImage() {
    if (photoFile != null) return FileImage(photoFile!);
    if (photoUrl != null && photoUrl!.isNotEmpty) return NetworkImage(photoUrl!);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final image = _resolveImage();
    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _Palette.primary, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: _Palette.primary.withOpacity(0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipOval(
                child: image != null
                    ? Image(image: image, fit: BoxFit.cover)
                    : Container(
                        color: _Palette.primary.withOpacity(0.1),
                        child: Icon(Icons.person_rounded,
                            size: 56, color: _Palette.primary.withOpacity(0.6)),
                      ),
              ),
            ),
            if (isUploading)
              const Positioned.fill(
                child: CircleAvatar(
                  backgroundColor: Colors.black45,
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  ),
                ),
              ),
            Positioned(
              bottom: 0,
              right: 0,
              child: GestureDetector(
                onTap: onEditPhoto,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _Palette.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: _Palette.background(context), width: 2),
                  ),
                  child: const Icon(Icons.camera_alt_rounded,
                      size: 16, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                name,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: _Palette.textPrimary(context),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isVerified) ...[
              const SizedBox(width: 6),
              const Icon(Icons.verified_rounded, size: 18, color: Colors.blueAccent),
            ],
          ],
        ),
      ],
    );
  }
}

// =============================================================================
// PROFILE COMPLETION
// =============================================================================

class ProfileCompletionCard extends StatelessWidget {
  const ProfileCompletionCard({super.key, required this.completion});

  final double completion;

  @override
  Widget build(BuildContext context) {
    final percent = (completion * 100).round();
    return SectionCard(
      title: 'Profile Completion',
      trailing: Text('$percent%',
          style: const TextStyle(fontWeight: FontWeight.w700, color: _Palette.primary)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: LinearProgressIndicator(
          value: completion,
          minHeight: 8,
          backgroundColor: _Palette.primary.withOpacity(0.1),
          valueColor: const AlwaysStoppedAnimation(_Palette.primary),
        ),
      ),
    );
  }
}

// =============================================================================
// ABOUT / BIO
// =============================================================================

class AboutSectionCard extends StatelessWidget {
  const AboutSectionCard({
    super.key,
    required this.controller,
    required this.maxLength,
    required this.onChanged,
  });

  final TextEditingController controller;
  final int maxLength;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'About',
      child: TextField(
        controller: controller,
        maxLength: maxLength,
        maxLines: 4,
        onChanged: onChanged,
        style: TextStyle(fontSize: 14, color: _Palette.textPrimary(context)),
        decoration: InputDecoration(
          hintText: 'Tell clients about your experience and expertise…',
          hintStyle: TextStyle(color: _Palette.textSecondary(context).withOpacity(0.7)),
          filled: true,
          fillColor: _Palette.background(context),
          counterStyle: TextStyle(color: _Palette.textSecondary(context), fontSize: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.all(14),
        ),
      ),
    );
  }
}

// =============================================================================
// PROFESSIONAL LINKS
// =============================================================================

class ProfessionalLinksCard extends StatelessWidget {
  const ProfessionalLinksCard({
    super.key,
    required this.githubController,
    required this.linkedinController,
    required this.portfolioController,
    required this.validator,
    required this.onChanged,
  });

  final TextEditingController githubController;
  final TextEditingController linkedinController;
  final TextEditingController portfolioController;
  final String? Function(String?) validator;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Portfolio & Links',
      child: Column(
        children: [
          _LinkField(
            label: 'Portfolio',
            icon: Icons.language_rounded,
            controller: portfolioController,
            hint: 'https://yourportfolio.com',
            validator: validator,
            onChanged: onChanged,
          ),
          const SizedBox(height: 14),
          _LinkField(
            label: 'GitHub',
            icon: Icons.code_rounded,
            controller: githubController,
            hint: 'https://github.com/yourhandle',
            validator: validator,
            onChanged: onChanged,
          ),
          const SizedBox(height: 14),
          _LinkField(
            label: 'LinkedIn',
            icon: Icons.business_center_outlined,
            controller: linkedinController,
            hint: 'https://linkedin.com/in/yourname',
            validator: validator,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _LinkField extends StatelessWidget {
  const _LinkField({
    required this.label,
    required this.icon,
    required this.controller,
    required this.hint,
    required this.validator,
    required this.onChanged,
  });

  final String label;
  final IconData icon;
  final TextEditingController controller;
  final String hint;
  final String? Function(String?) validator;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 12.5, fontWeight: FontWeight.w600, color: _Palette.textSecondary(context))),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: TextInputType.url,
          validator: validator,
          onChanged: (_) => onChanged(),
          style: TextStyle(fontSize: 14, color: _Palette.textPrimary(context)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: _Palette.textSecondary(context).withOpacity(0.6), fontSize: 13),
            prefixIcon: Icon(icon, size: 18, color: _Palette.textSecondary(context)),
            filled: true,
            fillColor: _Palette.background(context),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// SKILLS
// =============================================================================

class SkillsCard extends StatelessWidget {
  const SkillsCard({
    super.key,
    required this.predefinedSkills,
    required this.selectedSkills,
    required this.showOtherInput,
    required this.inputController,
    required this.onToggleSkill,
    required this.onToggleOtherInput,
    required this.onAddCustomSkill,
  });

  final List<String> predefinedSkills;
  final List<String> selectedSkills;
  final bool showOtherInput;
  final TextEditingController inputController;
  final ValueChanged<String> onToggleSkill;
  final VoidCallback onToggleOtherInput;
  final ValueChanged<String> onAddCustomSkill;

  @override
  Widget build(BuildContext context) {
    final displaySkills = <String>[
      ...predefinedSkills,
      ...selectedSkills.where((s) => !predefinedSkills.contains(s)),
    ];

    return SectionCard(
      title: 'Skills',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Choose all that apply',
              style: TextStyle(fontSize: 13, color: _Palette.textSecondary(context))),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ...displaySkills.map(
                (skill) => _SkillToggleChip(
                  label: skill,
                  isSelected: selectedSkills.contains(skill),
                  onTap: () => onToggleSkill(skill),
                ),
              ),
              _SkillToggleChip(
                label: 'Other',
                isSelected: showOtherInput,
                icon: Icons.add_rounded,
                onTap: onToggleOtherInput,
              ),
            ],
          ),
          if (showOtherInput) ...[
            const SizedBox(height: 14),
            TextField(
              controller: inputController,
              autofocus: true,
              textInputAction: TextInputAction.done,
              onSubmitted: onAddCustomSkill,
              inputFormatters: [LengthLimitingTextInputFormatter(30)],
              decoration: InputDecoration(
                hintText: 'Type your skill, e.g. Video Editing',
                hintStyle:
                    TextStyle(fontSize: 13, color: _Palette.textSecondary(context).withOpacity(0.7)),
                filled: true,
                fillColor: _Palette.background(context),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.check_circle_rounded, color: _Palette.primary),
                  onPressed: () => onAddCustomSkill(inputController.text),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SkillToggleChip extends StatelessWidget {
  const _SkillToggleChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? _Palette.primary.withOpacity(0.08) : _Palette.card(context),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? _Palette.primary : Theme.of(context).dividerColor,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null)
              Icon(icon,
                  size: 15, color: isSelected ? _Palette.primary : _Palette.textSecondary(context))
            else if (isSelected)
              const Icon(Icons.check_circle_rounded, size: 15, color: _Palette.primary),
            if (icon != null || isSelected) const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? _Palette.primary : _Palette.textPrimary(context),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                fontSize: 13.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// SAVE BUTTON
// =============================================================================

class SaveProfileButton extends StatelessWidget {
  const SaveProfileButton({super.key, required this.isSaving, required this.onPressed});

  final bool isSaving;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _Palette.primary,
          disabledBackgroundColor: _Palette.primary.withOpacity(0.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        child: isSaving
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              )
            : const Text('Save Changes',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
      ),
    );
  }
}
