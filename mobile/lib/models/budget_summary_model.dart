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
}

class BudgetSummaryModel {
  final double totalIncome;
  final double totalExpenses;
  final double netCashFlow;
  final double previousMonthExpenses;
  final List<CategoryBudgetSummary> categoryBudgets;

  BudgetSummaryModel({
    required this.totalIncome,
    required this.totalExpenses,
    required this.netCashFlow,
    required this.previousMonthExpenses,
    required this.categoryBudgets,
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
    );
  }
}
