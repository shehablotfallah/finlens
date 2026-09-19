import 'package:flutter/material.dart';

/// Recurrence interval for a transaction marked as recurring.
enum RecurrenceInterval { weekly, monthly, custom }

extension RecurrenceIntervalX on RecurrenceInterval {
  int get defaultDays {
    switch (this) {
      case RecurrenceInterval.weekly:
        return 7;
      case RecurrenceInterval.monthly:
        return 30;
      case RecurrenceInterval.custom:
        return 0;
    }
  }
}

/// Type of a transaction.
enum TransactionType { expense, income }

/// Domain entity for a single financial transaction.
///
/// Notes on currency design:
/// Each transaction stores its original currency code (e.g. 'USD' for
/// freelance income paid in dollars). At insert time we also persist the
/// exchange rate that was in effect, so historical reports stay accurate
/// even if the user later updates the rate.
class Transaction {
  Transaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.currency,
    required this.amountInBase,
    required this.exchangeRateAtTime,
    required this.categoryId,
    required this.date,
    this.note,
    this.isRecurring = false,
    this.recurrenceInterval,
    this.recurrenceCustomDays,
    this.reminderDaysBefore,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final TransactionType type;
  final double amount;
  final String currency;
  final double amountInBase;
  final double exchangeRateAtTime;
  final String categoryId;
  final DateTime date;
  final String? note;
  final bool isRecurring;
  final RecurrenceInterval? recurrenceInterval;
  final int? recurrenceCustomDays;
  final int? reminderDaysBefore;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Transaction copyWith({
    String? id,
    TransactionType? type,
    double? amount,
    String? currency,
    double? amountInBase,
    double? exchangeRateAtTime,
    String? categoryId,
    DateTime? date,
    String? note,
    bool? isRecurring,
    RecurrenceInterval? recurrenceInterval,
    int? recurrenceCustomDays,
    int? reminderDaysBefore,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Transaction(
      id: id ?? this.id,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      amountInBase: amountInBase ?? this.amountInBase,
      exchangeRateAtTime: exchangeRateAtTime ?? this.exchangeRateAtTime,
      categoryId: categoryId ?? this.categoryId,
      date: date ?? this.date,
      note: note ?? this.note,
      isRecurring: isRecurring ?? this.isRecurring,
      recurrenceInterval: recurrenceInterval ?? this.recurrenceInterval,
      recurrenceCustomDays: recurrenceCustomDays ?? this.recurrenceCustomDays,
      reminderDaysBefore: reminderDaysBefore ?? this.reminderDaysBefore,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'amount': amount,
        'currency': currency,
        'amountInBase': amountInBase,
        'exchangeRateAtTime': exchangeRateAtTime,
        'categoryId': categoryId,
        'date': date.toIso8601String(),
        'note': note,
        'isRecurring': isRecurring,
        'recurrenceInterval': recurrenceInterval?.name,
        'recurrenceCustomDays': recurrenceCustomDays,
        'reminderDaysBefore': reminderDaysBefore,
        'createdAt': createdAt?.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
      };

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'] as String,
      type: json['type'] == 'income'
          ? TransactionType.income
          : TransactionType.expense,
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'EGP',
      amountInBase: (json['amountInBase'] as num?)?.toDouble() ??
          (json['amount'] as num).toDouble(),
      exchangeRateAtTime:
          (json['exchangeRateAtTime'] as num?)?.toDouble() ?? 1.0,
      categoryId: json['categoryId'] as String,
      date: DateTime.parse(json['date'] as String),
      note: json['note'] as String?,
      isRecurring: json['isRecurring'] as bool? ?? false,
      recurrenceInterval: json['recurrenceInterval'] != null
          ? RecurrenceInterval.values.firstWhere(
              (e) => e.name == json['recurrenceInterval'],
              orElse: () => RecurrenceInterval.monthly,
            )
          : null,
      recurrenceCustomDays: json['recurrenceCustomDays'] as int?,
      reminderDaysBefore: json['reminderDaysBefore'] as int?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }
}

/// Domain entity for a custom (user-defined) category.
class Category {
  Category({
    required this.id,
    required this.iconCodePoint,
    required this.colorValue,
    required this.isIncome,
    this.isUserDefined = true,
  });

  final String id;
  final int iconCodePoint;
  final int colorValue;
  final bool isIncome;
  final bool isUserDefined;

  IconData get icon => IconData(iconCodePoint, fontFamily: 'MaterialIcons');
  Color get color => Color(colorValue);
}

/// Domain entity for an installment plan.
class InstallmentPlan {
  InstallmentPlan({
    required this.id,
    required this.providerName,
    required this.totalAmount,
    required this.currency,
    required this.installmentCount,
    required this.paidCount,
    required this.startDate,
    required this.intervalDays,
    this.note,
    this.createdAt,
  });

  final String id;
  final String providerName;
  final double totalAmount;
  final String currency;
  final int installmentCount;
  final int paidCount;
  final DateTime startDate;
  final int intervalDays;
  final String? note;
  final DateTime? createdAt;

  double get installmentAmount =>
      installmentCount == 0 ? 0 : totalAmount / installmentCount;

  double get remainingAmount =>
      installmentAmount * (installmentCount - paidCount);

  int get remainingCount => installmentCount - paidCount;

  DateTime get nextDueDate {
    if (paidCount >= installmentCount) return startDate;
    return startDate.add(Duration(days: intervalDays * paidCount));
  }

  bool get isComplete => paidCount >= installmentCount;
}

/// Computed monthly insight, generated by LLM service.
class MonthlyInsight {
  MonthlyInsight({
    required this.id,
    required this.monthKey,
    required this.text,
    required this.generatedAt,
    required this.locale,
  });

  final String id;
  final String monthKey; // YYYY-MM
  final String text;
  final DateTime generatedAt;
  final String locale;
}

/// Aggregated stats for a month, sent to the LLM insight service.
/// No individual transaction rows are sent.
class MonthlyAggregatedStats {
  MonthlyAggregatedStats({
    required this.monthKey,
    required this.totalSpent,
    required this.totalIncome,
    required this.currency,
    required this.topCategoryIds,
    required this.categoryTotals,
    required this.dailyAverage,
    required this.threeMonthAverageByCategory,
    required this.txCount,
  });

  final String monthKey;
  final double totalSpent;
  final double totalIncome;
  final String currency;
  /// category id → total amount
  final Map<String, double> categoryTotals;
  /// Top category ids sorted desc.
  final List<String> topCategoryIds;
  final double dailyAverage;
  /// categoryId → 3-month average (or empty if not enough history)
  final Map<String, double> threeMonthAverageByCategory;
  final int txCount;
}
