import 'transaction_model.dart';

enum DebtType {
  BORROWED, // Liability: User owes lender / bank
  LENT,     // Asset: User is owed money by borrower
}

enum DebtStatus {
  ACTIVE,
  SETTLED,
  OVERDUE,
  CANCELLED,
}

class DebtRepaymentModel {
  final int id;
  final int debtRecordId;
  final double amount;
  final DateTime repaymentDate;
  final PaymentMethod paymentMethod;
  final String? note;
  final DateTime createdAt;

  DebtRepaymentModel({
    required this.id,
    required this.debtRecordId,
    required this.amount,
    required this.repaymentDate,
    required this.paymentMethod,
    this.note,
    required this.createdAt,
  });

  factory DebtRepaymentModel.fromJson(Map<String, dynamic> json) {
    PaymentMethod method;
    final pmStr = (json['paymentMethod'] as String?)?.toUpperCase();
    if (pmStr == 'BANK_TRANSFER') {
      method = PaymentMethod.BANK_TRANSFER;
    } else {
      method = PaymentMethod.CARD;
    }

    return DebtRepaymentModel(
      id: json['id'] as int,
      debtRecordId: json['debtRecordId'] as int,
      amount: (json['amount'] as num).toDouble(),
      repaymentDate: DateTime.parse(json['repaymentDate'] as String),
      paymentMethod: method,
      note: json['note'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'debtRecordId': debtRecordId,
      'amount': amount,
      'repaymentDate': repaymentDate.toIso8601String().split('T').first,
      'paymentMethod': paymentMethod.name,
      'note': note,
    };
  }
}

class DebtRecordModel {
  final int id;
  final DebtType type;
  final String counterpartyName;
  final String? counterpartyContact;
  final double principalAmount;
  final double? interestRate;
  final double totalAmountDue;
  final double amountRepaid;
  final double remainingAmount;
  final DateTime startDate;
  final DateTime? dueDate;
  final DebtStatus status;
  final int reminderDaysBefore;
  final String? note;
  final List<DebtRepaymentModel> repayments;
  final DateTime createdAt;
  final DateTime updatedAt;

  DebtRecordModel({
    required this.id,
    required this.type,
    required this.counterpartyName,
    this.counterpartyContact,
    required this.principalAmount,
    this.interestRate,
    required this.totalAmountDue,
    required this.amountRepaid,
    required this.remainingAmount,
    required this.startDate,
    this.dueDate,
    required this.status,
    required this.reminderDaysBefore,
    this.note,
    required this.repayments,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DebtRecordModel.fromJson(Map<String, dynamic> json) {
    DebtType debtType = DebtType.BORROWED;
    if ((json['type'] as String?)?.toUpperCase() == 'LENT') {
      debtType = DebtType.LENT;
    }

    DebtStatus debtStatus = DebtStatus.ACTIVE;
    final statusStr = (json['status'] as String?)?.toUpperCase();
    if (statusStr == 'SETTLED') {
      debtStatus = DebtStatus.SETTLED;
    } else if (statusStr == 'OVERDUE') {
      debtStatus = DebtStatus.OVERDUE;
    } else if (statusStr == 'CANCELLED') {
      debtStatus = DebtStatus.CANCELLED;
    }

    List<DebtRepaymentModel> reps = [];
    if (json['repayments'] != null) {
      reps = (json['repayments'] as List)
          .map((item) => DebtRepaymentModel.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    return DebtRecordModel(
      id: json['id'] as int,
      type: debtType,
      counterpartyName: json['counterpartyName'] as String,
      counterpartyContact: json['counterpartyContact'] as String?,
      principalAmount: (json['principalAmount'] as num).toDouble(),
      interestRate: (json['interestRate'] as num?)?.toDouble(),
      totalAmountDue: (json['totalAmountDue'] as num).toDouble(),
      amountRepaid: (json['amountRepaid'] as num).toDouble(),
      remainingAmount: (json['remainingAmount'] as num).toDouble(),
      startDate: DateTime.parse(json['startDate'] as String),
      dueDate: json['dueDate'] != null ? DateTime.parse(json['dueDate'] as String) : null,
      status: debtStatus,
      reminderDaysBefore: json['reminderDaysBefore'] as int? ?? 3,
      note: json['note'] as String?,
      repayments: reps,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  double get progressPercentage {
    if (totalAmountDue <= 0) return 1.0;
    final p = amountRepaid / totalAmountDue;
    return p.clamp(0.0, 1.0);
  }
}

class DebtSummaryModel {
  final double totalLent;
  final double totalBorrowed;
  final double netDebtPosition;
  final int activeLentCount;
  final int activeBorrowedCount;
  final int overdueCount;

  DebtSummaryModel({
    required this.totalLent,
    required this.totalBorrowed,
    required this.netDebtPosition,
    required this.activeLentCount,
    required this.activeBorrowedCount,
    required this.overdueCount,
  });

  factory DebtSummaryModel.fromJson(Map<String, dynamic> json) {
    return DebtSummaryModel(
      totalLent: (json['totalLent'] as num?)?.toDouble() ?? 0.0,
      totalBorrowed: (json['totalBorrowed'] as num?)?.toDouble() ?? 0.0,
      netDebtPosition: (json['netDebtPosition'] as num?)?.toDouble() ?? 0.0,
      activeLentCount: (json['activeLentCount'] as num?)?.toInt() ?? 0,
      activeBorrowedCount: (json['activeBorrowedCount'] as num?)?.toInt() ?? 0,
      overdueCount: (json['overdueCount'] as num?)?.toInt() ?? 0,
    );
  }
}
