import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/budget_provider.dart';
import '../providers/debt_provider.dart';
import '../providers/lifetime_provider.dart';
import '../providers/transaction_provider.dart';
import 'offline_status_banner.dart';

/// Wraps the signed-in app content and wires up its offline behaviour:
///
/// * shows [OfflineStatusBanner] above the content and, while it is visible, removes the
///   top (status bar) inset from the content so tab app bars don't add it a second time;
/// * flushes the offline queue when this shell is first shown (app start / unlock) and
///   whenever the app returns to the foreground;
/// * refreshes budget and debt summaries after the transaction provider reports that
///   server-side transaction data changed (queue synced, transaction edited / deleted).
///
/// Must sit below the Transaction, Budget and Debt providers.
class OfflineAwareShell extends StatefulWidget {
  const OfflineAwareShell({super.key, required this.child});

  final Widget child;

  @override
  State<OfflineAwareShell> createState() => _OfflineAwareShellState();
}

class _OfflineAwareShellState extends State<OfflineAwareShell>
    with WidgetsBindingObserver {
  late final TransactionProvider _transactions;
  late final VoidCallback _refreshDependents;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _transactions = Provider.of<TransactionProvider>(context, listen: false);
    final budget = Provider.of<BudgetProvider>(context, listen: false);
    final debt = Provider.of<DebtProvider>(context, listen: false);
    final lifetime = Provider.of<LifetimeProvider>(context, listen: false);
    _refreshDependents = () {
      budget.fetchSummary(force: true); // Budgets and analytics
      budget.fetchDashboardSummary(force: true); // Dashboard
      debt.fetchSummary(force: true);
      lifetime.fetchLifetimeData(year: lifetime.selectedYear); // Lifetime tab
    };
    _transactions.onFinancialDataChanged = _refreshDependents;

    // App start or unlock: send anything that was saved offline earlier.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _transactions.onAppResumed();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _transactions.onAppResumed();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_transactions.onFinancialDataChanged == _refreshDependents) {
      _transactions.onFinancialDataChanged = null;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const OfflineStatusBanner(),
        Expanded(
          // The child is passed through the Selector unchanged so its state (tab
          // contents) survives the banner appearing and disappearing.
          child: Selector<TransactionProvider, bool>(
            selector: (_, p) => p.isOffline || p.pendingCount > 0,
            builder: (context, bannerShown, child) => MediaQuery.removePadding(
              context: context,
              removeTop: bannerShown,
              child: child!,
            ),
            child: widget.child,
          ),
        ),
      ],
    );
  }
}
