import 'dart:async';
import 'dart:convert';

import 'package:aureli/models/category_model.dart';
import 'package:aureli/models/transaction_model.dart';
import 'package:aureli/providers/transaction_provider.dart';
import 'package:aureli/services/api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

class FakeApi implements ApiService {
  final List<Map<String, String>> getCalls = [];
  final List<Completer<http.Response>> pending = [];

  @override
  String? get currentUserId => null;

  @override
  Future<http.Response> get(String path, {Map<String, String>? queryParams}) {
    getCalls.add({'path': path, ...?queryParams});
    final completer = Completer<http.Response>();
    pending.add(completer);
    return completer.future;
  }

  @override
  Future<http.Response> post(String path, Map<String, dynamic> body) async =>
      http.Response('{}', 201);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

http.Response page(String note, {bool last = true}) => http.Response(
      jsonEncode({
        'content': [
          {
            'id': 1,
            'amount': 1,
            'type': 'EXPENSE',
            'categoryId': 1,
            'categoryName': 'C',
            'transactionDate': '2026-11-05',
            'paymentMethod': 'CASH',
            'note': note,
          }
        ],
        'last': last,
      }),
      200,
    );

void main() {
  test('changing month during a load shows the newly selected month', () async {
    final api = FakeApi();
    final provider = TransactionProvider(api);

    final firstFetch = provider.fetchTransactions(refresh: true);
    provider.changeMonth(2026, 10);
    expect(api.getCalls.length, 2, reason: 'month change must issue its own request');
    expect(api.getCalls.last['startDate'], '2026-10-01');

    // The superseded request resolves first and must be ignored.
    api.pending[0].complete(page('stale'));
    await firstFetch;
    expect(provider.transactions, isEmpty);

    api.pending[1].complete(page('october'));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(provider.transactions.map((t) => t.note), ['october']);
    expect(provider.isLoading, isFalse);
  });

  test('stale response arriving after the newer one does not overwrite it', () async {
    final api = FakeApi();
    final provider = TransactionProvider(api);

    final firstFetch = provider.fetchTransactions(refresh: true);
    provider.changeMonth(2026, 10);

    api.pending[1].complete(page('october'));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    api.pending[0].complete(page('stale'));
    await firstFetch;

    expect(provider.transactions.map((t) => t.note), ['october']);
    expect(provider.isLoading, isFalse);
  });

  test('refresh after a successful create is not dropped by an in-flight fetch', () async {
    final api = FakeApi();
    final provider = TransactionProvider(api);

    final inFlight = provider.fetchTransactions(refresh: true);
    final create = provider.createTransaction(
      type: TransactionType.EXPENSE,
      categoryId: 1,
      amount: 5,
      date: DateTime(2026, 11, 5),
      paymentMethod: PaymentMethod.CASH,
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(api.getCalls.length, 2, reason: 'create must trigger a fresh list request');

    api.pending[0].complete(page('without-new-tx'));
    await inFlight;
    api.pending[1].complete(page('with-new-tx'));
    expect(await create, TransactionCreateResult.success);
    expect(provider.transactions.map((t) => t.note), ['with-new-tx']);
  });

  test('pagination requests are still ignored while a load is running', () async {
    final api = FakeApi();
    final provider = TransactionProvider(api);

    final first = provider.fetchTransactions(refresh: true);
    await provider.fetchTransactions(); // load more while loading
    expect(api.getCalls.length, 1);

    api.pending[0].complete(page('one'));
    await first;
    expect(provider.transactions.length, 1);
  });
}
