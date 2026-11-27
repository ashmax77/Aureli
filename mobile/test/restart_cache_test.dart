import 'dart:convert';
import 'dart:io';

import 'package:aureli/providers/budget_provider.dart';
import 'package:aureli/providers/lifetime_provider.dart';
import 'package:aureli/providers/notification_provider.dart';
import 'package:aureli/services/api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'helpers/fake_server_api.dart';

/// A server that can be switched off. "Restarting the app" is a brand-new provider built
/// over the same persisted storage.
class _Api implements ApiService {
  bool online = true;

  /// The request itself throws (as a broken connection can) instead of answering 503.
  bool throwing = false;

  @override
  String? get currentUserId => 'user-1';

  http.Response _ok(Object body) => http.Response(jsonEncode(body), 200);

  @override
  Future<http.Response> get(String path, {Map<String, String>? queryParams}) async {
    if (throwing) throw const SocketException('connection lost');
    if (!online) return http.Response('{"isOffline": true}', 503);

    if (path == '/budgets/summary') {
      return _ok({
        'totalBudget': 1000,
        'cashIncome': 500,
        'cashSpendable': 400,
        'bankTransferIncome': 700,
        'bankTransferSpendable': 600,
      });
    }
    if (path.startsWith('/lifetime/stats')) {
      return _ok({
        'totalEarned': path.contains('year=2025') ? 2025 : 1,
        'totalSpent': 2,
        'totalSaved': 3,
        'netWorth': 4,
        'activeMonths': 5,
      });
    }
    if (path == '/lifetime/achievements') {
      return _ok([
        {'id': 'first', 'title': 'First step', 'description': 'd', 'iconKey': 'k', 'unlocked': true},
      ]);
    }
    if (path == '/notifications') {
      return _ok({
        'content': [
          {
            'id': 1,
            'title': 'Budget alert',
            'body': 'You are close to your limit',
            'read': false,
            'createdAt': '2026-11-27T01:00:00Z',
          },
        ],
        'last': true,
      });
    }
    if (path == '/notifications/unread-count') return _ok({'count': 3});
    return _ok([]);
  }

  @override
  Future<http.Response> post(String path, Map<String, dynamic> body) async {
    if (!online) return http.Response('{"isOffline": true}', 503);
    return _ok({});
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUp(installFakeSecureStorage);

  group('dashboard budget summary', () {
    test('is still there after a restart with no network, including cash and bank amounts',
        () async {
      final api = _Api();
      await BudgetProvider(api).fetchDashboardSummary();

      api.online = false;
      final restarted = BudgetProvider(api);
      await settle(100);

      expect(restarted.dashboardSummary, isNotNull);
      expect(restarted.dashboardSummary!.cashSpendable, 400);
      expect(restarted.dashboardSummary!.bankTransferSpendable, 600);

      // The dashboard's refresh then fails; it keeps the saved copy and shows no error.
      await restarted.fetchDashboardSummary(force: true);
      expect(restarted.dashboardSummary!.cashSpendable, 400);
      expect(restarted.errorMessage, isNull);
    });

    test('the budgets screen sees the same saved copy', () async {
      final api = _Api();
      await BudgetProvider(api).fetchDashboardSummary();

      api.online = false;
      final restarted = BudgetProvider(api);
      await settle(100);

      expect(restarted.summary, isNotNull);
      expect(restarted.summary!.cashSpendable, 400);
    });
  });

  group('lifetime stats', () {
    test('stats and achievements survive a restart with no network', () async {
      final api = _Api();
      await LifetimeProvider(api).fetchLifetimeData();

      api.online = false;
      final restarted = LifetimeProvider(api);
      await settle(100);

      expect(restarted.stats?.totalEarned, 1);
      expect(restarted.achievements.map((a) => a.id), ['first']);
    });

    test('a year view offline shows that year\'s saved numbers, not another year\'s', () async {
      final api = _Api();
      final online = LifetimeProvider(api);
      await online.fetchLifetimeData();
      await online.fetchLifetimeData(year: 2025);
      expect(online.stats?.totalEarned, 2025);

      api.online = false;
      final restarted = LifetimeProvider(api);
      await settle(100);
      expect(restarted.stats?.totalEarned, 1, reason: 'starts on the all-time view');

      await restarted.fetchLifetimeData(year: 2025);
      expect(restarted.stats?.totalEarned, 2025);
      expect(restarted.errorMessage, isNotNull, reason: 'the user is still told it is offline');

      await restarted.fetchLifetimeData();
      expect(restarted.stats?.totalEarned, 1);
    });
  });

  test('lifetime: a request that throws also falls back to the saved stats', () async {
    final api = _Api();
    await LifetimeProvider(api).fetchLifetimeData(year: 2025);

    api.throwing = true;
    final restarted = LifetimeProvider(api);
    await restarted.fetchLifetimeData(year: 2025);

    expect(restarted.stats?.totalEarned, 2025);
    expect(restarted.errorMessage, isNotNull);
  });

  group('notifications', () {
    test('the list and unread count survive a restart with no network', () async {
      final api = _Api();
      final online = NotificationProvider(api);
      await online.fetchNotifications();
      await online.fetchUnreadCount();

      api.online = false;
      final restarted = NotificationProvider(api);
      await settle(100);

      expect(restarted.notifications.single.title, 'Budget alert');
      expect(restarted.notifications.single.isRead, isFalse);
      expect(restarted.notifications.single.createdAt.toUtc(), DateTime.utc(2026, 11, 27, 1));
      expect(restarted.unreadCount, 3);
    });

    test('a list restored from the snapshot is replaced, not extended, by the next refresh',
        () async {
      final api = _Api();
      await NotificationProvider(api).fetchNotifications();

      api.online = false;
      final restarted = NotificationProvider(api);
      await settle(100);
      expect(restarted.hasMore, isFalse, reason: 'load-more must not re-append page 0');

      api.online = true;
      await restarted.fetchNotifications();
      expect(restarted.notifications, hasLength(1));
    });

    test('marking everything read is remembered after a restart', () async {
      final api = _Api();
      final online = NotificationProvider(api);
      await online.fetchNotifications();
      await online.fetchUnreadCount();
      await online.markAllAsRead();

      api.online = false;
      final restarted = NotificationProvider(api);
      await settle(100);

      expect(restarted.unreadCount, 0);
      expect(restarted.notifications.single.isRead, isTrue);
    });
  });
}
