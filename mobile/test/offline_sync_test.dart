import 'dart:async';

import 'package:aureli/models/category_model.dart';
import 'package:aureli/models/transaction_model.dart';
import 'package:aureli/providers/transaction_provider.dart';
import 'package:aureli/services/offline_queue_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_server_api.dart';

Future<void> saveOffline(TransactionProvider p, {String note = 'n'}) =>
    p.saveTransactionOffline(
      type: TransactionType.EXPENSE,
      categoryId: 1,
      amount: 10,
      date: DateTime.now(),
      paymentMethod: PaymentMethod.CASH,
      note: note,
    );

void main() {
  setUp(installFakeSecureStorage);

  group('syncOfflineQueue', () {
    test('a dropped connection is not a rejection: no retry-count growth, pass stops early', () async {
      final api = FakeServerApi()..online = false;
      final p = TransactionProvider(api);
      await settle();
      await saveOffline(p, note: 'a');
      await saveOffline(p, note: 'b');

      await p.syncOfflineQueue();

      expect(api.postCount, 1, reason: 'stops after the first connection failure');
      expect(p.transactions.every((t) => t.syncAttempts == 0), isTrue);
      expect(p.isOffline, isTrue);
      expect(p.pendingCount, 2);
    });

    test('items queued while a sync runs are picked up by that sync', () async {
      final api = FakeServerApi();
      final p = TransactionProvider(api);
      await settle();
      await saveOffline(p, note: 'first');
      var injected = false;
      api.beforePost = () async {
        if (injected) return;
        injected = true;
        await saveOffline(p, note: 'second');
      };

      await p.syncOfflineQueue();

      expect(api.serverTransactions.length, 2);
      expect(p.pendingCount, 0);
    });

    test('a server rejection is counted and honours backoff, but explicit triggers bypass it', () async {
      final api = FakeServerApi()..failPosts = true;
      final p = TransactionProvider(api);
      await settle();
      await saveOffline(p);

      await p.syncOfflineQueue(); // rejected -> attempts 1, backoff 2s
      expect(p.transactions.single.syncAttempts, 1);

      api.failPosts = false;
      await p.syncOfflineQueue(); // still inside the backoff window
      expect(api.serverTransactions, isEmpty);
      expect(p.pendingCount, 1);

      await p.onAppResumed(); // explicit trigger ignores the backoff
      expect(api.serverTransactions.length, 1);
      expect(p.pendingCount, 0);
    });

    test('a trigger that arrives mid-sync is not lost', () async {
      final api = FakeServerApi()..failPostsRemaining = 1;
      final p = TransactionProvider(api);
      await settle();
      await saveOffline(p);
      var triggered = false;
      api.beforePost = () async {
        if (triggered) return;
        triggered = true;
        // e.g. the "network is back" event fires while the first attempt is in flight
        unawaited(p.onAppResumed());
      };

      await p.syncOfflineQueue(); // first POST rejected; the mid-sync trigger forces a 2nd pass

      expect(api.serverTransactions.length, 1);
      expect(p.pendingCount, 0);
    });

    test('notifies onQueueSynced only when something was actually synced', () async {
      final api = FakeServerApi()..online = false;
      var synced = 0;
      final p = TransactionProvider(api, onQueueSynced: () => synced++);
      await settle();
      await saveOffline(p);

      await p.syncOfflineQueue();
      expect(synced, 0);

      api.online = true;
      await p.syncOfflineQueue(ignoreBackoff: true);
      await settle();
      expect(synced, 1);

      await p.syncOfflineQueue(); // queue is empty now
      expect(synced, 1);
    });

    test('retries once on its own after a connection-level failure', () async {
      final api = FakeServerApi()..online = false;
      final p = TransactionProvider(api, retryDelay: const Duration(milliseconds: 80));
      await settle();
      await saveOffline(p);

      await p.syncOfflineQueue();
      expect(api.serverTransactions, isEmpty);

      api.online = true; // connectivity events can be missed; the timer is the backstop
      await settle(250);

      expect(api.serverTransactions.length, 1);
      expect(p.pendingCount, 0);
      p.dispose();
    });
  });

  group('connectivity & lifecycle triggers', () {
    test('network coming back syncs the queue and refreshes the list without user action', () async {
      final api = FakeServerApi()..online = false;
      final connectivity = StreamController<bool>();
      final p = TransactionProvider(api, connectivityChanges: connectivity.stream);
      await settle();
      await saveOffline(p, note: 'coffee');
      expect(p.transactions.single.isPending, isTrue);

      api.online = true;
      connectivity.add(true);
      await settle(150);

      expect(api.serverTransactions.length, 1);
      expect(p.pendingCount, 0);
      expect(p.transactions.length, 1);
      expect(p.transactions.single.isPending, isFalse);
      expect(p.isOffline, isFalse);
      await connectivity.close();
    });

    test('network coming back with nothing queued still refreshes stale data', () async {
      final api = FakeServerApi()..online = false;
      final connectivity = StreamController<bool>();
      final p = TransactionProvider(api, connectivityChanges: connectivity.stream);
      await settle();
      await p.fetchTransactions(refresh: true);
      expect(p.isOffline, isTrue);

      final today = DateTime.now();
      api
        ..online = true
        ..serverTransactions.add({
          'id': 5, 'amount': 20.0, 'type': 'EXPENSE', 'categoryId': 1,
          'categoryName': 'Food', 'paymentMethod': 'CASH', 'note': 'server side',
          'transactionDate':
              '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}',
          'createdAt': '2026-01-01T00:00:00',
        });
      connectivity.add(true);
      await settle(150);

      expect(p.transactions.map((t) => t.note), ['server side']);
      expect(p.isOffline, isFalse);
      await connectivity.close();
    });

    test('losing the network flags the provider offline immediately', () async {
      final connectivity = StreamController<bool>();
      final p = TransactionProvider(FakeServerApi(), connectivityChanges: connectivity.stream);
      await settle();
      expect(p.isOffline, isFalse);

      connectivity.add(false);
      await settle();

      expect(p.isOffline, isTrue);
      await connectivity.close();
    });

    test('disposing the provider stops listening to connectivity', () async {
      final api = FakeServerApi()..online = false;
      final connectivity = StreamController<bool>();
      final p = TransactionProvider(api, connectivityChanges: connectivity.stream);
      await settle();
      await saveOffline(p);
      p.dispose();

      api.online = true;
      connectivity.add(true);
      await settle(100);

      expect(api.serverTransactions, isEmpty, reason: 'no reaction after dispose');
      await connectivity.close();
    });
  });

  group('end to end: offline create -> restart -> reconnect', () {
    test('a transaction logged offline survives a restart and syncs exactly once', () async {
      final api = FakeServerApi()..online = false;
      final session1 = TransactionProvider(api);
      await settle();

      // What the dashboard does: try online, fall back to the offline queue on a network error.
      final result = await session1.createTransaction(
        type: TransactionType.EXPENSE,
        categoryId: 1,
        amount: 500,
        date: DateTime.now(),
        paymentMethod: PaymentMethod.CASH,
        note: 'groceries',
      );
      expect(result, TransactionCreateResult.networkError);
      await session1.saveTransactionOffline(
        type: TransactionType.EXPENSE,
        categoryId: 1,
        amount: 500,
        date: DateTime.now(),
        paymentMethod: PaymentMethod.CASH,
        note: 'groceries',
      );
      expect(session1.transactions.single.isPending, isTrue);

      // App is killed and relaunched while still offline.
      final connectivity = StreamController<bool>();
      final session2 = TransactionProvider(api, connectivityChanges: connectivity.stream);
      await settle();
      expect(session2.transactions.single.isPending, isTrue);
      expect(session2.transactions.single.note, 'groceries');

      // Network returns: no user action required.
      api.online = true;
      connectivity.add(true);
      await settle(200);

      expect(api.serverTransactions.length, 1);
      expect(session2.transactions.single.isPending, isFalse);
      expect(session2.pendingCount, 0);
      expect(await OfflineQueueService.getPendingTransactions(), isEmpty);
      await connectivity.close();
    });

    test('a response lost after the server committed does not create a duplicate', () async {
      final api = FakeServerApi()..dropResponseAfterCommit = true;
      final p = TransactionProvider(api);
      await settle();

      final result = await p.createTransaction(
        type: TransactionType.EXPENSE,
        categoryId: 1,
        amount: 80,
        date: DateTime.now(),
        paymentMethod: PaymentMethod.CASH,
        note: 'timeout case',
      );
      expect(result, TransactionCreateResult.networkError);
      expect(api.serverTransactions.length, 1, reason: 'server did store it');

      // User taps "Save Offline"; the queued replay reuses the same clientRequestId.
      await p.saveTransactionOffline(
        type: TransactionType.EXPENSE,
        categoryId: 1,
        amount: 80,
        date: DateTime.now(),
        paymentMethod: PaymentMethod.CASH,
        note: 'timeout case',
      );
      api.dropResponseAfterCommit = false;
      await p.syncOfflineQueue(ignoreBackoff: true);
      await settle();

      expect(api.serverTransactions.length, 1, reason: 'replay was deduplicated');
      expect(p.pendingCount, 0);
    });
  });
}
