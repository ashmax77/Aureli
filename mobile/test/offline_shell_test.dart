import 'package:aureli/models/category_model.dart';
import 'package:aureli/models/transaction_model.dart';
import 'package:aureli/providers/budget_provider.dart';
import 'package:aureli/providers/debt_provider.dart';
import 'package:aureli/providers/lifetime_provider.dart';
import 'package:aureli/providers/transaction_provider.dart';
import 'package:aureli/services/offline_queue_service.dart';
import 'package:aureli/services/snapshot_cache_service.dart';
import 'package:aureli/widgets/offline_aware_shell.dart';
import 'package:aureli/widgets/offline_status_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'helpers/fake_server_api.dart';

Future<void> _saveOffline(TransactionProvider p, {String note = 'n'}) =>
    p.saveTransactionOffline(
      type: TransactionType.EXPENSE,
      categoryId: 1,
      amount: 10,
      date: DateTime.now(),
      paymentMethod: PaymentMethod.CASH,
      note: note,
    );

/// Records the top inset it is given and how many times its state was created.
class _Probe extends StatefulWidget {
  const _Probe();
  static int created = 0;
  static double? topInset;

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  @override
  void initState() {
    super.initState();
    _Probe.created++;
  }

  @override
  Widget build(BuildContext context) {
    _Probe.topInset = MediaQuery.paddingOf(context).top;
    return const SizedBox.expand(key: Key('probe'));
  }
}

class _Harness {
  _Harness(this.api)
      : transactions = TransactionProvider(api),
        budgets = BudgetProvider(api),
        debts = DebtProvider(api),
        lifetime = LifetimeProvider(api);

  final FakeServerApi api;
  final TransactionProvider transactions;
  final BudgetProvider budgets;
  final DebtProvider debts;
  final LifetimeProvider lifetime;

  Widget app({Widget child = const _Probe(), bool showShell = true}) => MultiProvider(
        providers: [
          ChangeNotifierProvider<TransactionProvider>.value(value: transactions),
          ChangeNotifierProvider<BudgetProvider>.value(value: budgets),
          ChangeNotifierProvider<DebtProvider>.value(value: debts),
          ChangeNotifierProvider<LifetimeProvider>.value(value: lifetime),
        ],
        child: MaterialApp(
          home: showShell ? OfflineAwareShell(child: child) : const SizedBox(),
        ),
      );
}

/// Lets work started in both zones finish. Storage replies arrive in the real zone but
/// the continuations of code started during a pump only run when the test zone is pumped,
/// so alternate between the two (leaving a half-finished queue write would block the
/// shared write chain of the next test).
Future<void> _drain(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.runAsync(() => settle(60));
    await tester.pump();
  }
}

/// End-of-test cleanup for tests that mounted the shell: finish pending work, unmount,
/// dispose the providers (cancels the 30 s retry timer) and flush storage. A sync started
/// while pumping can leave the queue's shared static write chain half-finished, which
/// would block the next test's first write.
Future<void> _finish(WidgetTester tester, _Harness h) async {
  await _drain(tester);
  await tester.pumpWidget(const SizedBox());
  h.transactions.dispose();
  h.budgets.dispose();
  h.debts.dispose();
  h.lifetime.dispose();
  await tester.runAsync(() => OfflineQueueService.clearQueue().timeout(const Duration(seconds: 3)));
}

/// Simulates a status bar / notch that is [top] logical pixels tall.
void _simulateStatusBar(WidgetTester tester, [double top = 40]) {
  final physical = top * tester.view.devicePixelRatio;
  tester.view.padding = FakeViewPadding(top: physical);
  tester.view.viewPadding = FakeViewPadding(top: physical);
  addTearDown(tester.view.reset);
}

Future<void> _backgroundThenResume(WidgetTester tester) async {
  final binding = tester.binding;
  for (final s in [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
  ]) {
    binding.handleAppLifecycleStateChanged(s);
  }
  await tester.runAsync(() async {
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await settle(250);
  });
  await tester.pump();
}

