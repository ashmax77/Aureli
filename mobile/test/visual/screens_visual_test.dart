// Renders the real screens with realistic demo data to PNG files so the design can be
// reviewed without a device (the phone blocks screenshots by design).
//
//   flutter test test/visual --dart-define=SCREENSHOTS=true
//
// Output: build/screens/<theme>-<screen>.png. Skipped in a normal test run.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:aureli/providers/auth_provider.dart';
import 'package:aureli/providers/budget_provider.dart';
import 'package:aureli/providers/debt_provider.dart';
import 'package:aureli/providers/lifetime_provider.dart';
import 'package:aureli/providers/notification_provider.dart';
import 'package:aureli/providers/scheduled_transaction_provider.dart';
import 'package:aureli/providers/security_provider.dart';
import 'package:aureli/providers/theme_provider.dart';
import 'package:aureli/providers/transaction_provider.dart';
import 'package:aureli/services/api_service.dart';
import 'package:aureli/services/auth_service.dart';
import 'package:aureli/theme/app_theme.dart';
import 'package:aureli/views/auth/auth_view.dart';
import 'package:aureli/views/debts/debt_management_view.dart';
import 'package:aureli/views/home_navigation_scaffold.dart';
import 'package:aureli/views/onboarding/onboarding_view.dart';
import 'package:aureli/views/profile/profile_view.dart';
import 'package:aureli/views/scheduled/scheduled_transactions_view.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart' show setupFirebaseCoreMocks;
import 'package:firebase_core/firebase_core.dart' show Firebase;
import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'dart:typed_data' show ByteData;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fake_server_api.dart';

const _enabled = bool.fromEnvironment('SCREENSHOTS');

class _FakeUser implements User {
  @override
  String get uid => 'user-1';
  @override
  String? get email => 'ashen@example.com';
  @override
  String? get displayName => 'Ashen Perera';
  @override
  String? get photoURL => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Gateway implements AuthGateway {
  _Gateway({this.signedIn = true});
  final bool signedIn;

  @override
  User? get currentUser => signedIn ? _FakeUser() : null;
  @override
  Stream<User?> get userChanges =>
      Stream<User?>.value(signedIn ? _FakeUser() : null);
  @override
  Future<String?> getIdToken([bool forceRefresh = false]) async => null;
  @override
  Future<void> sendPasswordResetEmail(String email) async {}
  @override
  Future<void> signIn(String email, String password) async {}
  @override
  Future<void> signUp(String email, String password) async {}
  @override
  Future<void> signOut() async {}
  @override
  bool get isEmailVerified => true;
  @override
  Future<void> sendEmailVerification() async {}
  @override
  Future<bool> reloadEmailVerified() async => true;
}

String _day(int back) {
  final now = DateTime.now();
  var d = now.subtract(Duration(days: back));
  if (d.month != now.month) d = DateTime(now.year, now.month, 1);
  String two(int v) => v.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)}';
}

class _DemoApi extends FakeServerApi {
  static const _cats = [
    (1, 'Food & Dining', 'EXPENSE', '#FF5757'),
    (2, 'Transport', 'EXPENSE', '#4A90E2'),
    (3, 'Rent', 'EXPENSE', '#2ECC71'),
    (4, 'Utilities', 'EXPENSE', '#F39C12'),
    (5, 'Shopping', 'EXPENSE', '#BA68C8'),
    (9, 'Salary', 'INCOME', '#2CB8A0'),
    (10, 'Freelance', 'INCOME', '#6C8CFF'),
  ];

  List<Map<String, dynamic>> get _txns => [
        for (final t in [
          (101, 185000.0, 'INCOME', 9, 'Salary', 'BANK_TRANSFER', 'Monthly salary', 14),
          (102, 25000.0, 'INCOME', 10, 'Freelance', 'BANK_TRANSFER', 'Logo project', 9),
          (103, 45000.0, 'EXPENSE', 3, 'Rent', 'BANK_TRANSFER', 'Apartment rent', 13),
          (104, 8450.5, 'EXPENSE', 1, 'Food & Dining', 'CASH', 'Weekly groceries', 7),
          (105, 1250.0, 'EXPENSE', 2, 'Transport', 'CASH', 'Fuel', 6),
          (106, 6320.75, 'EXPENSE', 4, 'Utilities', 'BANK_TRANSFER', 'Electricity bill', 5),
          (107, 14990.0, 'EXPENSE', 5, 'Shopping', 'BANK_TRANSFER', 'Running shoes', 4),
          (108, 1890.0, 'EXPENSE', 1, 'Food & Dining', 'CASH', 'Dinner with friends', 3),
          (109, 640.0, 'EXPENSE', 2, 'Transport', 'CASH', 'Ride share', 2),
          (110, 3100.0, 'EXPENSE', 1, 'Food & Dining', 'CASH', 'Lunch & coffee', 1),
          (111, 2300.0, 'EXPENSE', 1, 'Food & Dining', 'CASH', 'Takeaway', 0),
        ])
          {
            'id': t.$1,
            'amount': t.$2,
            'type': t.$3,
            'categoryId': t.$4,
            'categoryName': t.$5,
            'transactionDate': _day(t.$8),
            'paymentMethod': t.$6,
            'note': t.$7,
            'createdAt': '2026-01-01T00:00:00',
          }
      ];

