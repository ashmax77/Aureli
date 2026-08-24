enum TransactionType { INCOME, EXPENSE }

class CategoryModel {
  final int id;
  final String name;
  final TransactionType type;

  CategoryModel({
    required this.id,
    required this.name,
    required this.type,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      type: json['type'] == 'INCOME' ? TransactionType.INCOME : TransactionType.EXPENSE,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type.toString().split('.').last,
    };
  }
}
