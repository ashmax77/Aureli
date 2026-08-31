import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../providers/auth_provider.dart';
import '../providers/budget_provider.dart';
import 'dashboard/dashboard_view.dart';
import 'transactions/transaction_list_view.dart';
import 'budgets/budgets_view.dart';
import 'charts/analytics_view.dart';
import 'scheduled/scheduled_transactions_view.dart';

class HomeNavigationScaffold extends StatefulWidget {
  const HomeNavigationScaffold({super.key});

  @override
  State<HomeNavigationScaffold> createState() => _HomeNavigationScaffoldState();
}

class _HomeNavigationScaffoldState extends State<HomeNavigationScaffold> {
  int _currentIndex = 0;
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  @override
  void initState() {
    super.initState();
    _setupFcm();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<BudgetProvider>(context, listen: false).changeMonth(
        DateTime.now().year,
        DateTime.now().month,
      );
    });
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
        debugPrint("Push notification permission authorized.");
      }

      // 2. Fetch target device push token
      String? token = await _fcm.getToken();
      if (token != null && mounted) {
        debugPrint("FCM Registration Token: $token");
        // Sync registration token to backend database
        Provider.of<AuthProvider>(context, listen: false).registerFcmToken(token);
      }

      // 3. Monitor token refresh updates
      _fcm.onTokenRefresh.listen((newToken) {
        if (mounted) {
          Provider.of<AuthProvider>(context, listen: false).registerFcmToken(newToken);
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
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  decoration: BoxDecoration(
                    color: const Color(0xFFB42318).withOpacity(0.9), // Glass Red
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              body,
                              style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.9)),
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
      debugPrint("FCM Setup failed: $e");
    }
  }

  void _showQuickActionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF141C28),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "Quick Actions",
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF147D64).withOpacity(0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.add_rounded, color: Color(0xFF2CB8A0)),
              ),
              title: const Text(
                "Log Expense / Income",
                style: TextStyle(fontFamily: 'Manrope', color: Colors.white, fontWeight: FontWeight.bold),
              ),
              subtitle: const Text("Record a new transaction right away", style: TextStyle(fontSize: 12, color: Colors.white54)),
              onTap: () {
                Navigator.pop(context);
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => const AddTransactionSheet(),
                );
              },
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF6C8CFF).withOpacity(0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.event_rounded, color: Color(0xFF6C8CFF)),
              ),
              title: const Text(
                "Schedule Payment",
                style: TextStyle(fontFamily: 'Manrope', color: Colors.white, fontWeight: FontWeight.bold),
              ),
              subtitle: const Text("Set a recurring bill or future reminder", style: TextStyle(fontSize: 12, color: Colors.white54)),
              onTap: () {
                Navigator.pop(context);
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => const AddScheduledTransactionSheet(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      DashboardView(
        onViewTransactions: () => setState(() => _currentIndex = 1),
        onViewBudgets: () => setState(() => _currentIndex = 2),
        onViewAnalytics: () => setState(() => _currentIndex = 3),
      ),
      const TransactionListView(),
      const BudgetsView(),
      const AnalyticsView(),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF0F1621),
      body: Stack(
        children: [
          // Background blobs
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.transparent,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0B3B5A).withOpacity(0.5),
                    blurRadius: 100,
                    spreadRadius: 50,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            right: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.transparent,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF147D64).withOpacity(0.4),
                    blurRadius: 100,
                    spreadRadius: 50,
                  ),
                ],
              ),
            ),
          ),

          screens[_currentIndex],
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showQuickActionSheet(context),
        backgroundColor: const Color(0xFF147D64),
        foregroundColor: Colors.white,
        elevation: 6,
        shape: const CircleBorder(),
        child: const Icon(Icons.add_rounded, size: 28),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: BottomNavigationBar(
              currentIndex: _currentIndex,
              backgroundColor: const Color(0xFF141B26).withOpacity(0.85),
              selectedItemColor: const Color(0xFF147D64), // Emerald
              unselectedItemColor: Colors.white38,
              elevation: 0,
              type: BottomNavigationBarType.fixed,
              onTap: (index) {
                setState(() => _currentIndex = index);
              },
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.dashboard_rounded),
                  label: "Dashboard",
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.list_alt_rounded),
                  label: "Transactions",
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.pie_chart_rounded),
                  label: "Budgets",
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.analytics_rounded),
                  label: "Analytics",
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
