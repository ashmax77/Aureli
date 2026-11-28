import 'package:aureli/theme/app_colors.dart';
import 'dart:ui';
import 'package:aureli/views/scheduled/scheduled_transactions_view.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../providers/auth_provider.dart';
import '../providers/budget_provider.dart';
import '../providers/transaction_provider.dart';
import '../providers/scheduled_transaction_provider.dart';
import '../providers/debt_provider.dart';
import 'dashboard/dashboard_view.dart';
import 'transactions/transaction_list_view.dart';
import 'budgets/budgets_view.dart';
import 'charts/analytics_view.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'debts/debt_management_view.dart';
import 'guide/app_tutorial_guide.dart';
import 'lifetime/lifetime_journey_view.dart';
import '../widgets/animated_nav_bar.dart';
import '../widgets/email_verification_banner.dart';
import '../widgets/glass_card.dart';
import '../widgets/quick_action_tile.dart';
import '../theme/app_text.dart';
import '../widgets/offline_aware_shell.dart';

class HomeNavigationScaffold extends StatefulWidget {
  const HomeNavigationScaffold({super.key});

  @override
  State<HomeNavigationScaffold> createState() => _HomeNavigationScaffoldState();
}

/// Order matches the screens in the [IndexedStack]. Each icon says what the tab holds.
const List<NavBarDestination> _navDestinations = [
  NavBarDestination(
    label: 'Dashboard',
    icon: Icons.space_dashboard_outlined,
    selectedIcon: Icons.space_dashboard_rounded,
  ),
  NavBarDestination(
    label: 'Transactions',
    icon: Icons.receipt_long_outlined,
    selectedIcon: Icons.receipt_long_rounded,
  ),
  NavBarDestination(
    label: 'Budgets',
    icon: Icons.account_balance_wallet_outlined,
    selectedIcon: Icons.account_balance_wallet_rounded,
  ),
  NavBarDestination(
    label: 'Analytics',
    icon: Icons.bar_chart_outlined,
    selectedIcon: Icons.bar_chart_rounded,
  ),
  NavBarDestination(
    label: 'Lifetime',
    icon: Icons.emoji_events_outlined,
    selectedIcon: Icons.emoji_events_rounded,
  ),
];

