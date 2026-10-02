import 'package:flutter/material.dart';

enum TransactionType { INCOME, EXPENSE }

class CategoryModel {
  final int id;
  final String name;
  final TransactionType type;
  final String? iconKey;
  final String? colorKey;
  final bool isArchived;
  final bool isSystemDefault;

  static const List<Color> defaultPalette = [
    Color(0xFFFF5757), // 1. Coral Red (Food)
    Color(0xFF4A90E2), // 2. Royal Blue (Transport)
    Color(0xFF2ECC71), // 3. Emerald Green (Rent)
    Color(0xFFF39C12), // 4. Amber Gold (Utilities)
    Color(0xFFBA68C8), // 5. Orchid Purple (Shopping)
    Color(0xFFFF8A65), // 6. Coral Orange (Entertainment)
    Color(0xFF00BCD4), // 7. Cyan (Education)
    Color(0xFFE91E63), // 8. Rose Pink (Medicine)
    Color(0xFF2CB8A0), // 9. Emerald Teal (Salary)
    Color(0xFF6C8CFF), // 10. Indigo (Work)
    Color(0xFF9B51E0), // 11. Violet (Investment)
    Color(0xFFE89A58), // 12. Peach Orange (Gifts)
    Color(0xFF64748B), // 13. Slate Grey (General)
    Color(0xFFF43F5E), // 14. Soft Red (Charity)
    Color(0xFF0EA5E9), // 15. Sky Blue (Phone)
    Color(0xFFEC4899), // 16. Pink (Beauty)
    Color(0xFF0284C7), // 17. Ocean Blue (Travel)
    Color(0xFF84CC16), // 18. Lime Green (Fitness)
    Color(0xFF475569), // 19. Slate Blue (Tech)
    Color(0xFFA16207), // 20. Brown (Maintenance)
    Color(0xFFD946EF), // 21. Magenta (Music)
    Color(0xFF1D4ED8), // 22. Deep Blue (Insurance)
    Color(0xFF991B1B), // 23. Deep Red (Tax)
    Color(0xFFF97316), // 24. Soft Orange (Family)
    Color(0xFF14B8A6), // 25. Teal (Hobbies)
    Color(0xFFEAB308), // 26. Yellow (Logistics)
    Color(0xFF4338CA), // 27. Indigo Dark (Books)
    Color(0xFF34D399), // 28. Mint (Personal)
  ];

  CategoryModel({
    required this.id,
    required this.name,
    required this.type,
    this.iconKey,
    this.colorKey,
    this.isArchived = false,
    this.isSystemDefault = false,
  });

  Color get color {
    if (colorKey != null && colorKey!.isNotEmpty) {
      try {
        String hex = colorKey!.replaceAll('#', '');
        if (hex.length == 6) {
          hex = 'FF$hex';
        }
        return Color(int.parse(hex, radix: 16));
      } catch (_) {}
    }
    // Fallback based on ID or name
    return defaultPalette[id.abs() % defaultPalette.length];
  }

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      type: json['type'] == 'INCOME' ? TransactionType.INCOME : TransactionType.EXPENSE,
      iconKey: json['iconKey'] as String?,
      colorKey: json['colorKey'] as String?,
      isArchived: json['isArchived'] as bool? ?? false,
      isSystemDefault: json['isSystemDefault'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type.toString().split('.').last,
      'iconKey': iconKey,
      'colorKey': colorKey,
      'isArchived': isArchived,
      'isSystemDefault': isSystemDefault,
    };
  }
}