  Map<String, dynamic> get _summary => {
        'totalIncome': 210000.0,
        'totalExpenses': 112450.75,
        'netCashFlow': 97549.25,
        'previousMonthExpenses': 98000.0,
        'savingsRatePercentage': 20.0,
        'monthlyReservedSavings': 42000.0,
        'cumulativeSavings': 214000.0,
        'scheduledPaymentsTotal': 18500.0,
        'spendableAllowance': 35050.0,
        'totalAllocatedCategoryBudgets': 90000.0,
        'unallocatedAllowance': 0.0,
        'cashIncome': 0.0,
        'bankTransferIncome': 210000.0,
        'cashSpendable': 0.0,
        'bankTransferSpendable': 35050.0,
        'cashExpenses': 17630.5,
        'bankTransferExpenses': 94820.25,
        'categoryBudgets': [
          {'categoryId': 1, 'categoryName': 'Food & Dining', 'budgetLimit': 20000.0, 'currentSpend': 15690.5, 'alertState': 'NEARING', 'transactionCount': 4},
          {'categoryId': 2, 'categoryName': 'Transport', 'budgetLimit': 5000.0, 'currentSpend': 1890.0, 'alertState': 'NORMAL', 'transactionCount': 2},
          {'categoryId': 4, 'categoryName': 'Utilities', 'budgetLimit': 6000.0, 'currentSpend': 6320.75, 'alertState': 'EXCEEDED', 'transactionCount': 1},
          {'categoryId': 5, 'categoryName': 'Shopping', 'budgetLimit': 25000.0, 'currentSpend': 14990.0, 'alertState': 'NORMAL', 'transactionCount': 1},
        ],
      };

  @override
  Future<http.Response> get(String path, {Map<String, String>? queryParams}) async {
    http.Response ok(Object body) => http.Response(jsonEncode(body), 200);
    if (path.startsWith('/debts?') || path == '/debts') {
      final d = DateTime.now();
      return ok([
        {
          'id': 1, 'type': 'BORROWED', 'counterpartyName': 'Nimal Perera', 'principalAmount': 50000.0,
          'totalAmountDue': 55000.0, 'amountRepaid': 20000.0, 'remainingAmount': 35000.0,
          'startDate': _day(30), 'dueDate': d.add(const Duration(days: 12)).toIso8601String().substring(0, 10),
          'status': 'ACTIVE', 'repayments': [], 'createdAt': '2026-01-01T00:00:00', 'updatedAt': '2026-01-01T00:00:00',
        },
        {
          'id': 2, 'type': 'LENT', 'counterpartyName': 'Kamal Silva', 'principalAmount': 15000.0,
          'totalAmountDue': 15000.0, 'amountRepaid': 0.0, 'remainingAmount': 15000.0,
          'startDate': _day(10), 'dueDate': d.subtract(const Duration(days: 3)).toIso8601String().substring(0, 10),
          'status': 'OVERDUE', 'repayments': [], 'createdAt': '2026-01-01T00:00:00', 'updatedAt': '2026-01-01T00:00:00',
        },
      ]);
    }
    switch (path) {
      case '/me':
        return ok({
          'id': 1, 'firebaseUid': 'user-1', 'email': 'ashen@example.com',
          'onboardingStatus': 'COMPLETED', 'savingsRatePercentage': 20,
        });
      case '/categories':
        return ok([
          for (final c in _cats)
            {'id': c.$1, 'name': c.$2, 'type': c.$3, 'colorKey': c.$4, 'isArchived': false, 'isSystemDefault': true}
        ]);
      case '/transactions':
        return ok({'content': _txns, 'last': true});
      case '/budgets/summary':
      case '/budgets/dashboard-summary':
        return ok(_summary);
      case '/debts/summary':
        return ok({
          'totalLent': 15000.0, 'totalBorrowed': 35000.0, 'netDebtPosition': -20000.0,
          'activeLentCount': 1, 'activeBorrowedCount': 1, 'overdueCount': 1,
        });
      case '/scheduled-transactions':
        final d = DateTime.now();
        String due(int n) => d.add(Duration(days: n)).toIso8601String().substring(0, 10);
        return ok([
          {'id': 1, 'categoryId': 3, 'categoryName': 'Rent', 'type': 'EXPENSE', 'title': 'Apartment rent', 'amount': 45000.0,
           'dueDate': due(4), 'paymentMethod': 'BANK_TRANSFER', 'recurringFrequency': 'MONTHLY', 'status': 'PENDING', 'reminderDaysBefore': 3},
          {'id': 2, 'categoryId': 4, 'categoryName': 'Utilities', 'type': 'EXPENSE', 'title': 'Internet', 'amount': 4500.0,
           'dueDate': due(-1), 'paymentMethod': 'BANK_TRANSFER', 'recurringFrequency': 'MONTHLY', 'status': 'PENDING', 'reminderDaysBefore': 3},
          {'id': 3, 'categoryId': 5, 'categoryName': 'Shopping', 'type': 'EXPENSE', 'title': 'Gym membership', 'amount': 14000.0,
           'dueDate': due(18), 'paymentMethod': 'CASH', 'recurringFrequency': 'MONTHLY', 'status': 'PENDING', 'reminderDaysBefore': 3},
        ]);
      case '/notifications/unread-count':
        return ok({'count': 3});
      case '/lifetime/stats':
        return ok({'totalEarned': 2460000.0, 'totalSpent': 1580000.0, 'totalSaved': 214000.0, 'netWorth': 880000.0, 'activeMonths': 14});
      case '/lifetime/achievements':
        return ok([
          {'id': 'a1', 'title': 'First Step', 'description': 'Log your first transaction', 'iconKey': 'star', 'unlocked': true},
          {'id': 'a2', 'title': 'Saver', 'description': 'Save for 3 months in a row', 'iconKey': 'savings', 'unlocked': true},
          {'id': 'a3', 'title': 'Budget Master', 'description': 'Stay under budget for a month', 'iconKey': 'trophy', 'unlocked': false},
        ]);
    }
    return http.Response('[]', 200);
  }
}