class _HomeNavigationScaffoldState extends State<HomeNavigationScaffold> {
  int _currentIndex = 0;
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      DashboardView(
        onViewTransactions: () => setState(() => _currentIndex = 1),
        onViewBudgets: () => setState(() => _currentIndex = 2),
        onViewAnalytics: () => setState(() => _currentIndex = 3),
      ),
      const TransactionListView(),
      const BudgetsView(),
      const AnalyticsView(),
      const LifetimeJourneyView(),
    ];
    _setupFcm();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndShowTutorial();
    });
  }

  Future<void> _checkAndShowTutorial() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      final authProv = Provider.of<AuthProvider>(context, listen: false);
      final uid = authProv.firebaseUser?.uid ?? 'guest';
      final hasSeenTutorial = prefs.getBool('has_seen_tutorial_$uid') ?? false;
      if (!hasSeenTutorial && mounted) {
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) {
          AppTutorialGuide.show(context);
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint("Error checking tutorial status: $e");
    }
  }

  Future<void> _setupFcm() async {
    try {
      // 1. Request Push Permissions (iOS / Android 13+)
      NotificationSettings settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        if (kDebugMode) debugPrint("Push notification permission authorized.");
      }

      // 2. Fetch target device push token
      String? token = await _fcm.getToken();
      if (token != null && mounted) {
        if (kDebugMode) debugPrint("FCM Registration Token: $token");
        // Sync registration token to backend database
        Provider.of<AuthProvider>(context, listen: false)
            .registerFcmToken(token);
      }

      // 3. Monitor token refresh updates
      _fcm.onTokenRefresh.listen((newToken) {
        if (mounted) {
          Provider.of<AuthProvider>(context, listen: false)
              .registerFcmToken(newToken);
        }
      });

      // 4. Foreground Message HUD alerts
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        if (!mounted) return;
        final title = message.notification?.title ?? "Budget Alert";
        final body = message.notification?.body ?? "";

        // Display gorgeous premium in-app glassmorphic SnackBar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            duration: const Duration(seconds: 4),
            content: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                child: Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 12.0),
                  decoration: BoxDecoration(
                    color:
                        context.tokens.coral.withValues(alpha: 0.9), // Glass Red
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.tokens.hairline),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          color: context.textPrimary, size: 24),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              title,
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: context.textPrimary),
                            ),
                            SizedBox(height: 2),
                            Text(
                              body,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: context.tokens.ink),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      });
    } catch (e) {
      if (kDebugMode) debugPrint("FCM Setup failed: $e");
    }
  }

  void _showQuickActionSheet(BuildContext context) {
    final budgetProv = Provider.of<BudgetProvider>(context, listen: false);
    final txProv = Provider.of<TransactionProvider>(context, listen: false);
    final schedProv =
        Provider.of<ScheduledTransactionProvider>(context, listen: false);
    final debtProv = Provider.of<DebtProvider>(context, listen: false);

    final sheetBg = context.tokens.panel;
    final titleTextColor = context.textPrimary;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final mediaQuery = MediaQuery.of(sheetContext);
        final systemBottomPadding = mediaQuery.viewPadding.bottom > 0
            ? mediaQuery.viewPadding.bottom
            : mediaQuery.padding.bottom;
        final effectiveBottomPadding =
            (systemBottomPadding > 0 ? systemBottomPadding : 16.0) + 20.0;

        return Container(
          decoration: BoxDecoration(
            color: sheetBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 24,
            bottom: effectiveBottomPadding,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              SizedBox(height: 16),
              Text('Quick actions',
                  style: AppText.title1.copyWith(color: titleTextColor)),
              SizedBox(height: 16),
              QuickActionTile(
                icon: Icons.add_rounded,
                color: context.tokens.emerald,
                title: 'Log expense or income',
                subtitle: 'Record a new transaction right away',
                onTap: () {
                  Navigator.pop(sheetContext);
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => const AddTransactionSheet(),
                  ).then((success) {
                    if (success == true) {
                      budgetProv.fetchSummary();
                      txProv.fetchTransactions(refresh: true);
                      debtProv.fetchSummary();
                    }
                  });
                },
              ),
              SizedBox(height: 8),
              QuickActionTile(
                icon: Icons.event_rounded,
                color: context.tokens.cobalt,
                title: 'Schedule a payment',
                subtitle: 'Set a recurring bill or future reminder',
                onTap: () {
                  Navigator.pop(sheetContext);
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => const AddScheduledTransactionSheet(),
                  ).then((_) {
                    schedProv.fetchScheduledTransactions();
                    budgetProv.fetchSummary();
                  });
                },
              ),
              SizedBox(height: 8),
              QuickActionTile(
                icon: Icons.category_rounded,
                color: context.tokens.amber,
                title: 'Create a category',
                subtitle: 'Add a custom expense or income category',
                onTap: () {
                  Navigator.pop(sheetContext);
                  BudgetsView.showCategoryFormDialog(context);
                },
              ),
              SizedBox(height: 8),
              QuickActionTile(
                icon: Icons.account_balance_rounded,
                color: context.tokens.emerald,
                title: 'Loans & debts',
                subtitle: 'Track borrowed loans & money lent out',
                onTap: () {
                  Navigator.pop(sheetContext);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const DebtManagementView(),
                    ),
                  ).then((_) {
                    debtProv.fetchSummary();
                    budgetProv.fetchSummary();
                  });
                },
              ),
              SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Canvas colour with two soft tonal fields for glass to sit over.
          const Positioned.fill(child: AmbientBackdrop()),

          Positioned.fill(
            child: Column(
              children: [
                const EmailVerificationBanner(),
                Expanded(
                  // While the reminder is visible it already covers the status bar, so
                  // the content below must not add that inset a second time. The shell
                  // is passed through the Selector unchanged to keep the tabs' state.
                  child: Selector<AuthProvider, bool>(
                    selector: (_, auth) => auth.showVerificationBanner,
                    builder: (context, bannerShown, child) =>
                        MediaQuery.removePadding(
                      context: context,
                      removeTop: bannerShown,
                      child: child!,
                    ),
                    child: OfflineAwareShell(
                      child: IndexedStack(
                        index: _currentIndex,
                        children: _screens,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton(
              onPressed: () => _showQuickActionSheet(context),
              tooltip: 'Add transaction',
              child: const Icon(Icons.add_rounded, size: 28),
            )
          : null,
      bottomNavigationBar: AnimatedNavBar(
        currentIndex: _currentIndex,
        destinations: _navDestinations,
        onTap: (index) {
          if (index == 0 && _currentIndex != 0) {
            Provider.of<BudgetProvider>(context, listen: false)
                .fetchSummary();
            Provider.of<TransactionProvider>(context, listen: false)
                .fetchTransactions(refresh: true);
            Provider.of<DebtProvider>(context, listen: false)
                .fetchSummary();
          }
          setState(() => _currentIndex = index);
        },
      ),
    );
  }
}
