import 'package:aureli/models/category_model.dart';
import 'package:aureli/models/transaction_model.dart';
import 'package:aureli/providers/auth_provider.dart';
import 'package:aureli/providers/transaction_provider.dart';
import 'package:aureli/services/offline_queue_service.dart';
import 'package:aureli/views/transactions/transaction_list_view.dart';
import 'package:aureli/widgets/offline_status_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'helpers/fake_server_api.dart';

class _FakeAuthProvider extends ChangeNotifier implements AuthProvider {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

Future<void> saveOffline(TransactionProvider p, {String note = 'n'}) =>
    p.saveTransactionOffline(
      type: TransactionType.EXPENSE,
      categoryId: 1,
      amount: 10,
      date: DateTime.now(),
      paymentMethod: PaymentMethod.CASH,
      note: note,
    );

Widget _app(TransactionProvider provider, Widget home) => MultiProvider(
      providers: [
        ChangeNotifierProvider<TransactionProvider>.value(value: provider),
        ChangeNotifierProvider<AuthProvider>.value(value: _FakeAuthProvider()),
      ],
      child: MaterialApp(home: Scaffold(body: home)),
    );

void main() {
  setUp(installFakeSecureStorage);

  group('discardPendingTransaction', () {
    test('removes a pending item from the queue and the list', () async {
      final api = FakeServerApi()..online = false;
      final p = TransactionProvider(api);
      await settle();
      await saveOffline(p, note: 'keep');
      await saveOffline(p, note: 'drop');
      final dropId = p.transactions.firstWhere((t) => t.note == 'drop').id;

      await p.discardPendingTransaction(dropId);

      expect(p.transactions.map((t) => t.note), ['keep']);
      expect((await OfflineQueueService.getPendingTransactions()).length, 1);
    });

    test('ignores ids that are not pending items', () async {
      final api = FakeServerApi()..online = false;
      final p = TransactionProvider(api);
      await settle();
      await saveOffline(p);

      await p.discardPendingTransaction(12345); // a server id / unknown id

      expect(p.pendingCount, 1);
    });
  });

  group('OfflineStatusBanner', () {
    testWidgets('is invisible when online with nothing pending', (tester) async {
      final provider = TransactionProvider(FakeServerApi());
      await tester.pumpWidget(_app(provider, const OfflineStatusBanner()));
      await tester.pump();

      expect(find.textContaining('offline'), findsNothing);
      expect(find.textContaining('waiting to sync'), findsNothing);
      expect(find.text('Sync now'), findsNothing);
    });

    testWidgets('reports offline state and pending count, then clears after Sync now', (tester) async {
      final api = FakeServerApi()..online = false;
      final provider = TransactionProvider(api);
      await tester.runAsync(() async {
        await settle();
        await saveOffline(provider);
        await saveOffline(provider);
        await provider.syncOfflineQueue(); // learns the server is unreachable
      });

      await tester.pumpWidget(_app(provider, const OfflineStatusBanner()));
      await tester.pump();

      expect(find.textContaining("You're offline"), findsOneWidget);
      expect(find.textContaining('2 transactions waiting to sync'), findsOneWidget);

      api.online = true;
      await tester.runAsync(() async {
        await tester.tap(find.text('Sync now'));
        await settle(200);
      });
      await tester.pump();

      expect(api.serverTransactions.length, 2);
      expect(find.textContaining('waiting to sync'), findsNothing);
      expect(find.textContaining("You're offline"), findsNothing);
    });

    testWidgets('online with pending items shows only the sync notice', (tester) async {
      final api = FakeServerApi()..failPosts = true;
      final provider = TransactionProvider(api);
      await tester.runAsync(() async {
        await settle();
        await saveOffline(provider);
      });

      await tester.pumpWidget(_app(provider, const OfflineStatusBanner()));
      await tester.pump();

      expect(find.text('1 transaction waiting to sync'), findsOneWidget);
      expect(find.textContaining("You're offline"), findsNothing);
    });
  });

  testWidgets('long-pressing a pending row offers to discard it', (tester) async {
    final api = FakeServerApi()..online = false;
    final provider = TransactionProvider(api);
    await tester.runAsync(() async {
      await settle();
      await saveOffline(provider, note: 'mistake entry');
    });

    await tester.pumpWidget(_app(provider, const TransactionListView()));
    await tester.pumpAndSettle();
    expect(find.text('mistake entry'), findsOneWidget);

    await tester.longPress(find.text('mistake entry'));
    await tester.pumpAndSettle();
    expect(find.text('Discard pending transaction?'), findsOneWidget);

    // "Keep" leaves it alone.
    await tester.tap(find.text('Keep'));
    await tester.pumpAndSettle();
    expect(find.text('mistake entry'), findsOneWidget);

    // "Discard" removes it for good.
    await tester.longPress(find.text('mistake entry'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle(); // dialog closes, discard starts
    await tester.runAsync(() => settle(200)); // let the storage write complete
    await tester.pumpAndSettle();

    expect(find.text('mistake entry'), findsNothing);
    expect(provider.pendingCount, 0);
  });
}
