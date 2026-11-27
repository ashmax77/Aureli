import 'package:aureli/models/category_model.dart';
import 'package:aureli/models/transaction_model.dart';
import 'package:aureli/providers/transaction_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'helpers/fake_server_api.dart';

/// Server that saves the transaction, then misbehaves when the list is re-read.
class _FlakyListApi extends FakeServerApi {
  Object? listError;
  http.Response? listResponse;

  @override
  Future<http.Response> get(String path, {Map<String, String>? queryParams}) async {
    if (path == '/transactions') {
      if (listError != null) throw listError!;
      if (listResponse != null) return listResponse!;
    }
    return super.get(path, queryParams: queryParams);
  }
}

/// A provider whose list refresh blows up outright, whatever the reason.
class _ThrowingRefreshProvider extends TransactionProvider {
  _ThrowingRefreshProvider(super.api, {super.onFinancialDataChanged});

  @override
  Future<void> fetchTransactions({bool refresh = false}) async =>
      throw StateError('refresh exploded');
}

Future<TransactionCreateResult> _create(TransactionProvider p) => p.createTransaction(
      type: TransactionType.EXPENSE,
      categoryId: 1,
      amount: 40,
      date: DateTime.now(),
      paymentMethod: PaymentMethod.CASH,
      note: 'lunch',
    );

void main() {
  setUp(installFakeSecureStorage);

  group('a transaction the server saved stays a success if refreshing the list fails', () {
    test('refresh answered with a server error', () async {
      final api = _FlakyListApi();
      var changed = 0;
      final p = TransactionProvider(api, onFinancialDataChanged: () => changed++);
      await settle();
      api.listResponse = http.Response('{"message":"boom"}', 500);

      expect(await _create(p), TransactionCreateResult.success);

      expect(api.serverTransactions, hasLength(1));
      expect(changed, 1, reason: 'summaries must still be refreshed');
    });

    test('refresh request throws', () async {
      final api = _FlakyListApi();
      var changed = 0;
      final p = TransactionProvider(api, onFinancialDataChanged: () => changed++);
      await settle();
      api.listError = Exception('socket closed');

      expect(await _create(p), TransactionCreateResult.success);

      expect(changed, 1);
    });

    test('refresh itself throws', () async {
      final api = FakeServerApi();
      var changed = 0;
      final p = _ThrowingRefreshProvider(api, onFinancialDataChanged: () => changed++);
      await settle();

      expect(await _create(p), TransactionCreateResult.success);

      expect(api.serverTransactions, hasLength(1));
      expect(changed, 1, reason: 'summaries must still be refreshed');
      expect(p.errorMessage, isNull, reason: 'a saved transaction is not an error');
      expect(p.isActionLoading, isFalse);
    });

    test('a failing summary callback does not turn a saved transaction into an error', () async {
      final api = FakeServerApi();
      final p = TransactionProvider(api, onFinancialDataChanged: () => throw StateError('x'));
      await settle();

      expect(await _create(p), TransactionCreateResult.success);
      expect(p.errorMessage, isNull);
    });
  });
}