final _boundaryKey = GlobalKey();

Future<void> _pumpFor(WidgetTester tester, [int ms = 1500]) async {
  for (var i = 0; i < ms ~/ 100; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _shoot(WidgetTester tester, String name) async {
  await _pumpFor(tester, 600);
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(_boundaryKey));
    final image = await boundary.toImage(pixelRatio: 1.6);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('build/screens/$name.png')..createSync(recursive: true);
    file.writeAsBytesSync(data!.buffer.asUint8List());
  });
}

Future<void> _mount(WidgetTester tester, Widget home, ThemeMode mode,
    {bool signedIn = true, double textScale = 1.0}) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);

  final gateway = _Gateway(signedIn: signedIn);
  final api = _DemoApi();
  await tester.pumpWidget(
    RepaintBoundary(
      key: _boundaryKey,
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => SecurityProvider()),
          ChangeNotifierProvider(create: (_) => AuthProvider(gateway, api)),
          ChangeNotifierProvider(create: (_) => TransactionProvider(api)),
          ChangeNotifierProvider(create: (_) => BudgetProvider(api)),
          ChangeNotifierProvider(create: (_) => NotificationProvider(api)),
          ChangeNotifierProvider(create: (_) => ScheduledTransactionProvider(api)),
          ChangeNotifierProvider(create: (_) => DebtProvider(api)),
          ChangeNotifierProvider(create: (_) => LifetimeProvider(api)),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: mode,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: home,
        ),
      ),
    ),
  );
  await _pumpFor(tester, 1500);
}

Future<void> _loadFonts() async {
  Future<ByteData> bytes(String path) async {
    final b = await File(path).readAsBytes();
    return ByteData.view(b.buffer);
  }

  final manrope = FontLoader('Manrope');
  for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
    manrope.addFont(bytes('assets/fonts/Manrope-$w.ttf'));
  }
  await manrope.load();

  final root = Platform.environment['FLUTTER_ROOT'] ?? r'C:\Users\Ashen\AppData\Local\flutter';
  final icons = FontLoader('MaterialIcons')
    ..addFont(bytes('$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf'));
  await icons.load();
}

void main() {
  setUpAll(() async {
    if (!_enabled) return;
    await _loadFonts();
    // The home screen reads FirebaseMessaging.instance when it is created.
    TestWidgetsFlutterBinding.ensureInitialized();
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({'has_seen_tutorial_user-1': true});
    installFakeSecureStorage();
  });

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    final t = mode.name;

    testWidgets('$t: home tabs', (tester) async {
      await _mount(tester, const HomeNavigationScaffold(), mode);
      await _shoot(tester, '$t-1-dashboard');
      for (final (i, label) in [(2, 'Transactions'), (3, 'Budgets'), (4, 'Analytics'), (5, 'Lifetime')]) {
        await tester.tap(find.text(label).last);
        await _pumpFor(tester, 1200);
        await _shoot(tester, '$t-$i-${label.toLowerCase()}');
      }
    }, skip: !_enabled);

    testWidgets('$t: secondary screens', (tester) async {
      await _mount(tester, const ProfileView(), mode);
      await _shoot(tester, '$t-6-profile');
      await _mount(tester, const DebtManagementView(), mode);
      await _shoot(tester, '$t-7-debts');
      await _mount(tester, const ScheduledTransactionsScreen(), mode);
      await _shoot(tester, '$t-8-scheduled');
    }, skip: !_enabled);

    testWidgets('$t: entry screens', (tester) async {
      await _mount(tester, const AuthView(), mode, signedIn: false);
      await _shoot(tester, '$t-9-auth');
      await _mount(tester, const OnboardingView(), mode);
      await _shoot(tester, '$t-10-onboarding');
    }, skip: !_enabled);
  }
}
