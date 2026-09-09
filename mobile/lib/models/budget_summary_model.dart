class CategoryBudgetSummary {
  final int categoryId;
  final String categoryName;
  final double? amountLimit;
  final double totalSpent;
  final String status; // NORMAL, NEARING_90, EXCEEDED_100
  final int transactionCount;

  CategoryBudgetSummary({
    required this.categoryId,
    required this.categoryName,
    this.amountLimit,
    required this.totalSpent,
    required this.status,
    required this.transactionCount,
  });

  factory CategoryBudgetSummary.fromJson(Map<String, dynamic> json) {
    final alertState = json['alertState'] as String? ?? 'NORMAL';
    String status = 'NORMAL';
    if (alertState == 'EXCEEDED') {
      status = 'EXCEEDED_100';
    } else if (alertState == 'NEARING') {
      status = 'NEARING_90';
    }

    return CategoryBudgetSummary(
      categoryId: json['categoryId'] as int,
      categoryName: json['categoryName'] as String? ?? '',
      amountLimit: json['budgetLimit'] != null ? (json['budgetLimit'] as num).toDouble() : null,
      totalSpent: (json['currentSpend'] as num? ?? 0.0).toDouble(),
      status: status,
      transactionCount: json['transactionCount'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'categoryId': categoryId,
      'categoryName': categoryName,
      'budgetLimit': amountLimit,
      'currentSpend': totalSpent,
      'alertState': status == 'EXCEEDED_100' ? 'EXCEEDED' : (status == 'NEARING_90' ? 'NEARING' : 'NORMAL'),
      'transactionCount': transactionCount,
    };
  }
}

class BudgetSummaryModel {
  final double totalIncome;
  final double totalExpenses;
  final double netCashFlow;
  final double previousMonthExpenses;
  final List<CategoryBudgetSummary> categoryBudgets;

  // Savings Vault & Spendable Allowance
  final double savingsRatePercentage;
  final double monthlyReservedSavings;
  final double cumulativeSavings;
  final double scheduledPaymentsTotal;
  final double spendableAllowance;
  final double totalAllocatedCategoryBudgets;
  final double unallocatedAllowance;

  BudgetSummaryModel({
    required this.totalIncome,
    required this.totalExpenses,
    required this.netCashFlow,
    required this.previousMonthExpenses,
    required this.categoryBudgets,
    this.savingsRatePercentage = 20.0,
    this.monthlyReservedSavings = 0.0,
    this.cumulativeSavings = 0.0,
    this.scheduledPaymentsTotal = 0.0,
    this.spendableAllowance = 0.0,
    this.totalAllocatedCategoryBudgets = 0.0,
    this.unallocatedAllowance = 0.0,
  });

  factory BudgetSummaryModel.fromJson(Map<String, dynamic> json) {
    var rawList = json['categoryBudgets'] as List? ?? [];
    List<CategoryBudgetSummary> budgetSummaries = rawList
        .map((e) => CategoryBudgetSummary.fromJson(e as Map<String, dynamic>))
        .toList();

    return BudgetSummaryModel(
      totalIncome: (json['totalIncome'] as num? ?? 0.0).toDouble(),
      totalExpenses: (json['totalExpenses'] as num? ?? 0.0).toDouble(),
      netCashFlow: (json['netCashFlow'] as num? ?? 0.0).toDouble(),
      previousMonthExpenses: (json['previousMonthExpenses'] as num? ?? 0.0).toDouble(),
      categoryBudgets: budgetSummaries,
      savingsRatePercentage: (json['savingsRatePercentage'] as num?)?.toDouble() ?? 20.0,
      monthlyReservedSavings: (json['monthlyReservedSavings'] as num?)?.toDouble() ?? 0.0,
      cumulativeSavings: (json['cumulativeSavings'] as num?)?.toDouble() ?? 0.0,
      scheduledPaymentsTotal: (json['scheduledPaymentsTotal'] as num?)?.toDouble() ?? 0.0,
      spendableAllowance: (json['spendableAllowance'] as num?)?.toDouble() ?? 0.0,
      totalAllocatedCategoryBudgets: (json['totalAllocatedCategoryBudgets'] as num?)?.toDouble() ?? 0.0,
      unallocatedAllowance: (json['unallocatedAllowance'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalIncome': totalIncome,
      'totalExpenses': totalExpenses,
      'netCashFlow': netCashFlow,
      'previousMonthExpenses': previousMonthExpenses,
      'categoryBudgets': categoryBudgets.map((b) => b.toJson()).toList(),
      'savingsRatePercentage': savingsRatePercentage,
      'monthlyReservedSavings': monthlyReservedSavings,
      'cumulativeSavings': cumulativeSavings,
      'scheduledPaymentsTotal': scheduledPaymentsTotal,
      'spendableAllowance': spendableAllowance,
      'totalAllocatedCategoryBudgets': totalAllocatedCategoryBudgets,
      'unallocatedAllowance': unallocatedAllowance,
    };
  }
}
