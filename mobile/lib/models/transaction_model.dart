import 'category_model.dart';

enum PaymentMethod { CASH, BANK_TRANSFER }

class TransactionModel {
  final int id;
  final double amount;
  final TransactionType type;
  final CategoryModel category;
  final DateTime transactionDate;
  final PaymentMethod paymentMethod;
  final String? note;
  final bool? isSavingsEnabled;
  final double? savingsRate;
  final double? savingsAmount;
  final DateTime? createdAt;

  TransactionModel({
    required this.id,
    required this.amount,
    required this.type,
    required this.category,
    required this.transactionDate,
    required this.paymentMethod,
    this.note,
    this.isSavingsEnabled,
    this.savingsRate,
    this.savingsAmount,
    this.createdAt,
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    PaymentMethod method;
    final pmStr = (json['paymentMethod'] as String?)?.toUpperCase();
    if (pmStr == 'BANK_TRANSFER') {
      method = PaymentMethod.BANK_TRANSFER;
    } else {
      method = PaymentMethod.CASH;
    }

    DateTime? parseUtcToLocal(String? dateStr) {
      if (dateStr == null) return null;
      final normalizedStr = dateStr.endsWith('Z') ? dateStr : '${dateStr}Z';
      return DateTime.tryParse(normalizedStr)?.toLocal();
    }

    return TransactionModel(
      id: json['id'] as int,
      amount: (json['amount'] as num).toDouble(),
      type: json['type'] == 'INCOME' ? TransactionType.INCOME : TransactionType.EXPENSE,
      category: CategoryModel(
        id: json['categoryId'] as int,
        name: json['categoryName'] as String? ?? '',
        type: json['type'] == 'INCOME' ? TransactionType.INCOME : TransactionType.EXPENSE,
      ),
      transactionDate: DateTime.parse(json['transactionDate'] as String),
      paymentMethod: method,
      note: json['note'] as String?,
      isSavingsEnabled: json['isSavingsEnabled'] as bool?,
      savingsRate: (json['savingsRate'] as num?)?.toDouble(),
      savingsAmount: (json['savingsAmount'] as num?)?.toDouble(),
      createdAt: parseUtcToLocal(json['createdAt'] as String?),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'amount': amount,
      'type': type.toString().split('.').last,
      'categoryId': category.id,
      'categoryName': category.name,
      'transactionDate': "${transactionDate.year.toString().padLeft(4, '0')}-${transactionDate.month.toString().padLeft(2, '0')}-${transactionDate.day.toString().padLeft(2, '0')}",
      'paymentMethod': paymentMethod.toString().split('.').last,
      'note': note,
      'isSavingsEnabled': isSavingsEnabled,
      'savingsRate': savingsRate,
      'savingsAmount': savingsAmount,
      'createdAt': createdAt?.toIso8601String(),
    };
  }
}
