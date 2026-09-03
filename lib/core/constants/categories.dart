/// Predefined transaction categories.
///
/// Each category has:
/// - a stable string `id` used as DB key (never localized)
/// - a default `icon` (Material icon codepoint)
/// - a default `color` (ARGB int)
/// - a localization key used to resolve the display name
library;

import 'package:flutter/material.dart';

class CategoryDef {
  const CategoryDef({
    required this.id,
    required this.iconCodePoint,
    required this.color,
    required this.l10nKey,
    this.isIncome = false,
  });

  final String id;
  final int iconCodePoint;
  final int color;
  final String l10nKey;
  final bool isIncome;

  IconData get icon => IconData(iconCodePoint, fontFamily: 'MaterialIcons');
  Color get colorValue => Color(color);
}

class PredefinedCategories {
  PredefinedCategories._();

  static const List<CategoryDef> all = [
    // Expense categories
    CategoryDef(
      id: 'food',
      iconCodePoint: 0xe56c, // restaurant
      color: 0xFFFF7043,
      l10nKey: 'txCategoryFood',
    ),
    CategoryDef(
      id: 'transport',
      iconCodePoint: 0xe1d5, // directions_car
      color: 0xFF42A5F5,
      l10nKey: 'txCategoryTransport',
    ),
    CategoryDef(
      id: 'bills',
      iconCodePoint: 0xe87c, // receipt_long
      color: 0xFF7E57C2,
      l10nKey: 'txCategoryBills',
    ),
    CategoryDef(
      id: 'entertainment',
      iconCodePoint: 0xe531, // movie
      color: 0xFFEC407A,
      l10nKey: 'txCategoryEntertainment',
    ),
    CategoryDef(
      id: 'shopping',
      iconCodePoint: 0xe59c, // shopping_bag
      color: 0xFFFFA726,
      l10nKey: 'txCategoryShopping',
    ),
    CategoryDef(
      id: 'health',
      iconCodePoint: 0xe3a3, // local_hospital
      color: 0xFFEF5350,
      l10nKey: 'txCategoryHealth',
    ),
    CategoryDef(
      id: 'education',
      iconCodePoint: 0xe80c, // school
      color: 0xFF26A69A,
      l10nKey: 'txCategoryEducation',
    ),
    // Income categories
    CategoryDef(
      id: 'salary',
      iconCodePoint: 0xe850, // account_balance
      color: 0xFF66BB6A,
      l10nKey: 'txCategorySalary',
      isIncome: true,
    ),
    CategoryDef(
      id: 'freelance',
      iconCodePoint: 0xe85d, // laptop_mac
      color: 0xFF26C6DA,
      l10nKey: 'txCategoryFreelance',
      isIncome: true,
    ),
    CategoryDef(
      id: 'other',
      iconCodePoint: 0xe5d3, // category
      color: 0xFF78909C,
      l10nKey: 'txCategoryOther',
    ),
  ];

  static CategoryDef? byId(String id) {
    for (final c in all) {
      if (c.id == id) return c;
    }
    return null;
  }

  static List<CategoryDef> get expenses =>
      all.where((c) => !c.isIncome).toList();
  static List<CategoryDef> get incomes => all.where((c) => c.isIncome).toList();
}
