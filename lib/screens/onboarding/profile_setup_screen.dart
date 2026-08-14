import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app/theme/app_theme.dart';
import '../../provider/user_provider.dart';
import '../../provider/home_provider.dart';
import '../../provider/order_provider.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../home/home_screen.dart';
import '../home/seller_home_screen.dart';

/// Registration / Profile Setup screen.
///
/// Per the Sprint 2 agreement with Disha Sharma, this screen — and ONLY
/// this screen — collects:
///   • Username
///   • College Name
///   • Date of Birth  (one-time; never editable again — see UserProvider)
///   • Experience Level
///
/// Skills, bio, GitHub/LinkedIn/Portfolio links, etc. are NOT collected
/// here — those live in Edit Profile, reachable later from the Profile
/// screen. This keeps registration short and matches the agreed scope.
class ProfileSetupScreen extends StatefulWidget {
  final String role;
  const ProfileSetupScreen({super.key, this.role = 'Buyer'});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _collegeCtrl = TextEditingController();

  DateTime? _dateOfBirth;
  String _experienceLevel = 'Beginner';
  bool _isSaving = false;

File? _profileImage;
final ImagePicker _picker = ImagePicker();

List<String> _skills = [];

static const List<String> _availableSkills = [
  'Flutter', 'Web Development', 'UI/UX Design', 'Graphic Design',
    'Content Writing', 'Translation', 'Digital Marketing', 'Video Editing',
    'Data Entry', 'Mobile App Development', 'SEO', 'Photography',
];

Future<void> _pickImage() async {
  final picked = await _picker.pickImage(
    source: ImageSource.gallery,
    imageQuality: 75,
  );

  if (picked != null) {
    setState(() {
      _profileImage = File(picked.path);
    });
  }
  
}


