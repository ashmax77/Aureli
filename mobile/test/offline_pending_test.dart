import 'package:aureli/models/category_model.dart';
import 'package:aureli/models/transaction_model.dart';
import 'package:aureli/providers/auth_provider.dart';
import 'package:aureli/providers/transaction_provider.dart';
import 'package:aureli/services/offline_queue_service.dart';
import 'package:aureli/views/transactions/transaction_list_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'helpers/fake_server_api.dart';

/// The list view only reads `userModel` (null = no registration-date limit).
class _FakeAuthProvider extends ChangeNotifier implements AuthProvider {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

Widget _listApp(TransactionProvider provider) => MultiProvider(
      providers: [
        ChangeNotifierProvider<TransactionProvider>.value(value: provider),
        ChangeNotifierProvider<AuthProvider>.value(value: _FakeAuthProvider()),
      ],
      child: const MaterialApp(home: TransactionListView()),
    );

Future<void> saveOffline(
  TransactionProvider p, {
  double amount = 250,
  String note = 'queued',
  DateTime? date,
  TransactionType type = TransactionType.EXPENSE,
}) =>
    p.saveTransactionOffline(
      type: type,
      categoryId: 1,
      amount: amount,
      date: date ?? DateTime.now(),
      paymentMethod: PaymentMethod.CASH,
      note: note,
    );

void main() {
  late Map<String, String> store;
  setUp(() => store = installFakeSecureStorage());

  group('pending (offline-queued) transactions', () {
    test('are shown, flagged pending, right after being saved offline', () async {
      final api = FakeServerApi()..online = false;
      final p = TransactionProvider(api);
      await settle();
      await saveOffline(p);

      expect(p.transactions.length, 1);
      expect(p.transactions.first.isPending, isTrue);
      expect(p.transactions.first.syncAttempts, 0);
      expect(p.pendingCount, 1);
    });

    test('are restored after an app restart', () async {
      final api = FakeServerApi()..online = false;
      final first = TransactionProvider(api);
      await settle();
      await saveOffline(first, amount: 410, note: 'bus fare');

      final restarted = TransactionProvider(api); // same storage, new instance
      await settle();

      expect(restarted.transactions.length, 1);
      final tx = restarted.transactions.single;
      expect(tx.isPending, isTrue);
      expect(tx.amount, 410);
      expect(tx.note, 'bus fare');
    });

    test('stay visible when a refresh happens before they sync', () async {
      final api = FakeServerApi()..online = false;
      final p = TransactionProvider(api);
      await settle();
      await saveOffline(p);

      api
        ..online = true
        ..failPosts = true; // reachable, but the replay is rejected for now
      await p.fetchTransactions(refresh: true);
      await settle();

      expect(p.transactions.length, 1);
      expect(p.transactions.single.isPending, isTrue);
    });

    test('are layered above the server list without duplicating it', () async {
      final api = FakeServerApi();
      final today = DateTime.now();
      final iso =
          '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      api.serverTransactions.add({
        'id': 99, 'amount': 75.0, 'type': 'EXPENSE', 'categoryId': 1,
        'categoryName': 'Food', 'transactionDate': iso, 'paymentMethod': 'CASH',
        'note': 'from server', 'createdAt': '2026-01-01T00:00:00',
      });
      final p = TransactionProvider(api);
      await settle();
      api.failPosts = true;
      await saveOffline(p, note: 'local only');
      await p.fetchTransactions(refresh: true);
      await settle();

      expect(p.transactions.map((t) => t.note), ['local only', 'from server']);
      expect(p.transactions.map((t) => t.isPending), [true, false]);
    });

    test('are hidden when outside the selected month', () async {
      final api = FakeServerApi()..online = false;
      final p = TransactionProvider(api);
      await settle();
      final now = DateTime.now();
      await saveOffline(p, date: DateTime(now.year, now.month - 1, 15));

      expect(p.pendingCount, 1, reason: 'still queued');
      expect(p.transactions, isEmpty, reason: 'but not part of this month view');
    });

    test('respect active filters', () async {
      final api = FakeServerApi()..online = false;
      final p = TransactionProvider(api);
      await settle();
      await saveOffline(p, note: 'coffee', amount: 300);

      p.selectedType = TransactionType.INCOME;
      await p.fetchTransactions(refresh: true);
      expect(p.transactions, isEmpty, reason: 'expense hidden by income filter');

      p.selectedType = null;
      p.searchQuery = 'tea';
      await p.fetchTransactions(refresh: true);
      expect(p.transactions, isEmpty, reason: 'note does not match search');

      p.searchQuery = 'COFF';
      await p.fetchTransactions(refresh: true);
      expect(p.transactions.length, 1, reason: 'case-insensitive note match');

      p.searchQuery = '';
      p.minAmount = 500;
      await p.fetchTransactions(refresh: true);
      expect(p.transactions, isEmpty, reason: 'below min amount');
    });

    test('surface a rejected sync via syncAttempts', () async {
      final api = FakeServerApi();
      final p = TransactionProvider(api);
      await settle();
      api.failPosts = true;
      await saveOffline(p);

      await p.syncOfflineQueue();

      expect(p.transactions.single.isPending, isTrue);
      expect(p.transactions.single.syncAttempts, 1);
    });

    test('disappear once synced, leaving exactly one server copy', () async {
      final api = FakeServerApi()..online = false;
      final p = TransactionProvider(api);
      await settle();
      await saveOffline(p, amount: 125, note: 'lunch');

      api.online = true;
      await p.syncOfflineQueue();
      await settle();

      expect(api.serverTransactions.length, 1);
      expect(p.pendingCount, 0);
      expect(await OfflineQueueService.getPendingTransactions(), isEmpty);
      expect(p.transactions.length, 1);
      expect(p.transactions.single.isPending, isFalse);
      expect(p.transactions.single.note, 'lunch');
    });

    test('never leak into the snapshot cache', () async {
      final api = FakeServerApi();
      final p = TransactionProvider(api);
      await settle();
      api.failPosts = true;
      await saveOffline(p, note: 'secret-pending-note');
      await p.fetchTransactions(refresh: true);
      await settle();

      final cacheEntries = store.entries
          .where((e) => e.key == 'aureli:user-1:transactions')
          .map((e) => e.value);
      expect(cacheEntries, isNotEmpty, reason: 'a snapshot was written');
      expect(cacheEntries.any((v) => v.contains('secret-pending-note')), isFalse);
    });
  });

  testWidgets('transaction list shows a Pending sync badge for queued items', (tester) async {
    final api = FakeServerApi()..online = false;
    final provider = TransactionProvider(api);
    await tester.runAsync(() async {
      await settle();
      await saveOffline(provider, note: 'taxi home');
    });

    await tester.pumpWidget(_listApp(provider));
    await tester.pumpAndSettle();

    expect(find.text('taxi home'), findsOneWidget);
    expect(find.text('Pending sync'), findsOneWidget);
  });

  testWidgets('a rejected pending item reads "Sync failed"', (tester) async {
    final api = FakeServerApi();
    final provider = TransactionProvider(api);
    await tester.runAsync(() async {
      await settle();
      api.failPosts = true;
      await saveOffline(provider, note: 'rent');
      await provider.syncOfflineQueue();
    });

    await tester.pumpWidget(_listApp(provider));
    await tester.pumpAndSettle();

    expect(find.text('Sync failed - will retry - hold to discard'), findsOneWidget);
    expect(find.text('Pending sync'), findsNothing);
  });
}
