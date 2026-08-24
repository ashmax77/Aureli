class CategoryBudgetSummary {
  final int categoryId;
  final String categoryName;
  final double? amountLimit;
  final double totalSpent;
  final String status; // NORMAL, NEARING_90, EXCEEDED_100

  CategoryBudgetSummary({
    required this.categoryId,
    required this.categoryName,
    this.amountLimit,
    required this.totalSpent,
    required this.status,
  });

  factory CategoryBudgetSummary.fromJson(Map<String, dynamic> json) {
    return CategoryBudgetSummary(
      categoryId: json['categoryId'] as int,
      categoryName: json['categoryName'] as String? ?? '',
      amountLimit: json['amountLimit'] != null ? (json['amountLimit'] as num).toDouble() : null,
      totalSpent: (json['totalSpent'] as num? ?? 0.0).toDouble(),
      status: json['status'] as String? ?? 'NORMAL',
    );
  }
}

class BudgetSummaryModel {
  final double totalIncome;
  final double totalExpenses;
  final double netCashFlow;
  final List<CategoryBudgetSummary> categoryBudgets;

  BudgetSummaryModel({
    required this.totalIncome,
    required this.totalExpenses,
    required this.netCashFlow,
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
      categoryBudgets: budgetSummaries,
    );
  }
}