void main() {
  setUp(() {
    installFakeSecureStorage();
    _Probe.created = 0;
    _Probe.topInset = null;
  });

  group('describeDataAge', () {
    final now = DateTime(2026, 6, 10, 12);
    String age(Duration d) => describeDataAge(now.subtract(d), now: now);

    test('uses the largest sensible unit', () {
      expect(age(const Duration(seconds: 20)), 'just now');
      expect(age(const Duration(minutes: 1)), '1 min ago');
      expect(age(const Duration(minutes: 59)), '59 min ago');
      expect(age(const Duration(minutes: 60)), '1 h ago');
      expect(age(const Duration(hours: 23, minutes: 59)), '23 h ago');
      expect(age(const Duration(hours: 24)), '1 day ago');
      expect(age(const Duration(days: 3)), '3 days ago');
    });

    test('a clock set slightly back does not produce a negative age', () {
      expect(describeDataAge(now.add(const Duration(minutes: 2)), now: now), 'just now');
    });
  });

  group('TransactionProvider.lastUpdatedAt', () {
    test('is null until something loads, then set by a successful fetch', () async {
      final api = FakeServerApi();
      final p = TransactionProvider(api);
      await settle();
      expect(p.lastUpdatedAt, isNull);

      final before = DateTime.now();
      await p.fetchTransactions(refresh: true);
      expect(p.lastUpdatedAt, isNotNull);
      expect(p.lastUpdatedAt!.isBefore(before), isFalse);
    });

    test('after a restart it is the saved snapshot\'s age, not "now"', () async {
      final threeHoursAgo = DateTime.now().subtract(const Duration(hours: 3));
      final now = DateTime.now();
      await SnapshotCacheService.write(
        userId: 'user-1',
        resource: 'transactions',
        data: {'year': now.year, 'month': now.month, 'transactions': []},
        savedAt: threeHoursAgo,
      );

      final p = TransactionProvider(FakeServerApi()..online = false);
      await settle();

      expect(p.lastUpdatedAt, isNotNull);
      expect(now.difference(p.lastUpdatedAt!).inMinutes, inInclusiveRange(179, 181));
    });

    test('a failed (offline) fetch does not make old data look fresh', () async {
      final api = FakeServerApi();
      final p = TransactionProvider(api);
      await settle();
      await p.fetchTransactions(refresh: true);
      final stamp = p.lastUpdatedAt;

      api.online = false;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await p.fetchTransactions(refresh: true);

      expect(p.isOffline, isTrue);
      expect(p.lastUpdatedAt, stamp);
    });
  });

  group('OfflineStatusBanner cache age', () {
    testWidgets('says how old the saved data is while offline', (tester) async {
      final now = DateTime.now();
      await tester.runAsync(() async {
        await SnapshotCacheService.write(
          userId: 'user-1',
          resource: 'transactions',
          data: {'year': now.year, 'month': now.month, 'transactions': []},
          savedAt: now.subtract(const Duration(hours: 3)),
        );
      });
      final api = FakeServerApi()..online = false;
      final provider = TransactionProvider(api);
      await tester.runAsync(() async {
        await settle();
        await provider.fetchTransactions(refresh: true); // learns the server is unreachable
      });

      await tester.pumpWidget(MultiProvider(
        providers: [ChangeNotifierProvider<TransactionProvider>.value(value: provider)],
        child: const MaterialApp(home: Scaffold(body: OfflineStatusBanner())),
      ));
      await tester.pump();

      expect(find.text("You're offline - showing saved data from 3 h ago"), findsOneWidget);
    });

    testWidgets('does not invent an age when none is known', (tester) async {
      final api = FakeServerApi()..online = false;
      final provider = TransactionProvider(api);
      await tester.runAsync(() async {
        await settle();
        await _saveOffline(provider);
        await provider.fetchTransactions(refresh: true);
      });
      expect(provider.lastUpdatedAt, isNull); // nothing was ever loaded on this device

      await tester.pumpWidget(MultiProvider(
        providers: [ChangeNotifierProvider<TransactionProvider>.value(value: provider)],
        child: const MaterialApp(home: Scaffold(body: OfflineStatusBanner())),
      ));
      await tester.pump();

      // No known age -> the banner must not invent one.
      expect(find.textContaining('saved data from'), findsNothing);
      expect(find.textContaining("You're offline - showing saved data. 1 transaction waiting to sync"),
          findsOneWidget);
    });
  });

  group('OfflineAwareShell layout', () {
    testWidgets('removes the top inset from the content only while the banner is shown',
        (tester) async {
      _simulateStatusBar(tester);
      final h = _Harness(FakeServerApi());
      await tester.pumpWidget(h.app());
      await tester.pump();

      // Online, nothing pending: no banner, content keeps the status-bar inset.
      expect(find.byType(OfflineStatusBanner), findsOneWidget);
      expect(find.textContaining('offline'), findsNothing);
      expect(_Probe.topInset, 40);
      final createdBefore = _Probe.created;

      // Offline with a pending item: banner appears and takes over the inset.
      await tester.runAsync(() async {
        h.api.online = false;
        await settle();
        await _saveOffline(h.transactions);
        await h.transactions.syncOfflineQueue();
      });
      await tester.pump();

      expect(find.textContaining("You're offline"), findsOneWidget);
      expect(_Probe.topInset, 0, reason: 'banner already covers the status bar');
      // The banner itself sits below the status bar.
      final bannerTop = tester.getTopLeft(find.byType(OfflineStatusBanner)).dy;
      final contentTop = tester.getTopLeft(find.byKey(const Key('probe'))).dy;
      expect(bannerTop, 0);
      expect(contentTop, greaterThan(40), reason: 'content starts below the banner, not under it');

      // Back online and synced: inset returns, and the content was never rebuilt from scratch.
      await tester.runAsync(() async {
        h.api.online = true;
        await h.transactions.syncNow();
        await settle(100);
      });
      await tester.pump();
      expect(find.textContaining('waiting to sync'), findsNothing);
      expect(_Probe.topInset, 40);
      expect(_Probe.created, createdBefore, reason: 'tab state must survive banner changes');
      await _finish(tester, h);
    });
  });

  group('OfflineAwareShell sync triggers', () {
    testWidgets('flushes the queue when the shell is first shown', (tester) async {
      final api = FakeServerApi()..online = false;
      final h = _Harness(api);
      await tester.runAsync(() async {
        await settle();
        await _saveOffline(h.transactions, note: 'saved on the train');
        api.online = true; // connectivity is back by the time the app opens
      });

      await tester.pumpWidget(h.app());
      await _drain(tester);
      await tester.pump();

      expect(api.serverTransactions.map((t) => t['note']), ['saved on the train']);
      expect(h.transactions.pendingCount, 0);
      await _finish(tester, h);
    });

    testWidgets('flushes the queue when the app returns to the foreground', (tester) async {
      final api = FakeServerApi()..online = false;
      final h = _Harness(api);
      await tester.runAsync(() async {
        await settle();
        await _saveOffline(h.transactions, note: 'queued');
      });

      await tester.pumpWidget(h.app());
      await _drain(tester);
      await tester.pump();
      expect(api.serverTransactions, isEmpty);
      expect(h.transactions.pendingCount, 1);

      api.online = true; // network returned while the app was in the background
      await _backgroundThenResume(tester);

      expect(api.serverTransactions.length, 1);
      expect(h.transactions.pendingCount, 0);
      await _finish(tester, h);
    });

    testWidgets('does nothing on resume when there is nothing queued', (tester) async {
      final api = FakeServerApi();
      final h = _Harness(api);
      await tester.pumpWidget(h.app());
      await _drain(tester);
      final posts = api.postCount;

      await _backgroundThenResume(tester);

      expect(api.postCount, posts);
      expect(find.textContaining('waiting to sync'), findsNothing);
      await _finish(tester, h);
    });

    testWidgets('stops reacting to resume once the shell is gone', (tester) async {
      final api = FakeServerApi()..online = false;
      final h = _Harness(api);
      await tester.runAsync(() async {
        await settle();
        await _saveOffline(h.transactions);
      });
      await tester.pumpWidget(h.app());
      await _drain(tester);

      await tester.pumpWidget(h.app(showShell: false)); // e.g. app locked / signed out
      await tester.pump();
      api.online = true;
      await _backgroundThenResume(tester);

      expect(api.serverTransactions, isEmpty, reason: 'observer must be removed on dispose');
      expect(h.transactions.onFinancialDataChanged, isNull);
      await _finish(tester, h);
    });
  });

  group('OfflineAwareShell summary refresh', () {
    testWidgets('a synced queue refreshes budget, dashboard and debt summaries', (tester) async {
      final api = FakeServerApi()..online = false;
      final h = _Harness(api);
      await tester.runAsync(() async {
        await settle();
        await _saveOffline(h.transactions);
      });
      await tester.pumpWidget(h.app());
      await _drain(tester);
      api.getPaths.clear();

      api.online = true;
      await tester.runAsync(() async {
        await h.transactions.syncNow();
        await settle(150);
      });

      expect(api.getPaths, containsAll(['/budgets/summary', '/debts/summary']));
      await _finish(tester, h);
    });

    testWidgets('does not refresh them when nothing was actually synced', (tester) async {
      final api = FakeServerApi();
      final h = _Harness(api);
      await tester.pumpWidget(h.app());
      await _drain(tester);
      api.getPaths.clear();

      await tester.runAsync(() async {
        await h.transactions.syncNow();
        await settle(100);
      });

      expect(api.getPaths.where((p) => p.startsWith('/budgets') || p.startsWith('/debts')), isEmpty);
      await _finish(tester, h);
    });

    testWidgets('an online save refreshes every summary the tabs show', (tester) async {
      final api = FakeServerApi();
      final h = _Harness(api);
      await tester.pumpWidget(h.app());
      await _drain(tester);
      api.getPaths.clear();

      await tester.runAsync(() async {
        final result = await h.transactions.createTransaction(
          type: TransactionType.EXPENSE,
          categoryId: 1,
          amount: 25,
          date: DateTime.now(),
          paymentMethod: PaymentMethod.CASH,
        );
        expect(result, TransactionCreateResult.success);
        await settle(150);
      });

      // Budgets/analytics and the dashboard both read /budgets/summary; there's one request each.
      expect(api.getPaths.where((p) => p == '/budgets/summary'), hasLength(2));
      expect(api.getPaths, containsAll(['/debts/summary', '/lifetime/stats']));
      await _finish(tester, h);
    });

    testWidgets('a failed save refreshes nothing', (tester) async {
      final api = FakeServerApi()..failPosts = true;
      final h = _Harness(api);
      await tester.pumpWidget(h.app());
      await _drain(tester);
      api.getPaths.clear();

      await tester.runAsync(() async {
        final result = await h.transactions.createTransaction(
          type: TransactionType.EXPENSE,
          categoryId: 1,
          amount: 25,
          date: DateTime.now(),
          paymentMethod: PaymentMethod.CASH,
        );
        expect(result, TransactionCreateResult.failed);
        await settle(100);
      });

      expect(api.getPaths.where((p) => p.startsWith('/budgets') || p.startsWith('/lifetime')), isEmpty);
      await _finish(tester, h);
    });

    testWidgets('the callback is wired while mounted and removed on dispose', (tester) async {
      final h = _Harness(FakeServerApi());
      await tester.pumpWidget(h.app());
      expect(h.transactions.onFinancialDataChanged, isNotNull);

      await tester.pumpWidget(h.app(showShell: false));
      expect(h.transactions.onFinancialDataChanged, isNull);
      await _finish(tester, h);
    });
  });
}
