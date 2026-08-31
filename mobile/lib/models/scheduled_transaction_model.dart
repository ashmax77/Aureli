import 'transaction_model.dart';

enum ScheduledFrequency { ONCE, DAILY, WEEKLY, MONTHLY, YEARLY }

enum ScheduledStatus { PENDING, PAID, CANCELLED }

class ScheduledTransactionModel {
  final int id;
  final int categoryId;
  final String categoryName;
  final TransactionType type;
  final String title;
  final double amount;
  final DateTime dueDate;
  final PaymentMethod paymentMethod;
  final String? note;
  final ScheduledFrequency recurringFrequency;
  final ScheduledStatus status;
  final int reminderDaysBefore;
  final DateTime? lastNotifiedAt;
  final DateTime createdAt;

  ScheduledTransactionModel({
    required this.id,
    required this.categoryId,
    required this.categoryName,
    required this.type,
    required this.title,
    required this.amount,
    required this.dueDate,
    required this.paymentMethod,
    this.note,
    required this.recurringFrequency,
    required this.status,
    required this.reminderDaysBefore,
    this.lastNotifiedAt,
    required this.createdAt,
  });

  factory ScheduledTransactionModel.fromJson(Map<String, dynamic> json) {
    return ScheduledTransactionModel(
      id: (json['id'] as num).toInt(),
      categoryId: (json['categoryId'] as num).toInt(),
      categoryName: json['categoryName'] as String? ?? '',
      type: TransactionType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => TransactionType.EXPENSE,
      ),
      title: json['title'] as String? ?? '',
      amount: (json['amount'] as num? ?? 0.0).toDouble(),
      dueDate: json['dueDate'] != null
          ? DateTime.parse(json['dueDate'].toString())
          : DateTime.now(),
      paymentMethod: PaymentMethod.values.firstWhere(
        (e) => e.name == json['paymentMethod'],
        orElse: () => PaymentMethod.CASH,
      ),
      note: json['note'] as String?,
      recurringFrequency: ScheduledFrequency.values.firstWhere(
        (e) => e.name == json['recurringFrequency'],
        orElse: () => ScheduledFrequency.ONCE,
      ),
      status: ScheduledStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => ScheduledStatus.PENDING,
      ),
      reminderDaysBefore: json['reminderDaysBefore'] != null
          ? (json['reminderDaysBefore'] as num).toInt()
          : 3,
      lastNotifiedAt: json['lastNotifiedAt'] != null
          ? DateTime.parse(json['lastNotifiedAt'].toString())
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'].toString())
          : DateTime.now(),
    );
  }

  int get daysUntilDue {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
    return due.difference(today).inDays;
  }
}
