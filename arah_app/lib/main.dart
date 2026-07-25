import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import 'app/theme/app_theme.dart';
import 'provider/user_provider.dart';
import 'provider/home_provider.dart';
import 'provider/order_provider.dart';
import 'provider/request_provider.dart';
import 'screens/onboarding/role_selection_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/home/seller_home_screen.dart';
import 'screens/onboarding/profile_setup_screen.dart';
import 'firebase_options.dart';

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

  // Pass all uncaught errors from the framework to Crashlytics.
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

  // Optional: Also catch asynchronous errors not caught by the Flutter framework.
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  // Initialize Analytics
  final analytics = FirebaseAnalytics.instance;
  await analytics.setAnalyticsCollectionEnabled(true);
  await analytics.logAppOpen();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => HomeProvider()),
        ChangeNotifierProvider(create: (_) => OrderProvider()),
        ChangeNotifierProvider(create: (_) => RequestProvider()),
      ],
      child: const ArahApp(),
    ),
  );
}

class ArahApp extends StatelessWidget {
  const ArahApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Arah',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      builder: (context, child) {
        return ScrollConfiguration(
          behavior: const NoScrollbarBehavior(),
          child: child!,
        );
      },
      home: const AuthGate(),
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

        // Not logged in → show role selection / onboarding
        if (user == null) {
          return const RoleSelectionScreen();
        }

        // Logged in — load user then route
        return _UserLoader(uid: user.uid);
      },
    );
  }
}

/// Loads user data from Firestore after confirmed auth, then shows correct home
class _UserLoader extends StatefulWidget {
  final String uid;
  const _UserLoader({required this.uid});

  @override
  State<_UserLoader> createState() => _UserLoaderState();
}

class _UserLoaderState extends State<_UserLoader> {
  bool _loaded = false;
  bool _needsProfileSetup = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUser();
    });
  }

  Future<void> _loadUser() async {
    final userProvider = context.read<UserProvider>();
    await userProvider.loadUser(widget.uid);

    // If user profile doesn't exist in Firestore, send to profile setup
    if (userProvider.user == null) {
      if (mounted) setState(() {
        _loaded = true;
        _needsProfileSetup = true;
      });
      return;
    }

    final uid = widget.uid;

    // Subscribe HomeProvider with user's UID to exclude own tasks
    final homeProvider = context.read<HomeProvider>();
    homeProvider.subscribeToOpenTasks(excludeUserId: uid);

    // Subscribe OrderProvider based on current mode
    final orderProvider = context.read<OrderProvider>();
    final mode = userProvider.currentMode;
    orderProvider.subscribeToOrders(uid, isSeller: mode == 'Seller');

    if (mounted) setState(() => _loaded = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const _LoadingScreen();
    }

    if (_needsProfileSetup) {
      return const ProfileSetupScreen();
    }

    final mode = context.read<UserProvider>().currentMode;
    return mode == 'Seller' ? const SellerHomeScreen() : const BuyerHomeScreen();
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
}
