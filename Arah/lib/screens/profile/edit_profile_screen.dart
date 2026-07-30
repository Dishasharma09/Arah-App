// ============================================================================
// ARAH — Edit Profile Screen
// ----------------------------------------------------------------------------
// Rewritten against your ACTUAL UserProvider and AppTheme (as provided) —
// no invented API names remain. Two things still need your attention,
// both marked with // NOTE: below:
//
//   1. Import paths at the top — adjust to match where this file lives
//      relative to your `providers/`, `theme/`, and `services/` folders.
//   2. Portfolio URL — your UserModel/UserProvider has no `portfolioUrl`
//      field yet, so that input is UI-only until you add it end-to-end.
//
// Country picking now uses the `country_picker` package (already in your
// pubspec.yaml) — full world list, built-in search, and flag emojis.
// The read-only "Role" field has been removed per request.
// ============================================================================
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:country_picker/country_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
// NOTE: adjust these three paths to match your project structure.
import 'package:arah_app/provider/user_provider.dart';
import '../../app/theme/app_theme.dart';

/// Maps this screen's design tokens onto YOUR real AppTheme constants.
/// Change values here only — never scattered through the widgets below.
class _Palette {
  static const Color primary = AppTheme.arahPurple;
  static const Color background = AppTheme.offWhite;
  static const Color card = AppTheme.pureWhite;
  static const Color textPrimary = AppTheme.navyBlue;
  static const Color textSecondary = Colors.black54;
  static const Color error = AppTheme.alertRed;
  static const Color success = AppTheme.successGreen;
}

