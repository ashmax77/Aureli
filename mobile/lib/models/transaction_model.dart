import 'category_model.dart';

enum PaymentMethod { CARD, BANK_TRANSFER }

class TransactionModel {
  final int id;
  final double amount;
  final TransactionType type;
  final CategoryModel category;
  final DateTime transactionDate;
  final PaymentMethod paymentMethod;
  final String? note;

  TransactionModel({
    required this.id,
    required this.amount,
    required this.type,
    required this.category,
    required this.transactionDate,
    required this.paymentMethod,
    this.note,
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    PaymentMethod method;
    switch (json['paymentMethod'] as String?) {
      case 'BANK_TRANSFER':
        method = PaymentMethod.BANK_TRANSFER;
        break;
      case 'CARD':
      case 'CASH':
      default:
        method = PaymentMethod.CARD;
        break;
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
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'amount': amount,
      'type': type.toString().split('.').last,
      'category': category.toJson(),
      'transactionDate': "${transactionDate.year.toString().padLeft(4, '0')}-${transactionDate.month.toString().padLeft(2, '0')}-${transactionDate.day.toString().padLeft(2, '0')}",
      'paymentMethod': paymentMethod.toString().split('.').last,
      'note': note,
    };
  }
}
