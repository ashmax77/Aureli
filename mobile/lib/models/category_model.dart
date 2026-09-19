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
    Color(0xFFFF5757), // Coral Red (Food)
    Color(0xFF4A90E2), // Royal Blue (Transport)
    Color(0xFF2ECC71), // Emerald Green (Rent)
    Color(0xFFF39C12), // Amber Gold (Utilities)
    Color(0xFFBA68C8), // Orchid Purple (Shopping)
    Color(0xFFFF8A65), // Coral Orange (Entertainment)
    Color(0xFF00BCD4), // Cyan (Education)
    Color(0xFFE91E63), // Rose Pink (Medicine)
    Color(0xFF2CB8A0), // Emerald Teal
    Color(0xFF6C8CFF), // Indigo
    Color(0xFF9B51E0), // Violet
    Color(0xFFE89A58), // Peach Orange
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