// =============================================================================
// SCREEN
// =============================================================================

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _bioController;
  late TextEditingController _githubController;
  late TextEditingController _linkedinController;
  late TextEditingController _portfolioController; // UI-only, see header note
  late TextEditingController _skillInputController;

  static const int _bioMaxLength = 250;

  String? _selectedCountry;
  late String _selectedExperienceLevel;
  List<String> _skills = [];
  bool _isProfilePublic = true;
  bool _showOtherSkillInput = false;

  bool _isSaving = false;
  bool _isUploadingImage = false;

  // Matches UserProvider's default ('Beginner') so the Dropdown never
  // receives a value outside of this list.
  static const List<String> _experienceLevels = [
    'Beginner',
    'Intermediate',
    'Advanced',
  ];

  // Curated skill options shown as selectable chips. Adjust freely —
  // anything the user already has saved that isn't in this list still
  // shows up (see SkillsCard), so nothing gets silently dropped.
  static const List<String> _predefinedSkills = [
    'Flutter', 'Web Development', 'UI/UX Design', 'Graphic Design',
    'Content Writing', 'Translation', 'Digital Marketing', 'Video Editing',
    'Data Entry', 'Mobile App Development', 'SEO', 'Photography',
  ];

  @override
  void initState() {
    super.initState();
    _initializeFromProvider();
  }

  /// Seeds local editable state from the real UserProvider getters.
  void _initializeFromProvider() {
    final provider = context.read<UserProvider>();

    _bioController = TextEditingController(text: provider.bio);
    _githubController = TextEditingController(text: provider.githubUrl);
    _linkedinController = TextEditingController(text: provider.linkedinUrl);
    _portfolioController = TextEditingController(text: '');
    _skillInputController = TextEditingController();

    _selectedCountry = provider.country.isEmpty ? null : provider.country;
    _selectedExperienceLevel = _experienceLevels.contains(provider.experienceLevel)
        ? provider.experienceLevel
        : _experienceLevels.first;
    _skills = List<String>.from(provider.skills);
    _isProfilePublic = provider.isProfilePublic;
  }

  @override
  void dispose() {
    _bioController.dispose();
    _githubController.dispose();
    _linkedinController.dispose();
    _portfolioController.dispose();
    _skillInputController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Profile completion (local UI-only calculation)
  // ---------------------------------------------------------------------------

  double _profileCompletion(UserProvider provider) {
    final hasPhoto = provider.profileImageFile != null ||
        (provider.photoUrl?.isNotEmpty ?? false);
    final checks = <bool>[
      hasPhoto,
      _bioController.text.trim().isNotEmpty,
      _selectedCountry != null && _selectedCountry!.isNotEmpty,
      _skills.isNotEmpty,
      _githubController.text.trim().isNotEmpty ||
          _linkedinController.text.trim().isNotEmpty ||
          _portfolioController.text.trim().isNotEmpty,
    ];
    final completed = checks.where((c) => c).length;
    return completed / checks.length;
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<void> _handleEditPhoto() async {
    setState(() => _isUploadingImage = true);
    try {
      // Your provider already handles picking, uploading to Storage,
      // and persisting photoUrl to Firestore in one call.
      await context.read<UserProvider>().pickAndUploadImage(ImageSource.gallery);
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  /// Toggles a predefined or previously-added skill on/off.
  void _toggleSkill(String skill) {
    setState(() {
      if (_skills.contains(skill)) {
        _skills.remove(skill);
      } else {
        _skills.add(skill);
      }
    });
  }

  /// Shows/hides the free-text field used to type a custom ("Other") skill.
  void _toggleOtherSkillInput() {
    setState(() => _showOtherSkillInput = !_showOtherSkillInput);
  }

  /// Adds a custom skill typed into the "Other" field, then hides it again.
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

  void _openCountryPicker() {
    showCountryPicker(
      context: context,
      showPhoneCode: false,
      countryListTheme: CountryListThemeData(
        backgroundColor: _Palette.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        bottomSheetHeight: MediaQuery.of(context).size.height * 0.75,
        searchTextStyle: const TextStyle(color: _Palette.textPrimary),
        inputDecoration: InputDecoration(
          hintText: 'Search country',
          prefixIcon: const Icon(Icons.search_rounded),
          filled: true,
          fillColor: _Palette.background,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      onSelect: (Country country) {
        setState(() => _selectedCountry = country.name);
      },
    );
  }

  Future<void> _handlePrivacyChanged(bool value) async {
    setState(() => _isProfilePublic = value);
    await context.read<UserProvider>().updateProfileVisibility(value);
  }

  String? _validateUrl(String? value) {
    if (value == null || value.trim().isEmpty) return null; // optional fields
    final uri = Uri.tryParse(value.trim());
    final isValid =
        uri != null && uri.hasAbsolutePath && uri.scheme.startsWith('http');
    return isValid ? null : 'Enter a valid URL (starting with https://)';
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() => _isSaving = true);

    try {
      await context.read<UserProvider>().updateProfile(
            country: _selectedCountry,
            bio: _bioController.text.trim(),
            experienceLevel: _selectedExperienceLevel,
            skills: _skills,
            githubUrl: _githubController.text.trim(),
            linkedinUrl: _linkedinController.text.trim(),
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

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<UserProvider>();
    final isVerified = FirebaseAuth.instance.currentUser?.emailVerified ?? false;

    return Scaffold(
      backgroundColor: _Palette.background,
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: _Palette.background,
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
                email: provider.email,
                isVerified: isVerified,
                isUploading: _isUploadingImage,
                onEditPhoto: _handleEditPhoto,
              ),
              const SizedBox(height: 20),
              ProfileCompletionCard(completion: _profileCompletion(provider)),
              const SizedBox(height: 20),
              AboutSectionCard(
                controller: _bioController,
                maxLength: _bioMaxLength,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 20),
              PersonalInfoCard(
                country: _selectedCountry,
                experienceLevel: _selectedExperienceLevel,
                onTapCountry: _openCountryPicker,
                onExperienceChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedExperienceLevel = value);
                  }
                },
                experienceLevels: _experienceLevels,
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
              const SizedBox(height: 20),
              PrivacyCard(
                isPublic: _isProfilePublic,
                onChanged: _handlePrivacyChanged,
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
        color: _Palette.card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
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
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _Palette.textPrimary,
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
// 1. PROFILE HEADER
// =============================================================================

class ProfileHeaderSection extends StatelessWidget {
  const ProfileHeaderSection({
    super.key,
    required this.photoFile,
    required this.photoUrl,
    required this.name,
    required this.email,
    required this.isVerified,
    required this.isUploading,
    required this.onEditPhoto,
  });

  final File? photoFile;
  final String? photoUrl;
  final String name;
  final String email;
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
                    border: Border.all(color: _Palette.background, width: 2),
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
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: _Palette.textPrimary,
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
        const SizedBox(height: 4),
        Text(email, style: const TextStyle(fontSize: 13, color: _Palette.textSecondary)),
      ],
    );
  }
}

// =============================================================================
// 2. PROFILE COMPLETION
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
// 3. ABOUT / BIO
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
        style: const TextStyle(fontSize: 14, color: _Palette.textPrimary),
        decoration: InputDecoration(
          hintText: 'Tell clients about your experience and expertise…',
          hintStyle: TextStyle(color: _Palette.textSecondary.withOpacity(0.7)),
          filled: true,
          fillColor: _Palette.background,
          counterStyle: const TextStyle(color: _Palette.textSecondary, fontSize: 12),
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
// 4. PERSONAL INFORMATION
// =============================================================================

class PersonalInfoCard extends StatelessWidget {
  const PersonalInfoCard({
    super.key,
    required this.country,
    required this.experienceLevel,
    required this.onTapCountry,
    required this.onExperienceChanged,
    required this.experienceLevels,
  });

  final String? country;
  final String experienceLevel;
  final VoidCallback onTapCountry;
  final ValueChanged<String?> onExperienceChanged;
  final List<String> experienceLevels;

  /// Looks up the flag emoji for the currently saved country name, if any.
  String? get _countryFlag {
    if (country == null || country!.isEmpty) return null;
    try {
      return CountryService().getAll().firstWhere((c) => c.name == country).flagEmoji;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final flag = _countryFlag;
    final countryLabel = country == null
        ? 'Select country'
        : (flag != null ? '$flag  $country' : country!);

    return SectionCard(
      title: 'Personal Information',
      child: Column(
        children: [
          _PickerField(
            label: 'Country',
            value: countryLabel,
            icon: Icons.public_rounded,
            onTap: onTapCountry,
          ),
          const SizedBox(height: 14),
          _DropdownField(
            label: 'Experience Level',
            value: experienceLevel,
            items: experienceLevels,
            onChanged: onExperienceChanged,
          ),
        ],
      ),
    );
  }
}

class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _FieldLabelWrapper(
      label: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: _Palette.background,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: _Palette.textSecondary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(value,
                    style: const TextStyle(fontSize: 14, color: _Palette.textPrimary)),
              ),
              const Icon(Icons.chevron_right_rounded, color: _Palette.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _DropdownField extends StatelessWidget {
  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return _FieldLabelWrapper(
      label: label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: _Palette.background,
          borderRadius: BorderRadius.circular(12),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: _Palette.textSecondary),
            style: const TextStyle(fontSize: 14, color: _Palette.textPrimary),
            items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }
}

class _FieldLabelWrapper extends StatelessWidget {
  const _FieldLabelWrapper({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12.5, fontWeight: FontWeight.w600, color: _Palette.textSecondary)),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

// =============================================================================
// 5. PROFESSIONAL LINKS
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
      title: 'Professional Links',
      child: Column(
        children: [
          _UrlFormField(
            label: 'GitHub',
            icon: Icons.code_rounded,
            controller: githubController,
            hint: 'https://github.com/username',
            validator: validator,
            onChanged: onChanged,
          ),
          const SizedBox(height: 14),
          _UrlFormField(
            label: 'LinkedIn',
            icon: Icons.business_center_rounded,
            controller: linkedinController,
            hint: 'https://linkedin.com/in/username',
            validator: validator,
            onChanged: onChanged,
          ),
          const SizedBox(height: 14),
          // NOTE: portfolioUrl is not yet a field on UserModel/UserProvider.
          // This input works in the UI but won't persist until you add
          // `portfolioUrl` end-to-end (model, Firestore doc, updateProfile()).
          _UrlFormField(
            label: 'Portfolio Website (optional)',
            icon: Icons.language_rounded,
            controller: portfolioController,
            hint: 'https://yourportfolio.com',
            validator: validator,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _UrlFormField extends StatelessWidget {
  const _UrlFormField({
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
    return _FieldLabelWrapper(
      label: label,
      child: TextFormField(
        controller: controller,
        keyboardType: TextInputType.url,
        validator: validator,
        onChanged: (_) => onChanged(),
        style: const TextStyle(fontSize: 14, color: _Palette.textPrimary),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, size: 18, color: _Palette.textSecondary),
          hintText: hint,
          hintStyle: TextStyle(fontSize: 13, color: _Palette.textSecondary.withOpacity(0.7)),
          filled: true,
          fillColor: _Palette.background,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _Palette.error),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}

// =============================================================================
// 6. SKILLS
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

  /// The curated list of tappable skill options.
  final List<String> predefinedSkills;

  /// Skills currently selected — may include custom ones typed via "Other"
  /// that aren't part of [predefinedSkills].
  final List<String> selectedSkills;

  /// Whether the free-text "Other" input is currently visible.
  final bool showOtherInput;

  final TextEditingController inputController;
  final ValueChanged<String> onToggleSkill;
  final VoidCallback onToggleOtherInput;
  final ValueChanged<String> onAddCustomSkill;

  @override
  Widget build(BuildContext context) {
    // Keep any previously-added custom skill visible (and selected) even
    // though it isn't part of the curated list, so nothing gets lost.
    final displaySkills = <String>[
      ...predefinedSkills,
      ...selectedSkills.where((s) => !predefinedSkills.contains(s)),
    ];

    return SectionCard(
      title: 'Skills',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Choose all that apply',
              style: TextStyle(fontSize: 13, color: _Palette.textSecondary)),
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
                    TextStyle(fontSize: 13, color: _Palette.textSecondary.withOpacity(0.7)),
                filled: true,
                fillColor: _Palette.background,
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

/// A single selectable skill pill — filled + checkmark when selected,
/// outlined when not. The "Other" chip reuses this with a plus icon instead.
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
          color: isSelected ? _Palette.primary.withOpacity(0.08) : _Palette.card,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? _Palette.primary : const Color(0xFFE2E8F0),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null)
              Icon(icon,
                  size: 15, color: isSelected ? _Palette.primary : _Palette.textSecondary)
            else if (isSelected)
              const Icon(Icons.check_circle_rounded, size: 15, color: _Palette.primary),
            if (icon != null || isSelected) const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? _Palette.primary : _Palette.textPrimary,
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
// 7. PRIVACY
// =============================================================================

class PrivacyCard extends StatelessWidget {
  const PrivacyCard({super.key, required this.isPublic, required this.onChanged});

  final bool isPublic;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Row(
        children: [
          Icon(isPublic ? Icons.public_rounded : Icons.lock_outline_rounded,
              color: _Palette.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Public Profile',
                    style: TextStyle(
                        fontSize: 14.5, fontWeight: FontWeight.w600, color: _Palette.textPrimary)),
                const SizedBox(height: 2),
                Text(
                  isPublic
                      ? 'Visible to clients browsing the marketplace'
                      : 'Hidden from marketplace search',
                  style: const TextStyle(fontSize: 12.5, color: _Palette.textSecondary),
                ),
              ],
            ),
          ),
          Switch.adaptive(value: isPublic, activeColor: _Palette.primary, onChanged: onChanged),
        ],
      ),
    );
  }
}

// =============================================================================
// 8. SAVE BUTTON
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