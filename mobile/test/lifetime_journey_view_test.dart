import 'dart:convert';

import 'package:aureli/providers/lifetime_provider.dart';
import 'package:aureli/services/api_service.dart';
import 'package:aureli/views/lifetime/lifetime_journey_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

/// Serves queued responses per path; the last queued response repeats.
class FakeLifetimeApi implements ApiService {
  FakeLifetimeApi(this._responses);

  final Map<String, List<http.Response>> _responses;
  final List<String> calls = [];

  @override
  String? get currentUserId => null;

  @override
  Future<http.Response> get(String path, {Map<String, String>? queryParams}) async {
    calls.add(path);
    final queue = _responses[path]!;
    return queue.length > 1 ? queue.removeAt(0) : queue.first;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _okStats = http.Response(
  jsonEncode({
    'totalEarned': 100000,
    'totalSpent': 2500,
    'totalSaved': 20000,
    'netWorth': 97500,
    'activeMonths': 12,
  }),
  200,
);

void main() {
  testWidgets('Lifetime tab offers a retry after a failed load and recovers', (tester) async {
    final api = FakeLifetimeApi({
      '/lifetime/stats': [http.Response('{"message":"unavailable"}', 503), _okStats],
      '/lifetime/achievements': [http.Response('[]', 200)],
    });

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => LifetimeProvider(api),
        child: const MaterialApp(home: LifetimeJourneyView()),
      ),
    );
    await tester.pumpAndSettle();

    // The failed load must leave a way to try again instead of a dead error screen.
    expect(find.text('Retry'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.textContaining('100,000'), findsOneWidget);
    expect(api.calls.where((c) => c == '/lifetime/stats').length, 2);
  });
}
