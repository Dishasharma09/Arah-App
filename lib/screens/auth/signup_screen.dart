import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:country_picker/country_picker.dart';
import '../../app/theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../provider/user_provider.dart';
import '../onboarding/profile_setup_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  // Shared palette for this screen's inputs/errors — pulled out of the
  // widget tree so they're declared once instead of repeated per field.
  Color get _fieldFill => AppTheme.colorsOf(context).searchBackground;
  Color get _errorRed => AppTheme.colorsOf(context).error;
  Color get _errorBg => AppTheme.colorsOf(context).errorBackground;
  Color get _errorTextColor => AppTheme.colorsOf(context).error;

  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  final _authService = FirebaseAuthService();

  bool _obscure = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  String? _errorMessage;

  Country? _selectedCountry;
  bool _isEmailValid = false;
  PasswordStrength _passwordStrength = const PasswordStrength();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final cred = await _authService.signUp(
        _emailCtrl.text.trim(),
        _passCtrl.text.trim(),
      );


      final prefs = await SharedPreferences.getInstance();
      final selectedRole = prefs.getString('selected_role') ?? 'Buyer';
      final countryName = _selectedCountry?.name ?? '';

      await prefs.setString('signup_name', _nameCtrl.text.trim());
      await prefs.setString('signup_email', _emailCtrl.text.trim());
      await prefs.setString('signup_uid', cred.user!.uid);
      await prefs.setString('signup_country', countryName);

      await context.read<UserProvider>().setupProfile(
        uid: cred.user!.uid,
        name: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        role: selectedRole,
        experienceLevel: 'Beginner',
        skills: [],
        country: countryName,
      );

      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Verify your email'),
          content: const Text(
            'We sent a verification email to your inbox. Please verify your email before logging in.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => ProfileSetupScreen(role: selectedRole),
        ),
        (route) => false,
      );
    } on Exception catch (e) {
      setState(() {
        _errorMessage = _parseFirebaseError(e.toString());
        _isLoading = false;
      });
    }
  }

  String _parseFirebaseError(String error) {
    if (error.contains('email-already-in-use')) {
      return 'An account already exists with this email.';
    }
    if (error.contains('invalid-email')) {
      return 'Please enter a valid email address.';
    }
    if (error.contains('weak-password')) {
      return 'Password is too weak. Use at least 6 characters.';
    }
    return 'Sign up failed. Please try again.\n(Error: $error)';
  }

  void _openCountryPicker(FormFieldState<Country> fieldState) {
    showCountryPicker(
      context: context,
      showPhoneCode: false,
      countryListTheme: CountryListThemeData(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        bottomSheetHeight: MediaQuery.of(context).size.height * 0.75,
        inputDecoration: InputDecoration(
          hintText: 'Search country',
          prefixIcon: const Icon(Icons.search, size: 20),
          filled: true,
          fillColor: _fieldFill,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      onSelect: (country) {
        setState(() => _selectedCountry = country);
        fieldState.didChange(country);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              IconButton(
                icon: Icon(
                  Icons.arrow_back_ios_new,
                  size: 20,
                  color: Theme.of(context).textTheme.titleLarge?.color,
                ),
                onPressed: () => Navigator.pop(context),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(height: 24),
              Text(
                'Create Account',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.headlineLarge?.color,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Join Arah and start your journey',
                style: TextStyle(fontSize: 15, color: AppTheme.colorsOf(context).secondaryText),
              ),
              const SizedBox(height: 36),
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTextField(
                      controller: _nameCtrl,
                      hint: 'Full Name',
                      icon: Icons.person_outline,
                      validator: Validators.name,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _emailCtrl,
                      hint: 'Email address',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      onChanged: (val) {
                        setState(
                          () => _isEmailValid = Validators.isValidEmail(val),
                        );
                      },
                      validator: Validators.email,
                    ),
                    if (_emailCtrl.text.isNotEmpty)
                      _buildValidationRow('Valid email format', _isEmailValid),

                    const SizedBox(height: 16),
                    _buildCountryField(),

                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _passCtrl,
                      hint: 'Password',
                      icon: Icons.lock_outline,
                      obscure: _obscure,
                      onChanged: (val) {
                        setState(
                          () => _passwordStrength = PasswordStrength.evaluate(
                            val,
                          ),
                        );
                      },
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscure
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: AppTheme.colorsOf(context).secondaryText,
                        ),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Enter a password';
                        if (!_passwordStrength.isValid) {
                          return 'Please meet all password requirements';
                        }
                        return null;
                      },
                    ),
                    if (_passCtrl.text.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      ..._passwordStrength.requirements.map(
                        (r) => _buildValidationRow(r.key, r.value),
                      ),
                    ],

                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _confirmPassCtrl,
                      hint: 'Confirm Password',
                      icon: Icons.lock_outline,
                      obscure: _obscureConfirm,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirm
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: AppTheme.colorsOf(context).secondaryText,
                        ),
                        onPressed: () =>
                            setState(() => _obscureConfirm = !_obscureConfirm),
                      ),
                      validator: (v) =>
                          Validators.confirmPassword(v, _passCtrl.text),
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: _errorBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: _errorRed,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(
                                  color: _errorTextColor,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _signUp,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.arahPurple,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Text(
                                'Create Account',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Already have an account? ',
                    style: TextStyle(
                      color: AppTheme.colorsOf(context).secondaryText,
                      fontSize: 14,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Text(
                      'Sign In',
                      style: TextStyle(
                        color: AppTheme.arahPurple,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildValidationRow(String text, bool isValid) {
    return Padding(
      padding: const EdgeInsets.only(top: 6.0, left: 4.0),
      child: Row(
        children: [
          Icon(
            isValid ? Icons.check_circle : Icons.radio_button_unchecked,
            color: isValid ? AppTheme.successGreen : AppTheme.colorsOf(context).secondaryText,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: isValid ? AppTheme.successGreen : AppTheme.colorsOf(context).secondaryText,
              fontSize: 13,
              fontWeight: isValid ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  /// Shared decoration for every input on this screen (text fields and
  /// the country picker) so the five border states (default/enabled/
  /// focused/error/focused-error) are defined once instead of per field.
  InputDecoration _decoration({
    String? hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    OutlineInputBorder border(Color color, [double width = 1]) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusSearch),
        borderSide: BorderSide(color: color, width: width),
      );
    }

final colors = AppTheme.colorsOf(context);
final theme = Theme.of(context);

final defaultBorder = OutlineInputBorder(
  borderRadius: BorderRadius.circular(AppTheme.radiusSearch),
  borderSide: BorderSide.none,
);
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: colors.secondaryText,
        fontSize: 14,
      ),
      prefixIcon: Icon(
        icon,
        color: colors.secondaryText,
        size: 20,
      ),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: _fieldFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: defaultBorder,
      enabledBorder: defaultBorder,
      focusedBorder: border(theme.colorScheme.primary, 1.5),
      errorBorder: border(_errorRed),
      focusedErrorBorder: border(_errorRed, 1.5),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      validator: validator,
      onChanged: onChanged,
      style: TextStyle(
          fontSize: 15, color: Theme.of(context).textTheme.bodyLarge?.color),
      decoration: _decoration(hint: hint, icon: icon, suffixIcon: suffixIcon),
    );
  }

  /// Required field, so it's wrapped in its own FormField to keep it
  /// participating in `_formKey.currentState!.validate()` just like the
  /// old DropdownButtonFormField did.
  Widget _buildCountryField() {
    return FormField<Country>(
      initialValue: _selectedCountry,
      validator: (value) => value == null ? 'Please select your country' : null,
      builder: (fieldState) {
        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _openCountryPicker(fieldState),
          child: InputDecorator(
            decoration: _decoration(
              icon: Icons.public,
            ).copyWith(errorText: fieldState.errorText),
            child: Row(
              children: [
                if (_selectedCountry != null) ...[
                  Text(
                    _selectedCountry!.flagEmoji,
                    style: const TextStyle(fontSize: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _selectedCountry!.name,
                      style: TextStyle(
                        fontSize: 15,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ] else
                  Expanded(
                    child: Text(
                      'Select Country',
                      style: TextStyle(
                        color: AppTheme.colorsOf(context).secondaryText,
                        fontSize: 14,
                      ),
                    ),
                  ),
                Icon(
                  Icons.keyboard_arrow_down,
                  color: AppTheme.colorsOf(context).secondaryText,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Shared form-validation helpers, kept in this file so the screen is
/// fully self-contained. If a second screen ever needs these same
/// rules, move this class out to its own file at that point.
class Validators {
  Validators._();

  static final RegExp _emailPattern = RegExp(r'^[\w.-]+@([\w-]+\.)+[\w]{2,4}$');

  static bool isValidEmail(String value) =>
      _emailPattern.hasMatch(value.trim());

  static String? name(String? value) {
    if (value == null || value.trim().isEmpty) return 'Enter your name';
    if (value.trim().length < 2) return 'Name must be at least 2 characters';
    return null;
  }

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return 'Enter your email';
    if (!isValidEmail(value)) return 'Enter a valid email address';
    return null;
  }

  static String? confirmPassword(String? value, String original) {
    if (value == null || value.isEmpty) return 'Confirm your password';
    if (value != original) return 'Passwords do not match';
    return null;
  }
}

/// Evaluates live password requirements as one immutable object instead
/// of four separate booleans — easier to extend (e.g. add a "special
/// character" rule) and easier to render as a list in the UI.
class PasswordStrength {
  final bool hasMinLength;
  final bool hasUppercase;
  final bool hasLowercase;
  final bool hasNumber;

  const PasswordStrength({
    this.hasMinLength = false,
    this.hasUppercase = false,
    this.hasLowercase = false,
    this.hasNumber = false,
  });

  factory PasswordStrength.evaluate(String value) => PasswordStrength(
    hasMinLength: value.length >= 8,
    hasUppercase: value.contains(RegExp(r'[A-Z]')),
    hasLowercase: value.contains(RegExp(r'[a-z]')),
    hasNumber: value.contains(RegExp(r'[0-9]')),
  );

  bool get isValid => hasMinLength && hasUppercase && hasLowercase && hasNumber;

  /// Label + met-status pairs, ready to be mapped into UI rows.
  List<MapEntry<String, bool>> get requirements => [
    MapEntry('At least 8 characters', hasMinLength),
    MapEntry('Contains an uppercase letter', hasUppercase),
    MapEntry('Contains a lowercase letter', hasLowercase),
    MapEntry('Contains a number', hasNumber),
  ];
}
