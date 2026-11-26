import 'dart:convert';

import 'package:aureli/models/category_model.dart';
import 'package:aureli/providers/auth_provider.dart';
import 'package:aureli/providers/budget_provider.dart';
import 'package:aureli/providers/transaction_provider.dart';
import 'package:aureli/services/api_service.dart';
import 'package:aureli/services/auth_service.dart';
import 'package:aureli/services/network_failure.dart';
import 'package:aureli/views/budgets/budgets_view.dart';
import 'package:aureli/views/onboarding/onboarding_view.dart';
import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import 'helpers/fake_server_api.dart';

/// Answers every request through [handler] and records what was asked.
class _ScriptedApi implements ApiService {
  _ScriptedApi(this.handler);

  http.Response Function(String method, String path) handler;
  final List<String> calls = [];

  @override
  String? get currentUserId => 'user-1';

  Future<http.Response> _answer(String method, String path) async {
    calls.add('$method $path');
    return handler(method, path);
  }

  @override
  Future<http.Response> get(String path, {Map<String, String>? queryParams}) =>
      _answer('GET', path);

  @override
  Future<http.Response> post(String path, Map<String, dynamic> body) =>
      _answer('POST', path);

  @override
  Future<http.Response> put(String path, Map<String, dynamic> body) =>
      _answer('PUT', path);

  @override
  Future<http.Response> patch(String path, Map<String, dynamic> body) =>
      _answer('PATCH', path);

