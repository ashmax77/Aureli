import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import 'services/auth_service.dart';
import 'services/api_service.dart';
import 'providers/auth_provider.dart';
import 'providers/transaction_provider.dart';
import 'providers/budget_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/scheduled_transaction_provider.dart';
import 'providers/security_provider.dart';

import 'views/auth/auth_view.dart';
import 'views/auth/biometric_lock_view.dart';
import 'views/onboarding/onboarding_view.dart';
import 'views/home_navigation_scaffold.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint("Firebase initialization failed: $e");
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 1. Instantiate Core Services
    final authService = AuthService();
    final apiService = ApiService(authService);

    return MultiProvider(
      providers: [
        // 2. Instantiate State Providers
        ChangeNotifierProvider(create: (_) => SecurityProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider(authService, apiService)),
        ChangeNotifierProvider(create: (_) => TransactionProvider(apiService)),
        ChangeNotifierProvider(create: (_) => BudgetProvider(apiService)),
        ChangeNotifierProvider(create: (_) => NotificationProvider(apiService)),
        ChangeNotifierProvider(create: (_) => ScheduledTransactionProvider(apiService)),
      ],
      child: MaterialApp(
        title: 'Aureli',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          textTheme: GoogleFonts.manropeTextTheme(
            ThemeData.dark().textTheme,
          ),
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF0B3B5A), // Navy seed
            brightness: Brightness.dark,
          ),
        ),
        home: const AuthStateWrapper(),
      ),
    );
  }
}

class AuthStateWrapper extends StatefulWidget {
  const AuthStateWrapper({super.key});

  @override
  State<AuthStateWrapper> createState() => _AuthStateWrapperState();
}

class _AuthStateWrapperState extends State<AuthStateWrapper> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      final secProvider = Provider.of<SecurityProvider>(context, listen: false);
      secProvider.lockApp();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final secProvider = Provider.of<SecurityProvider>(context);

    // Show loading screen while Firebase/Backend sync profiles
    if (authProvider.isLoading && authProvider.userModel == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F1621),
        body: Center(
          child: CircularProgressIndicator(
            color: Color(0xFF147D64), // Emerald
          ),
        ),
      );
    }

    // 1. Session check: If not logged in -> AuthView
    if (!authProvider.isAuthenticated) {
      return const AuthView();
    }

    // 2. Security check: If biometrics enabled and app is locked -> BiometricLockView
    if (secProvider.isBiometricsEnabled && !secProvider.isAppUnlocked) {
      return const BiometricLockView();
    }

    // 3. Onboarding check: If user hasn't set initial limits -> OnboardingView
    if (authProvider.needsOnboarding) {
      return const OnboardingView();
    }

    // 4. Authenticated & Onboarded & Unlocked -> Home Navigation Scaffold
    return const HomeNavigationScaffold();
  }
}
