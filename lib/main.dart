import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app/theme/app_theme.dart';
import 'provider/user_provider.dart';
import 'provider/home_provider.dart';
import 'dart:async';
import 'provider/theme_provider.dart';
import 'package:flutter/services.dart';
import 'provider/order_provider.dart';
import 'provider/notification_provider.dart';
import 'provider/request_provider.dart';
import 'provider/match_provider.dart';
import 'screens/home/home_screen.dart';
import 'screens/home/seller_home_screen.dart';
import 'screens/onboarding/profile_setup_screen.dart';
import 'screens/onboarding/role_selection_screen.dart';
import 'firebase_options.dart';
import 'package:arah_app/screens/auth/login_screen.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    if (e.toString().contains('duplicate-app')) {
      debugPrint('Firebase already initialized: $e');
    } else {
      rethrow;
    }
    
  }

  runApp(
MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => ThemeProvider()),
    ChangeNotifierProvider(create: (_) => UserProvider()),
    ChangeNotifierProvider(create: (_) => HomeProvider()),
    ChangeNotifierProvider(create: (_) => OrderProvider()),
    ChangeNotifierProvider(create: (_) => RequestProvider()),
    ChangeNotifierProvider(create: (_) => NotificationProvider()),
    ChangeNotifierProvider(create: (_) => MatchProvider()),
  ],
  child: const ArahApp(),
),
  );
}

class ArahApp extends StatelessWidget {
  const ArahApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return MaterialApp(
      title: 'Arah',
      
      debugShowCheckedModeBanner: false,

      theme: AppTheme.lightTheme,

      darkTheme: AppTheme.darkTheme,

      themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,

builder: (context, child) {
  final isDark = Theme.of(context).brightness == Brightness.dark;

  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness:
          isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness:
          isDark ? Brightness.dark : Brightness.light,

      systemNavigationBarColor:
          Theme.of(context).scaffoldBackgroundColor,
      systemNavigationBarIconBrightness:
          isDark ? Brightness.light : Brightness.dark,
    ),
  );

  return ScrollConfiguration(
    behavior: const NoScrollbarBehavior(),
    child: child!,
  );
},

home: const AuthGate(
),
    );
  }
}


/// Listens to Firebase auth state and routes to login or home
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingScreen();
        }

        final user = snapshot.data;

        // Not logged in → first-ever launch sees Role Selection (which
        // then hands off to Login/Signup); a returning user who has
        // already been through onboarding once (e.g. just signed out)
        // goes straight to Login instead of being asked to pick a role
        // again.
        //
        // NOTE: previously this always returned LoginScreen directly —
        // RoleSelectionScreen existed fully wired (it saves
        // `selected_role` and pushes to LoginScreen) but nothing in the
        // app ever navigated to it, so it was unreachable dead code.
        if (user == null) {
          return const _LoggedOutGate();
        }

        // Logged in — load user then route
        return _UserLoader(uid: user.uid);
      },
    );
  }
}

/// Decides Role Selection vs Login for a logged-out user, based on
/// whether onboarding has been shown before on this device.
class _LoggedOutGate extends StatefulWidget {
  const _LoggedOutGate();

  @override
  State<_LoggedOutGate> createState() => _LoggedOutGateState();
}

class _LoggedOutGateState extends State<_LoggedOutGate> {
  static const _onboardingSeenKey = 'has_seen_onboarding';
  bool? _hasSeenOnboarding;

  @override
  void initState() {
    super.initState();
    _checkOnboardingSeen();
  }

  Future<void> _checkOnboardingSeen() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _hasSeenOnboarding = prefs.getBool(_onboardingSeenKey) ?? false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasSeenOnboarding == null) return const _LoadingScreen();
    return _hasSeenOnboarding!
        ? const LoginScreen()
        : const RoleSelectionScreen();
  }
}

/// Loads user data from Firestore after confirmed auth, then shows correct home
class _UserLoader extends StatefulWidget {
  final String uid;
  const _UserLoader({required this.uid});

  @override
  State<_UserLoader> createState() => _UserLoaderState();
}

/// What state the loader ended up in, so build() never has to guess.
enum _LoadResult { loading, ready, needsProfileSetup, error }