  @override
  Future<http.Response> delete(String path) => _answer('DELETE', path);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _QuietGateway implements AuthGateway {
  @override
  User? get currentUser => null;

  @override
  Stream<User?> get userChanges => const Stream<User?>.empty();

  @override
  Future<String?> getIdToken([bool forceRefresh = false]) async => null;

  @override
  Future<void> sendPasswordResetEmail(String email) async {}

  @override
  Future<void> signIn(String email, String password) async {}

  @override
  Future<void> signOut() async {}

  @override
  Future<void> signUp(String email, String password) async {}
}

http.Response _json(Object body, int status) =>
    http.Response(jsonEncode(body), status);

final _offline = _json({'error': 'Network connection unreachable.', 'isOffline': true}, 503);
final _timeout = _json({'error': 'Connection timed out.', 'isTimeout': true}, 504);
final _rejected = _json({'message': 'Category name already exists'}, 409);
final _crash = http.Response('Internal Server Error', 500);

http.Response _userJson({String status = 'NOT_STARTED', double rate = 20}) => _json({
      'id': 1,
      'firebaseUid': 'user-1',
      'email': 'a@b.c',
      'onboardingStatus': status,
      'savingsRatePercentage': rate,
    }, 200);

void main() {
  setUp(installFakeSecureStorage);

  group('category writes (TransactionProvider)', () {
    test('say that the app is offline instead of failing silently', () async {
      final p = TransactionProvider(_ScriptedApi((_, __) => _offline));

      expect(await p.createCategory('Pets', TransactionType.EXPENSE), isFalse);
      expect(p.actionErrorMessage, offlineWriteMessage);

      expect(await p.updateCategory(1, 'Pets', TransactionType.EXPENSE), isFalse);
      expect(p.actionErrorMessage, offlineWriteMessage);

      expect(await p.deleteCategory(1), isFalse);
      expect(p.actionErrorMessage, offlineWriteMessage);
    });

    test('explain a timeout', () async {
      final p = TransactionProvider(_ScriptedApi((_, __) => _timeout));
      expect(await p.createCategory('Pets', TransactionType.EXPENSE), isFalse);
      expect(p.actionErrorMessage, timeoutWriteMessage);
    });

    test('surface the server\'s own message, or the status code when there is none', () async {
      final api = _ScriptedApi((_, __) => _rejected);
      final p = TransactionProvider(api);

      expect(await p.createCategory('Pets', TransactionType.EXPENSE), isFalse);
      expect(p.actionErrorMessage, 'Category name already exists');

      api.handler = (_, __) => _crash;
      expect(await p.deleteCategory(1), isFalse);
      expect(p.actionErrorMessage, contains('500'));
    });

    test('a later success clears the old message', () async {
      final api = _ScriptedApi((_, __) => _offline);
      final p = TransactionProvider(api);
      expect(await p.deleteCategory(1), isFalse);
      expect(p.actionErrorMessage, isNotNull);

      api.handler = (_, __) => http.Response('', 204);
      expect(await p.deleteCategory(1), isTrue);
      expect(p.actionErrorMessage, isNull);
    });

    test('failures do not blank the transaction list (errorMessage stays untouched)', () async {
      final p = TransactionProvider(_ScriptedApi((_, __) => _offline));
      await p.createCategory('Pets', TransactionType.EXPENSE);
      expect(p.errorMessage, isNull);
    });
  });

  group('budget limit write (BudgetProvider)', () {
    test('explains being offline and returns null', () async {
      final p = BudgetProvider(_ScriptedApi((_, __) => _offline));
      final result = await p.setCategoryBudget(
          categoryId: 1, month: DateTime(2026, 1, 1), limit: 100);
      expect(result, isNull);
      expect(p.errorMessage, offlineWriteMessage);
    });

    test('keeps the server\'s validation message and replaces a stale one', () async {
      final api = _ScriptedApi((_, __) => _offline);
      final p = BudgetProvider(api);
      await p.setCategoryBudget(categoryId: 1, month: DateTime(2026, 1, 1), limit: 100);
      expect(p.errorMessage, offlineWriteMessage);

      api.handler = (_, __) => _json({'message': 'Limit exceeds unallocated allowance'}, 400);
      await p.setCategoryBudget(categoryId: 1, month: DateTime(2026, 1, 1), limit: 100);
      expect(p.errorMessage, 'Limit exceeds unallocated allowance');
    });
  });

  group('profile writes (AuthProvider)', () {
    AuthProvider make(_ScriptedApi api) => AuthProvider(_QuietGateway(), api);

    test('savings rate: offline and server failures are reported', () async {
      final api = _ScriptedApi((_, __) => _offline);
      final auth = make(api);

      expect(await auth.updateSavingsRate(15), isFalse);
      expect(auth.actionErrorMessage, offlineWriteMessage);

      api.handler = (_, __) => _crash;
      expect(await auth.updateSavingsRate(15), isFalse);
      expect(auth.actionErrorMessage, contains('500'));

      // The sign-in screens' own message is not hijacked.
      expect(auth.errorMessage, isNull);
    });

    test('savings rate: success stores the value and clears the message', () async {
      final api = _ScriptedApi((_, __) => _offline);
      final auth = make(api);
      await auth.updateSavingsRate(15);
      expect(auth.actionErrorMessage, isNotNull);

      api.handler = (_, __) => _userJson(rate: 15);
      expect(await auth.updateSavingsRate(15), isTrue);
      expect(auth.actionErrorMessage, isNull);
      expect(auth.userModel?.savingsRatePercentage, 15);
    });

    test('onboarding completion explains being offline', () async {
      final auth = make(_ScriptedApi((_, __) => _offline));
      expect(await auth.completeOnboarding(), isFalse);
      expect(auth.actionErrorMessage, offlineWriteMessage);
    });
  });

  group('screens', () {
    testWidgets('a failed category save keeps the dialog open and shows why (no "created!")',
        (tester) async {
      final api = _ScriptedApi((_, __) => _offline);
      final transactions = TransactionProvider(api);
      final budgets = BudgetProvider(api);

      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<TransactionProvider>.value(value: transactions),
          ChangeNotifierProvider<BudgetProvider>.value(value: budgets),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => BudgetsView.showCategoryFormDialog(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Create Category'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'Pets');
      await tester.tap(find.text('Create'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text(offlineWriteMessage), findsOneWidget);
      expect(find.textContaining('created!'), findsNothing);
      // Dialog is still open with what the user typed, and can be retried.
      expect(find.text('Create Category'), findsOneWidget);
      expect(find.text('Pets'), findsOneWidget);
      expect(find.text('Create'), findsOneWidget);
    });

    testWidgets('onboarding stops at the first failed step and shows the reason',
        (tester) async {
      tester.view.physicalSize = const Size(900, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      // Categories load fine, saving the savings rate fails (offline).
      final api = _ScriptedApi((method, path) {
        if (method == 'GET' && path == '/categories') return _json([], 200);
        return _offline;
      });
      final auth = AuthProvider(_QuietGateway(), api);
      final transactions = TransactionProvider(api);
      final budgets = BudgetProvider(api);

      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider<TransactionProvider>.value(value: transactions),
          ChangeNotifierProvider<BudgetProvider>.value(value: budgets),
        ],
        child: const MaterialApp(home: OnboardingView()),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Complete Onboarding Setup'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text(offlineWriteMessage), findsOneWidget);
      expect(api.calls, contains('PATCH /me/savings-rate'));
      expect(api.calls, isNot(contains('PATCH /me/onboarding')),
          reason: 'must not mark onboarding complete after a failed step');
      // Button is back so the user can simply try again.
      expect(find.text('Complete Onboarding Setup'), findsOneWidget);
    });

    testWidgets('onboarding reports a failure of the final step too', (tester) async {
      tester.view.physicalSize = const Size(900, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final api = _ScriptedApi((method, path) {
        if (method == 'GET' && path == '/categories') return _json([], 200);
        if (path == '/me/savings-rate') return _userJson();
        return _timeout; // /me/onboarding
      });
      final auth = AuthProvider(_QuietGateway(), api);

      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider<TransactionProvider>.value(value: TransactionProvider(api)),
          ChangeNotifierProvider<BudgetProvider>.value(value: BudgetProvider(api)),
        ],
        child: const MaterialApp(home: OnboardingView()),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.runAsync(() async {
        await tester.tap(find.text('Complete Onboarding Setup'));
        await settle(150); // the successful savings-rate call writes to storage
      });
      await tester.pump();

      expect(find.text(timeoutWriteMessage), findsOneWidget);
    });
  });
}
