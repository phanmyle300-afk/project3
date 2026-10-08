import 'package:flutter/material.dart';

enum ExpenseCategory {
  food,
  education,
  travel,
  equipment,
  entertainment,
  other,
}

extension ExpenseCategoryExtension on ExpenseCategory {
  String get nameVi {
    switch (this) {
      case ExpenseCategory.food:
        return 'Thực phẩm';
      case ExpenseCategory.education:
        return 'Học tập';
      case ExpenseCategory.travel:
        return 'Du lịch & Di chuyển';
      case ExpenseCategory.equipment:
        return 'Thiết bị & Đồ dùng';
      case ExpenseCategory.entertainment:
        return 'Giải trí';
      case ExpenseCategory.other:
        return 'Khác';
    }
  }

  IconData get icon {
    switch (this) {
      case ExpenseCategory.food:
        return Icons.restaurant_rounded;
      case ExpenseCategory.education:
        return Icons.menu_book_rounded;
      case ExpenseCategory.travel:
        return Icons.directions_bus_rounded;
      case ExpenseCategory.equipment:
        return Icons.devices_rounded;
      case ExpenseCategory.entertainment:
        return Icons.sports_esports_rounded;
      case ExpenseCategory.other:
        return Icons.category_rounded;
    }
  }

  Color get color {
    switch (this) {
      case ExpenseCategory.food:
        return const Color(0xFFFF5252); // Red-Orange
      case ExpenseCategory.education:
        return const Color(0xFF448AFF); // Blue
      case ExpenseCategory.travel:
        return const Color(0xFFFFB300); // Amber
      case ExpenseCategory.equipment:
        return const Color(0xFF7C4DFF); // Purple
      case ExpenseCategory.entertainment:
        return const Color(0xFF00E676); // Emerald Green
      case ExpenseCategory.other:
        return const Color(0xFF78909C); // Blue Grey
    }
  }

  static ExpenseCategory fromString(String categoryStr) {
    return ExpenseCategory.values.firstWhere(
      (e) => e.name.toLowerCase() == categoryStr.toLowerCase() || e.nameVi.toLowerCase() == categoryStr.toLowerCase(),
      orElse: () => ExpenseCategory.other,
    );
  }
}
