import 'dart:convert';

import 'package:aureli/providers/budget_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fake_server_api.dart';

/// Serves one budget summary, slowly enough for two screens to ask for it at once.
class _SlowSummaryApi extends FakeServerApi {
  int summaryCalls = 0;

  @override
  Future<http.Response> get(String path, {Map<String, String>? queryParams}) async {
    if (path != '/budgets/summary') return super.get(path, queryParams: queryParams);
    summaryCalls++;
    await Future<void>.delayed(const Duration(milliseconds: 20));
    return http.Response(
      jsonEncode({
        'totalIncome': 1000.0,
        'totalExpenses': 400.0,
        'netCashFlow': 600.0,
        'previousMonthExpenses': 0.0,
        'categoryBudgets': [
          {
            'categoryId': 1,
            'categoryName': 'Food',
            'budgetLimit': 500.0,
            'currentSpend': 400.0,
            'alertState': 'NORMAL',
            'transactionCount': 2,
          },
        ],
      }),
      200,
    );
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    installFakeSecureStorage();
  });

  // Every tab of the home screen is built at launch, and the dashboard, budgets and
  // analytics screens each ask for the month's summary the moment they appear.
  test('a screen that asks while another request is in flight still gets the data',
      () async {
    final api = _SlowSummaryApi();
    final budgets = BudgetProvider(api);
    await settle();

    final fromDashboard = budgets.fetchDashboardSummary();
    final fromBudgetsScreen = budgets.fetchSummary();
    await Future.wait([fromDashboard, fromBudgetsScreen]);

    expect(budgets.dashboardSummary, isNotNull, reason: 'dashboard');
    expect(budgets.summary, isNotNull, reason: 'budgets and analytics screens');
    expect(budgets.summary!.categoryBudgets.single.totalSpent, 400.0);
  });

  test('one request serves both, rather than two racing', () async {
    final api = _SlowSummaryApi();
    final budgets = BudgetProvider(api);
    await settle();

    await Future.wait([budgets.fetchDashboardSummary(), budgets.fetchSummary()]);

    expect(api.summaryCalls, 1);
  });

  test('changing month still refreshes both views', () async {
    final api = _SlowSummaryApi();
    final budgets = BudgetProvider(api);
    await settle();
    await budgets.fetchSummary();

    budgets.changeMonth(DateTime.now().year, DateTime.now().month, dashboardOnly: true);
    await settle(80);

    expect(budgets.dashboardSummary, isNotNull);
    expect(budgets.summary, isNotNull);
  });
}
