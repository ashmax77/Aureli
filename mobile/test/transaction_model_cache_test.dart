import 'dart:convert';

import 'package:aureli/models/transaction_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> serverJson() => {
        'id': 1,
        'amount': 10.5,
        'type': 'EXPENSE',
        'categoryId': 2,
        'categoryName': 'Food',
        'transactionDate': '2026-11-25',
        'paymentMethod': 'BANK_TRANSFER',
        'createdAt': '2026-11-25T10:00:00', // backend sends naive UTC
      };

  test('createdAt survives a snapshot-cache round trip without shifting', () {
    final fromNetwork = TransactionModel.fromJson(serverJson());
    final cached = jsonDecode(jsonEncode(fromNetwork.toJson())) as Map<String, dynamic>;
    final fromCache = TransactionModel.fromJson(cached);

    expect(fromCache.createdAt, fromNetwork.createdAt);
    // A second pass must stay stable too (the bug compounded on every cycle).
    final again = TransactionModel.fromJson(
        jsonDecode(jsonEncode(fromCache.toJson())) as Map<String, dynamic>);
    expect(again.createdAt, fromNetwork.createdAt);
  });

  test('naive server createdAt is interpreted as UTC', () {
    final model = TransactionModel.fromJson(serverJson());
    expect(model.createdAt!.toUtc(), DateTime.utc(2026, 11, 25, 10));
  });

  test('other fields round trip', () {
    final model = TransactionModel.fromJson(serverJson());
    final copy = TransactionModel.fromJson(
        jsonDecode(jsonEncode(model.toJson())) as Map<String, dynamic>);
    expect(copy.amount, 10.5);
    expect(copy.paymentMethod, PaymentMethod.BANK_TRANSFER);
    expect(copy.transactionDate, DateTime(2026, 11, 25));
    expect(copy.category.name, 'Food');
  });
}
