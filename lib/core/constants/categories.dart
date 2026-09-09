import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Predefined transaction categories.
///
/// Each category uses a Lucide icon (modern, consistent icon family)
/// instead of generic Material icons.
class CategoryDef {
  const CategoryDef({
    required this.id,
    required this.icon,
    required this.color,
    required this.l10nKey,
    this.isIncome = false,
  });

  final String id;
  final IconData icon;
  final int color;
  final String l10nKey;
  final bool isIncome;

  Color get colorValue => Color(color);
}

class PredefinedCategories {
  PredefinedCategories._();

  static const List<CategoryDef> all = [
    // Expense categories
    CategoryDef(
      id: 'food',
      icon: LucideIcons.utensils,
      color: 0xFFFF7043,
      l10nKey: 'txCategoryFood',
    ),
    CategoryDef(
      id: 'transport',
      icon: LucideIcons.bus,
      color: 0xFF42A5F5,
      l10nKey: 'txCategoryTransport',
    ),
    CategoryDef(
      id: 'bills',
      icon: LucideIcons.receipt,
      color: 0xFF7E57C2,
      l10nKey: 'txCategoryBills',
    ),
    CategoryDef(
      id: 'entertainment',
      icon: LucideIcons.gamepad2,
      color: 0xFFEC407A,
      l10nKey: 'txCategoryEntertainment',
    ),
    CategoryDef(
      id: 'shopping',
      icon: LucideIcons.shoppingBag,
      color: 0xFFFFA726,
      l10nKey: 'txCategoryShopping',
    ),
    CategoryDef(
      id: 'health',
      icon: LucideIcons.heartPulse,
      color: 0xFFEF5350,
      l10nKey: 'txCategoryHealth',
    ),
    CategoryDef(
      id: 'education',
      icon: LucideIcons.graduationCap,
      color: 0xFF26A69A,
      l10nKey: 'txCategoryEducation',
    ),
    // Income categories
    CategoryDef(
      id: 'salary',
      icon: LucideIcons.banknote,
      color: 0xFF66BB6A,
      l10nKey: 'txCategorySalary',
      isIncome: true,
    ),
    CategoryDef(
      id: 'freelance',
      icon: LucideIcons.laptop,
      color: 0xFF26C6DA,
      l10nKey: 'txCategoryFreelance',
      isIncome: true,
    ),
    CategoryDef(
      id: 'investment_return',
      icon: LucideIcons.trendingUp,
      color: 0xFF9CCC65,
      l10nKey: 'txCategoryInvestmentReturn',
      isIncome: true,
    ),
    CategoryDef(
      id: 'other',
      icon: LucideIcons.moreHorizontal,
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
