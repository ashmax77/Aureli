enum TransactionType { INCOME, EXPENSE }

class CategoryModel {
  final int id;
  final String name;
  final TransactionType type;
  final bool isArchived;

  CategoryModel({
    required this.id,
    required this.name,
    required this.type,
    this.isArchived = false,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      type: json['type'] == 'INCOME' ? TransactionType.INCOME : TransactionType.EXPENSE,
      isArchived: json['isArchived'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type.toString().split('.').last,
      'isArchived': isArchived,
    };
  }
}
