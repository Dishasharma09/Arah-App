import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../app/theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../provider/user_provider.dart';
import '../../provider/home_provider.dart';
import '../../provider/order_provider.dart';
import '../home/home_screen.dart';
import '../home/seller_home_screen.dart';
import '../onboarding/profile_setup_screen.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  Future<void> _resendVerificationEmail() async {
  try {
    final user = _authService.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign in again.'),
        ),
      );
      return;
    }

    await user.sendEmailVerification();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Verification email sent successfully.'),
      ),
    );
  } catch (_) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Failed to send verification email.'),
      ),
    );
  }
}
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _isLoading = false;
  String? _errorMessage;

  final _authService = FirebaseAuthService();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
final cred = await _authService.signIn(
  _emailCtrl.text.trim(),
  _passCtrl.text,
);      await cred.user?.reload();

if (!(cred.user?.emailVerified ?? false)) {
  if (!mounted) return;

  setState(() {
    _errorMessage =
        'Please verify your email before signing in. Check your inbox.';
    _isLoading = false;
  });

  return;
}
      if (!mounted) return;

      final userProvider = context.read<UserProvider>();
      await userProvider.loadUser(cred.user!.uid);

      if (!mounted) return;

      // Single source of truth: whatever loadUser() just populated (or
      // didn't). Previously this screen ran its OWN separate Firestore
      // read (_firestoreService.getUserProfile) to decide "new vs
      // existing user" instead of trusting userProvider.user — that read
      // could disagree with loadUser()'s result, and worse, when it *did*
      // decide "new user", it navigated straight to ProfileSetupScreen
      // without ever creating a base profile document. That left
      // userProvider.user == null, and ProfileSetupScreen's Complete Setup
      // button calls completeRegistration(), which immediately throws
      // ("User is null") and never writes anything to Firestore — so the
      // user saw a failure/snackbar instead of a saved profile, and any
      // retry kept landing back on the same broken state.
      if (userProvider.user == null) {
        // Genuinely no profile document for this account yet. Create the
        // base profile first — exactly like SignupScreen does — so
        // completeRegistration() has a non-null user to update later.
        final prefs = await SharedPreferences.getInstance();
        final selectedRole = prefs.getString('selected_role') ?? 'Buyer';
        if (!mounted) return;

        await userProvider.setupProfile(
          uid: cred.user!.uid,
          name: cred.user?.displayName ?? '',
          email: cred.user?.email ?? _emailCtrl.text.trim(),
          role: selectedRole,
          experienceLevel: 'Beginner',
          skills: const [],
          country: '',
        );

        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => ProfileSetupScreen(role: selectedRole),
          ),
          (route) => false,
        );
        return;
      }

      // Existing user: apply selected_role if coming from onboarding
      final prefs = await SharedPreferences.getInstance();
      final selectedRole = prefs.getString('selected_role');
      if (selectedRole != null) {
        final modeToSet = selectedRole == 'Seller' ? 'Seller' : 'Buyer';
        await userProvider.switchMode(modeToSet);
        await prefs.remove('selected_role');
      }

      if (!mounted) return;

      // Subscribe providers
      final homeProvider = context.read<HomeProvider>();
      homeProvider.subscribeToOpenTasks(excludeUserId: cred.user!.uid);

      final orderProvider = context.read<OrderProvider>();
      final mode = userProvider.currentMode;
      orderProvider.subscribeToOrders(cred.user!.uid, isSeller: mode == 'Seller');

      final currentMode = userProvider.currentMode;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => currentMode == 'Seller'
              ? const SellerHomeScreen()
              : const BuyerHomeScreen(),
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
    if (error.contains('user-not-found')) return 'No account found with this email.';
    if (error.contains('wrong-password') || error.contains('invalid-credential')) {
      return 'Incorrect email or password.';
    }
    if (error.contains('invalid-email')) return 'Please enter a valid email.';
    if (error.contains('too-many-requests')) return 'Too many attempts. Try again later.';
    return 'Sign in failed. Please try again.';
  }



Future<void> _showForgotPasswordDialog() async {
 
  final emailController = TextEditingController();

  await showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Reset Password'),
      content: TextField(
        controller: emailController,
        decoration: const InputDecoration(
          hintText: 'Enter your email',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
         try {
  await _authService.sendPasswordResetEmail(
    emailController.text.trim(),
  );

  if (!mounted) return;

  Navigator.pop(context);

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Password reset email sent successfully.'),
    ),
  );
} catch (_) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Failed to send reset email.'),
    ),
  );
}
          },
          child: const Text('Send'),
        ),
      ],
    ),
  );
}


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppTheme.colorsOf(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),
              Center(
                child: Container(
                  width: 100,
                  height: 100,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.card,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: colors.shadow,
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'assets/images/Arah.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Welcome back',
                style: theme.textTheme.headlineLarge?.copyWith(fontSize: 28),
              ),
              const SizedBox(height: 8),
              Text(
                'Sign in to continue on Arah',
                style: TextStyle(fontSize: 15, color: colors.secondaryText),
              ),
              const SizedBox(height: 36),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildTextField(
                      controller: _emailCtrl,
                      hint: 'Email address',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Enter your email';
                        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w]{2,4}').hasMatch(v)) {
                          return 'Enter a valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _passCtrl,
                      hint: 'Password',
                      icon: Icons.lock_outline,
                      obscure: _obscure,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          color: colors.secondaryText,
                        ),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Enter your password';
                        if (v.length < 6) return 'Password must be at least 6 characters';
                        return null;
                      },
                    ),
                 const SizedBox(height: 8),

Align(
  alignment: Alignment.centerRight,
  child: TextButton(
    onPressed: _showForgotPasswordDialog,
    child: const Text(
      'Forgot Password?',
      style: TextStyle(
        color: AppTheme.arahPurple,
        fontWeight: FontWeight.w600,
      ),
    ),
  ),
),
if (_errorMessage != null) ...[
  const SizedBox(height: 12),

  Container(
    padding: const EdgeInsets.symmetric(
      horizontal: 14,
      vertical: 10,
    ),
    decoration: BoxDecoration(
      color: colors.errorBackground,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      children: [
        Icon(
          Icons.error_outline,
          color: colors.error,
          size: 18,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            _errorMessage!,
            style: TextStyle(
              color: colors.error,
              fontSize: 13,
            ),
          ),
        ),
      ],
    ),
  ),

  if (_errorMessage!.contains('verify your email'))
    Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: _resendVerificationEmail,
        child: const Text(
          'Resend verification email',
          style: TextStyle(
            color: AppTheme.arahPurple,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ),
],
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _signIn,
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppTheme.radiusButton),
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
                                'Sign In',
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
                    "Don't have an account? ",
                    style: TextStyle(color: colors.secondaryText, fontSize: 14),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SignupScreen()),
                    ),
                    child: const Text(
                      'Sign Up',
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
final theme = Theme.of(context);
final colors = AppTheme.colorsOf(context);

return TextFormField(
  controller: controller,
  obscureText: obscure,
  keyboardType: keyboardType,
  validator: validator,
  style: TextStyle(
    fontSize: 15,
    color: colors.mainText,
  ),
  decoration: InputDecoration(
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
        fillColor: colors.searchBackground,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusSearch),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusSearch),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusSearch),
          borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusSearch),
          borderSide: BorderSide(color: colors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusSearch),
          borderSide: BorderSide(color: colors.error, width: 1.5),
        ),
      ),
    );
  }
}