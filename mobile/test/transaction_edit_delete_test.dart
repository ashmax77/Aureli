import 'package:aureli/models/category_model.dart';
import 'package:aureli/models/transaction_model.dart';
import 'package:aureli/providers/auth_provider.dart';
import 'package:aureli/providers/transaction_provider.dart';
import 'package:aureli/services/network_failure.dart';
import 'package:aureli/views/transactions/transaction_list_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'helpers/fake_server_api.dart';

class _FakeAuthProvider extends ChangeNotifier implements AuthProvider {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

Future<TransactionProvider> _loadedProvider(FakeServerApi api, {VoidCallback? onChanged}) async {
  final p = TransactionProvider(api, onFinancialDataChanged: onChanged);
  await settle();
  await p.fetchTransactions(refresh: true);
  return p;
}

Future<bool> _edit(TransactionProvider p, int id, {double amount = 650, String note = 'groceries'}) =>
    p.updateTransaction(
      id,
      type: TransactionType.EXPENSE,
      categoryId: 1,
      amount: amount,
      date: DateTime.now(),
      paymentMethod: PaymentMethod.CASH,
      note: note,
    );

void main() {
  setUp(installFakeSecureStorage);

  group('TransactionProvider.updateTransaction', () {
    test('updates the server copy and refreshes the list', () async {
      final api = FakeServerApi();
      seedServerTransaction(api, id: 7);
      var changed = 0;
      final p = await _loadedProvider(api, onChanged: () => changed++);

      expect(await _edit(p, 7, amount: 650), isTrue);

      expect(api.serverTransactions.single['amount'], 650);
      expect(p.transactions.single.amount, 650);
      expect(changed, 1, reason: 'budget/debt summaries get refreshed');
    });

    test('income keeps its savings settings (the server would otherwise re-enable savings)', () async {
      final api = FakeServerApi();
      seedServerTransaction(api, id: 8, type: 'INCOME', amount: 1000, isSavingsEnabled: false);
      final p = await _loadedProvider(api);

      final ok = await p.updateTransaction(
        8,
        type: TransactionType.INCOME,
        categoryId: 1,
        amount: 1200,
        date: DateTime.now(),
        paymentMethod: PaymentMethod.CASH,
        note: 'salary',
        isSavingsEnabled: false,
        savingsRate: 20,
      );

      expect(ok, isTrue);
      expect(api.lastPutBody!['isSavingsEnabled'], false);
      expect(api.lastPutBody!.containsKey('savingsRate'), isFalse,
          reason: 'no rate is sent when savings are off');
    });

    test('income with savings on sends the chosen rate; expenses send no savings fields', () async {
      final api = FakeServerApi();
      seedServerTransaction(api, id: 9, type: 'INCOME', isSavingsEnabled: true, savingsRate: 10);
      seedServerTransaction(api, id: 10);
      final p = await _loadedProvider(api);

      await p.updateTransaction(9,
          type: TransactionType.INCOME,
          categoryId: 1,
          amount: 100,
          date: DateTime.now(),
          paymentMethod: PaymentMethod.CASH,
          note: 'x',
          isSavingsEnabled: true,
          savingsRate: 15);
      expect(api.lastPutBody!['savingsRate'], 15);

      await _edit(p, 10);
      expect(api.lastPutBody!.containsKey('isSavingsEnabled'), isFalse);
    });

    test('offline: fails with a clear message, leaves data alone, does not blank the list', () async {
      final api = FakeServerApi();
      seedServerTransaction(api, id: 7);
      final p = await _loadedProvider(api);
      api.online = false;

      expect(await _edit(p, 7), isFalse);

      expect(p.actionErrorMessage, offlineWriteMessage);
      expect(p.errorMessage, isNull, reason: 'errorMessage would replace the whole list');
      expect(p.transactions.single.amount, 500);
      expect(api.serverTransactions.single['amount'], 500);
    });

    test('surfaces the server rejection message', () async {
      final api = FakeServerApi();
      seedServerTransaction(api, id: 7);
      final p = await _loadedProvider(api);
      api.failEdits = true;

      expect(await _edit(p, 7), isFalse);
      expect(p.actionErrorMessage, 'Edit rejected');
    });

    test('refuses a pending (unsynced) item without calling the server', () async {
      final api = FakeServerApi();
      final p = await _loadedProvider(api);

      expect(await _edit(p, -12345), isFalse);

      expect(api.putCount, 0);
      expect(p.actionErrorMessage, contains("hasn't synced"));
    });
  });

  group('TransactionProvider.deleteTransaction', () {
    test('removes it from the server and the list', () async {
      final api = FakeServerApi();
      seedServerTransaction(api, id: 7);
      seedServerTransaction(api, id: 8, note: 'keep me');
      var changed = 0;
      final p = await _loadedProvider(api, onChanged: () => changed++);

      expect(await p.deleteTransaction(7), isTrue);

      expect(api.serverTransactions.map((t) => t['id']), [8]);
      expect(p.transactions.map((t) => t.note), ['keep me']);
      expect(changed, 1);
    });

    test('an already-deleted transaction (404) counts as success and refreshes', () async {
      final api = FakeServerApi();
      seedServerTransaction(api, id: 7);
      final p = await _loadedProvider(api);
      api.serverTransactions.clear(); // deleted elsewhere

      expect(await p.deleteTransaction(7), isTrue);
      expect(p.transactions, isEmpty);
    });

    test('offline: keeps the transaction and explains why', () async {
      final api = FakeServerApi();
      seedServerTransaction(api, id: 7);
      final p = await _loadedProvider(api);
      api.online = false;

      expect(await p.deleteTransaction(7), isFalse);

      expect(p.actionErrorMessage, offlineWriteMessage);
      expect(p.errorMessage, isNull);
      expect(p.transactions.length, 1);
    });

    test('server failure keeps the transaction and reports the message', () async {
      final api = FakeServerApi();
      seedServerTransaction(api, id: 7);
      final p = await _loadedProvider(api);
      api.failEdits = true;

      expect(await p.deleteTransaction(7), isFalse);
      expect(p.actionErrorMessage, 'Delete rejected');
      expect(p.transactions.length, 1);
    });

    test('refuses a pending item (use discard) without calling the server', () async {
      final api = FakeServerApi();
      final p = await _loadedProvider(api);

      expect(await p.deleteTransaction(-5), isFalse);
      expect(api.deleteCount, 0);
    });
  });

  group('UI: tap a transaction to edit or delete, with confirmation', () {
    Future<void> pumpList(WidgetTester tester, TransactionProvider provider) async {
      // The edit sheet is tall; use a phone-like but roomy surface so its button is on screen.
      tester.view.physicalSize = const Size(900, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<TransactionProvider>.value(value: provider),
            ChangeNotifierProvider<AuthProvider>.value(value: _FakeAuthProvider()),
          ],
          child: const MaterialApp(home: TransactionListView()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() => settle(100));
      await tester.pumpAndSettle();
    }

    Future<void> afterWork(WidgetTester tester) async {
      await tester.pumpAndSettle();
      await tester.runAsync(() => settle(200));
      await tester.pumpAndSettle();
    }

    testWidgets('delete needs an explicit confirmation; "Keep" changes nothing', (tester) async {
      final api = FakeServerApi();
      seedServerTransaction(api, id: 7, note: 'old phone case');
      late TransactionProvider provider;
      await tester.runAsync(() async => provider = await _loadedProvider(api));
      await pumpList(tester, provider);

      await tester.tap(find.text('old phone case'));
      await tester.pumpAndSettle();
      expect(find.text('Edit'), findsOneWidget);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Delete this transaction?'), findsOneWidget);
      expect(api.deleteCount, 0, reason: 'nothing is sent before confirming');

      await tester.tap(find.text('Keep'));
      await afterWork(tester);

      expect(api.deleteCount, 0);
      expect(find.text('old phone case'), findsOneWidget);
    });

    testWidgets('confirming the delete removes it', (tester) async {
      final api = FakeServerApi();
      seedServerTransaction(api, id: 7, note: 'old phone case');
      late TransactionProvider provider;
      await tester.runAsync(() async => provider = await _loadedProvider(api));
      await pumpList(tester, provider);

      await tester.tap(find.text('old phone case'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await afterWork(tester);

      expect(api.deleteCount, 1);
      expect(api.serverTransactions, isEmpty);
      expect(find.text('old phone case'), findsNothing);
      expect(find.text('Transaction deleted'), findsOneWidget);
    });

    testWidgets('a failed delete (offline) keeps the row and explains why', (tester) async {
      final api = FakeServerApi();
      seedServerTransaction(api, id: 7, note: 'old phone case');
      late TransactionProvider provider;
      await tester.runAsync(() async => provider = await _loadedProvider(api));
      await pumpList(tester, provider);
      api.online = false;

      await tester.tap(find.text('old phone case'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await afterWork(tester);

      expect(find.text('old phone case'), findsOneWidget);
      expect(find.text(offlineWriteMessage), findsOneWidget);
    });

    testWidgets('edit shows the current values, then a review dialog before saving', (tester) async {
      final api = FakeServerApi();
      seedServerTransaction(api, id: 7, note: 'groceries', amount: 500);
      late TransactionProvider provider;
      await tester.runAsync(() async => provider = await _loadedProvider(api));
      await pumpList(tester, provider);

      await tester.tap(find.text('groceries'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      expect(find.text('Edit Transaction'), findsOneWidget);
      expect(find.widgetWithText(TextField, '500'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'groceries'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextField, '500'), '650');
      await tester.tap(find.text('Review & Save'));
      await tester.pumpAndSettle();

      // Verification: the user sees exactly what changes and must approve it.
      expect(find.text('Save these changes?'), findsOneWidget);
      expect(find.text('Amount: LKR 500 → LKR 650'), findsOneWidget);
      expect(api.putCount, 0, reason: 'nothing is sent before approval');

      // Cancel -> still nothing sent, sheet stays open for further edits.
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(api.putCount, 0);
      expect(find.text('Edit Transaction'), findsOneWidget);

      // Approve.
      await tester.tap(find.text('Review & Save'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save changes'));
      await afterWork(tester);

      expect(api.putCount, 1);
      expect(api.serverTransactions.single['amount'], 650);
      expect(find.text('Edit Transaction'), findsNothing, reason: 'sheet closed');
      expect(find.textContaining('650'), findsWidgets);
      expect(find.text('Transaction updated'), findsOneWidget);
    });

    testWidgets('saving without changing anything does not call the server', (tester) async {
      final api = FakeServerApi();
      seedServerTransaction(api, id: 7, note: 'groceries');
      late TransactionProvider provider;
      await tester.runAsync(() async => provider = await _loadedProvider(api));
      await pumpList(tester, provider);

      await tester.tap(find.text('groceries'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Review & Save'));
      await tester.pumpAndSettle();

      expect(find.text('No changes to save'), findsOneWidget);
      expect(find.text('Save these changes?'), findsNothing);
      expect(api.putCount, 0);
    });

    testWidgets('an approved edit that fails (offline) keeps the sheet open with the reason', (tester) async {
      final api = FakeServerApi();
      seedServerTransaction(api, id: 7, note: 'groceries', amount: 500);
      late TransactionProvider provider;
      await tester.runAsync(() async => provider = await _loadedProvider(api));
      await pumpList(tester, provider);

      await tester.tap(find.text('groceries'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, '500'), '900');
      api.online = false;
      await tester.tap(find.text('Review & Save'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save changes'));
      await afterWork(tester);

      expect(find.text('Edit Transaction'), findsOneWidget, reason: 'user keeps their input');
      expect(find.text(offlineWriteMessage), findsOneWidget);
      expect(api.serverTransactions.single['amount'], 500);
    });

    testWidgets('pending rows are not editable by tapping', (tester) async {
      final api = FakeServerApi()..online = false;
      late TransactionProvider provider;
      await tester.runAsync(() async {
        provider = TransactionProvider(api);
        await settle();
        await provider.saveTransactionOffline(
          type: TransactionType.EXPENSE,
          categoryId: 1,
          amount: 10,
          date: DateTime.now(),
          paymentMethod: PaymentMethod.CASH,
          note: 'queued item',
        );
      });
      await pumpList(tester, provider);

      await tester.tap(find.text('queued item'));
      await tester.pumpAndSettle();

      expect(find.text('Edit'), findsNothing);
      expect(find.text('Delete'), findsNothing);
    });
  });
}
