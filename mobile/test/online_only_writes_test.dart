import 'dart:convert';

import 'package:aureli/models/debt_model.dart';
import 'package:aureli/models/transaction_model.dart';
import 'package:aureli/providers/debt_provider.dart';
import 'package:aureli/providers/scheduled_transaction_provider.dart';
import 'package:aureli/services/api_service.dart';
import 'package:aureli/services/network_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'helpers/fake_server_api.dart';

/// Answers every write with a fixed response.
class _FixedApi implements ApiService {
  _FixedApi(this.response);
  final http.Response response;

  @override
  String? get currentUserId => null;

  @override
  Future<http.Response> post(String path, Map<String, dynamic> body) async => response;

  @override
  Future<http.Response> delete(String path) async => response;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _offline = http.Response(
  jsonEncode({'error': 'Network connection unreachable.', 'isOffline': true}),
  503,
);
final _timeout = http.Response(
  jsonEncode({'error': 'Connection timed out.', 'isTimeout': true}),
  504,
);
final _serverRejects = http.Response(jsonEncode({'message': 'Principal must be positive'}), 400);
final _serverCrash = http.Response('Internal Server Error', 500);

Future<bool> _createDebt(DebtProvider p) => p.createDebt(
      type: DebtType.BORROWED,
      counterpartyName: 'Sam',
      principalAmount: 100,
      startDate: DateTime(2026, 1, 1),
    );

void main() {
  setUp(installFakeSecureStorage);

  group('isConnectivityFailure / connectivityFailureMessage', () {
    test('recognise offline and timeout responses only', () {
      expect(isConnectivityFailure(_offline), isTrue);
      expect(isConnectivityFailure(_timeout), isTrue);
      expect(connectivityFailureMessage(_offline), offlineWriteMessage);
      expect(connectivityFailureMessage(_timeout), timeoutWriteMessage);

      expect(isConnectivityFailure(_serverCrash), isFalse, reason: 'plain 500 is a server bug');
      expect(isConnectivityFailure(_serverRejects), isFalse);
      expect(connectivityFailureMessage(_serverCrash), isNull);
      // A 4xx never counts, even if a body happened to carry the flag.
      expect(isConnectivityFailure(http.Response('{"isOffline":true}', 400)), isFalse);
    });
  });

  group('DebtProvider writes', () {
    test('explain that the app is offline instead of a generic failure', () async {
      final p = DebtProvider(_FixedApi(_offline));
      expect(await _createDebt(p), isFalse);
      expect(p.errorMessage, offlineWriteMessage);

      expect(
        await p.recordRepayment(
          debtId: 1,
          amount: 10,
          repaymentDate: DateTime(2026, 1, 2),
          paymentMethod: PaymentMethod.CASH,
        ),
        isFalse,
      );
      expect(p.errorMessage, offlineWriteMessage);

      expect(await p.deleteDebt(1), isFalse);
      expect(p.errorMessage, offlineWriteMessage);
    });

    test('explain a timeout', () async {
      final p = DebtProvider(_FixedApi(_timeout));
      expect(await _createDebt(p), isFalse);
      expect(p.errorMessage, timeoutWriteMessage);
    });

    test('still surface the server\'s own validation message', () async {
      final p = DebtProvider(_FixedApi(_serverRejects));
      expect(await _createDebt(p), isFalse);
      expect(p.errorMessage, 'Principal must be positive');
    });
  });

  group('ScheduledTransactionProvider writes', () {
    Future<bool> create(ScheduledTransactionProvider p) => p.createScheduledTransaction(
          categoryId: 1,
          title: 'Rent',
          amount: 50,
          dueDate: DateTime(2026, 2, 1),
          paymentMethod: 'CASH',
        );

    test('create / pay / delete all explain being offline', () async {
      final p = ScheduledTransactionProvider(_FixedApi(_offline));

      expect(await create(p), isFalse);
      expect(p.errorMessage, offlineWriteMessage);

      expect(await p.payScheduledTransaction(1), isFalse);
      expect(p.errorMessage, offlineWriteMessage);

      expect(await p.deleteScheduledTransaction(1), isFalse);
      expect(p.errorMessage, offlineWriteMessage);
    });

    test('pay / delete report a server failure instead of failing silently', () async {
      final p = ScheduledTransactionProvider(_FixedApi(_serverCrash));

      expect(await p.payScheduledTransaction(1), isFalse);
      expect(p.errorMessage, contains('500'));

      expect(await p.deleteScheduledTransaction(1), isFalse);
      expect(p.errorMessage, contains('500'));
    });
  });
}