  static const List<String> _experienceLevels = [
    'Beginner',
    'Intermediate',
    'Advanced',
  ];

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _collegeCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(now.year - 100),
      lastDate: now, // can't be born in the future
      helpText: 'Select your date of birth',
    );
    if (picked != null) {
      setState(() => _dateOfBirth = picked);
    }
  }
  int _calculateAge(DateTime birthDate) {
  final today = DateTime.now();

  int age = today.year - birthDate.year;

  if (today.month < birthDate.month ||
      (today.month == birthDate.month &&
          today.day < birthDate.day)) {
    age--;
  }

  return age;
}

  Future<void> _completeSetup() async {
    if (!_formKey.currentState!.validate()) return;
    if (_dateOfBirth == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your date of birth.')),
      );
      return;
    }
  final age = _calculateAge(_dateOfBirth!);

  final isSellingRole =
      widget.role.toLowerCase() == 'seller' ||
      widget.role.toLowerCase() == 'both';

  if (isSellingRole && age < 23) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'You must be 23 or older to sell on ARAH.',
        ),
      ),
    );
    return;
  }
    setState(() => _isSaving = true);
    
    try {
      final userProvider = context.read<UserProvider>();
      final uid = userProvider.uid;

      if (uid.isEmpty) {
        throw Exception('Not authenticated. Please sign in again.');
      }

      // The ONLY call site in the app allowed to set username, collegeName,
      // and dateOfBirth. dateOfBirth becomes permanent once this succeeds.
print("CURRENT USER OBJECT: ${userProvider.user}");
print("CURRENT UID: ${userProvider.uid}");

await userProvider.completeRegistration(
  username: _usernameCtrl.text.trim(),
  collegeName: _collegeCtrl.text.trim(),
  dateOfBirth: _dateOfBirth!,
  experienceLevel: _experienceLevel,
  skills: _skills,
  profileImage: _profileImage,
);

      if (!mounted) return;

      final homeProvider = context.read<HomeProvider>();
      homeProvider.subscribeToOpenTasks(excludeUserId: uid);

      final orderProvider = context.read<OrderProvider>();
      final mode = userProvider.currentMode;
      orderProvider.subscribeToOrders(uid, isSeller: mode == 'Seller');

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => mode == 'Seller'
              ? const SellerHomeScreen()
              : const BuyerHomeScreen(),
        ),
        (route) => false,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Setup failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _formatDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),
                Center(
                  child: Column(
                    children: [
                      Text(
                        "Set up your profile",
                        style: Theme.of(context).textTheme.headlineLarge
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 24,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "You're all set as a ${widget.role}!\nJust a few more details to get started.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 36),
                Center(
  child: GestureDetector(
    onTap: _pickImage,
    child: CircleAvatar(
      radius: 45,
      backgroundColor: Theme.of(context).cardColor,
      foregroundColor: Theme.of(context).textTheme.bodyLarge?.color,
      backgroundImage: _profileImage != null
          ? FileImage(_profileImage!)
          : null,
      child: _profileImage == null
          ? const Icon(Icons.camera_alt, size: 30)
          : null,
    ),
  ),
),

                _label('Username'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _usernameCtrl,
                  decoration: _fieldDecoration('e.g. jordan_dev'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Enter a username';
                    }
                    if (v.trim().length < 3) {
                      return 'Username must be at least 3 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                _label('College Name'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _collegeCtrl,
                  decoration: _fieldDecoration('e.g. XYZ University'),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Enter your college name'
                      : null,
                ),
                const SizedBox(height: 24),

                _label('Date of Birth'),
                Text(
                  'This cannot be changed later.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _pickDateOfBirth,
                  child: InputDecorator(
                    decoration: _fieldDecoration('Select date of birth'),
                    child: Row(
                      children: [
                        Icon(Icons.cake_outlined,
                            size: 18,
                            color: Theme.of(context).textTheme.bodyMedium?.color),
                        const SizedBox(width: 10),
                        Text(
                          _dateOfBirth != null
                              ? _formatDate(_dateOfBirth!)
                              : 'Select date of birth',
                          style: TextStyle(
                            fontSize: 14,
                            color: _dateOfBirth != null
                                ? Theme.of(context).textTheme.bodyLarge?.color
                                : Theme.of(context).textTheme.bodyMedium?.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                _label('Skills'),
const SizedBox(height: 12),

Wrap(
  spacing: 8,
  runSpacing: 8,
  children: _availableSkills.map((skill) {
    final isSelected = _skills.contains(skill);

    return ChoiceChip(
  label: Text(
    skill,
    style: TextStyle(
      color: isSelected
          ? Colors.white
          : Theme.of(context).textTheme.bodyLarge?.color,
      fontWeight: FontWeight.w500,
    ),
  ),
  selected: isSelected,

  selectedColor: AppTheme.arahPurple,

  backgroundColor: Theme.of(context).cardColor,

  side: BorderSide(
    color: isSelected
        ? AppTheme.arahPurple
        : AppTheme.colorsOf(context).border,
    width: 1,
  ),

  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(10),
  ),

  onSelected: (selected) {
    setState(() {
      if (selected) {
        _skills.add(skill);
      } else {
        _skills.remove(skill);
      }
    });
  },
);
  }).toList(),
),

const SizedBox(height: 24),

                _label('Experience Level'),
                const SizedBox(height: 12),
                Column(
                  children: _experienceLevels.map((level) {
                    final isSelected = _experienceLevel == level;
                    return GestureDetector(
                      onTap: () => setState(() => _experienceLevel = level),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 16),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.arahPurple.withOpacity(0.08)
                              : Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? AppTheme.arahPurple
                                : Theme.of(context).dividerColor,
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected
                                      ? AppTheme.arahPurple
                                      : Theme.of(context).dividerColor,
                                  width: isSelected ? 5.5 : 1.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              level,
                              style: TextStyle(
                                color: isSelected
                                    ? AppTheme.arahPurple
                                    : Theme.of(context).textTheme.bodyLarge?.color,
                                fontSize: 15,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _completeSetup,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.arahPurple,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Text(
                            "Complete Setup",
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).textTheme.bodyLarge?.color,
        ),
      );

  InputDecoration _fieldDecoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: Theme.of(context).inputDecorationTheme.hintStyle?.color,
          fontSize: 14,
        ),
        filled: true,
        fillColor: Theme.of(context).inputDecorationTheme.fillColor,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Theme.of(context).dividerColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Theme.of(context).dividerColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.arahPurple, width: 1.5),
        ),
      );
}
