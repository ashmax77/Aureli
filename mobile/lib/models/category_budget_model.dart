class CategoryBudgetModel {
  final int id;
  final int categoryId;
  final String categoryName;
  final DateTime budgetMonth;
  final double amountLimit;

  CategoryBudgetModel({
    required this.id,
    required this.categoryId,
    required this.categoryName,
    required this.budgetMonth,
    required this.amountLimit,
  });

  factory CategoryBudgetModel.fromJson(Map<String, dynamic> json) {
    return CategoryBudgetModel(
      id: json['id'] as int,
      categoryId: json['categoryId'] as int,
      categoryName: json['categoryName'] as String? ?? '',
      budgetMonth: DateTime.parse(json['budgetMonth'] as String),
      amountLimit: (json['amountLimit'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'categoryId': categoryId,
      'categoryName': categoryName,
      'budgetMonth': "${budgetMonth.year.toString().padLeft(4, '0')}-${budgetMonth.month.toString().padLeft(2, '0')}-${budgetMonth.day.toString().padLeft(2, '0')}",
      'amountLimit': amountLimit,
    };
  }
}
