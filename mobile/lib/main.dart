import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import 'services/auth_service.dart';
import 'services/api_service.dart';
import 'services/connectivity_service.dart';
import 'providers/theme_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/transaction_provider.dart';
import 'providers/budget_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/scheduled_transaction_provider.dart';
import 'providers/debt_provider.dart';
import 'providers/security_provider.dart';
import 'providers/lifetime_provider.dart';

import 'views/auth/auth_view.dart';
import 'views/auth/biometric_lock_view.dart';
import 'views/onboarding/onboarding_view.dart';
import 'views/home_navigation_scaffold.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (e) {
    if (kDebugMode) debugPrint("Firebase initialization failed: $e");
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
    apiService.wakeUpServer();

    return MultiProvider(
      providers: [
        // 2. Instantiate State Providers
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => SecurityProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider(authService, apiService)),
        ChangeNotifierProvider(
          create: (_) => TransactionProvider(
            apiService,
            // Replay the offline queue as soon as the network returns.
            // (onFinancialDataChanged is attached by HomeNavigationScaffold, where the budget
            // and debt providers are reachable.)
            connectivityChanges: ConnectivityService.onlineChanges(),
          ),
        ),
        ChangeNotifierProvider(create: (_) => BudgetProvider(apiService)),
        ChangeNotifierProvider(create: (_) => NotificationProvider(apiService)),
        ChangeNotifierProvider(create: (_) => ScheduledTransactionProvider(apiService)),
        ChangeNotifierProvider(create: (_) => DebtProvider(apiService)),
        ChangeNotifierProvider(create: (_) => LifetimeProvider(apiService)),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'Aureli',
            debugShowCheckedModeBanner: false,
            themeMode: themeProvider.themeMode,
            darkTheme: ThemeData(
              useMaterial3: true,
              brightness: Brightness.dark,
              scaffoldBackgroundColor: const Color(0xFF0F1621),
              textTheme: GoogleFonts.manropeTextTheme(
                ThemeData.dark().textTheme,
              ),
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF0B3B5A),
                brightness: Brightness.dark,
                surface: const Color(0xFF192233),
              ),
            ),
            theme: ThemeData(
              useMaterial3: true,
              brightness: Brightness.light,
              scaffoldBackgroundColor: const Color(0xFFF4F6F9),
              textTheme: GoogleFonts.manropeTextTheme(
                ThemeData.light().textTheme,
              ),
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF0B3B5A),
                brightness: Brightness.light,
                surface: Colors.white,
              ),
            ),
            home: const AuthStateWrapper(),
          );
        },
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
    // (Syncing the offline queue on resume is handled by OfflineAwareShell, which only
    // exists while signed in and unlocked.)
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final secProvider = Provider.of<SecurityProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Show loading screen while Firebase/Backend sync profiles
    if ((authProvider.status == AuthStatus.initializing ||
        authProvider.status == AuthStatus.syncingProfile) &&
      authProvider.userModel == null) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F1621) : const Color(0xFFF4F6F9),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                color: Color(0xFF147D64), // Emerald
              ),
              const SizedBox(height: 20),
              Text(
                "Connecting to Aureli...",
                style: TextStyle(
                  color: isDark ? Colors.white.withValues(alpha: 0.7) : const Color(0xFF475569),
                  fontFamily: 'Manrope',
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (authProvider.status == AuthStatus.profileSyncFailed) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F1621) : const Color(0xFFF4F6F9),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Your account could not be synchronized.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: isDark ? Colors.white : const Color(0xFF1E293B)),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => authProvider.fetchUserProfile(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // 1. Session check: If not logged in -> AuthView
    if (!authProvider.isAuthenticated) {
      return const AuthView();
    }

    // Wait for stored security preferences before deciding whether the app is locked,
    // otherwise protected screens would flash (or stay open) before the lock applies.
    if (!secProvider.isInitialized) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F1621) : const Color(0xFFF4F6F9),
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFF147D64)),
        ),
      );
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