class _UserLoaderState extends State<_UserLoader> {
  _LoadResult _result = _LoadResult.loading;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUser();
    });
  }

  Future<void> _loadUser() async {
    if (mounted) setState(() => _result = _LoadResult.loading);
    final userProvider = context.read<UserProvider>();

    // ROOT CAUSE OF THE REPORTED BUG:
    // The previous implementation treated "loadUser threw" and "loadUser
    // succeeded but found no profile document" as the SAME outcome
    // (userProvider.user == null), and routed both straight to
    // ProfileSetupScreen. Any transient failure while fetching an
    // EXISTING user's profile — a Firestore permission hiccup, no network
    // on cold start, etc. — silently swallowed the error and dropped a
    // fully-registered user onto the Profile Setup screen, which looked
    // like "the app always opens into Set Profile".
    //
    // Fix: only treat "no profile" as "needs setup" when the fetch itself
    // actually succeeded. If the fetch throws, show a retry screen instead
    // of guessing — never silently reroute an existing user into Setup.
    try {
      await userProvider.loadUser(widget.uid);
    } catch (e) {
      debugPrint('_UserLoader: loadUser failed: $e');
      if (mounted) setState(() => _result = _LoadResult.error);
      return;
    }

    if (userProvider.user == null) {
      // The fetch succeeded AND there is genuinely no profile document —
      // this really is a brand-new account that needs Profile Setup.
      //
      // IMPORTANT: ProfileSetupScreen's "Complete Setup" button calls
      // UserProvider.completeRegistration(), which requires
      // userProvider.user to already be non-null (it only ever UPDATES
      // an existing document — see UserProvider). Simply switching to
      // needsProfileSetup here without creating that base document first
      // left `_user` null, so completeRegistration() immediately threw
      // "User is null" and nothing was ever saved, even though the form
      // looked like it submitted fine. Create the base profile now,
      // exactly like SignupScreen does, so it's ready for
      // completeRegistration() to fill in later.
      final authUser = FirebaseAuth.instance.currentUser;
      try {
        await userProvider.setupProfile(
          uid: widget.uid,
          name: authUser?.displayName ?? '',
          email: authUser?.email ?? '',
          role: 'Buyer',
          experienceLevel: 'Beginner',
          skills: const [],
          country: '',
        );
      } catch (e) {
        debugPrint('_UserLoader: setupProfile failed: $e');
        if (mounted) setState(() => _result = _LoadResult.error);
        return;
      }
      if (mounted) setState(() => _result = _LoadResult.needsProfileSetup);
      return;
    }

    final uid = widget.uid;
    context
    .read<NotificationProvider>()
    .listenNotifications(uid);
    final homeProvider = context.read<HomeProvider>();
    homeProvider.subscribeToOpenTasks(excludeUserId: uid);

    final orderProvider = context.read<OrderProvider>();
    final mode = userProvider.currentMode;
    orderProvider.subscribeToOrders(uid, isSeller: mode == 'Seller');

    if (mounted) setState(() => _result = _LoadResult.ready);
  }


  @override
  Widget build(BuildContext context) {
    switch (_result) {
      case _LoadResult.loading:
        return const _LoadingScreen();
      case _LoadResult.error:
        return _LoadErrorScreen(onRetry: _loadUser);
      case _LoadResult.needsProfileSetup:
        return const ProfileSetupScreen();
      case _LoadResult.ready:
        final mode = context.read<UserProvider>().currentMode;
        return mode == 'Seller'
            ? const SellerHomeScreen()
            : const BuyerHomeScreen();
    }
  }
}

/// Shown only when we genuinely could not confirm whether an already
/// logged-in user has a profile. Never auto-routes to Profile Setup —
/// that would risk wiping an existing user's data on save.
class _LoadErrorScreen extends StatelessWidget {
  final Future<void> Function() onRetry;
  const _LoadErrorScreen({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.pureWhite,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                size: 48,
                color: AppTheme.navyBlue,
              ),
              const SizedBox(height: 16),
              const Text(
                "Couldn't load your profile",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.navyBlue,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Check your connection and try again.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.blueGrey.shade400, fontSize: 13),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => onRetry(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppTheme.pureWhite,
      body: Center(
        child: CircularProgressIndicator(color: AppTheme.arahPurple),
      ),
    );
  }
}

// Custom behavior to hide scrollbars
class NoScrollbarBehavior extends ScrollBehavior {
  const NoScrollbarBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}