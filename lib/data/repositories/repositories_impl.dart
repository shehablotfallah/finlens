import 'package:drift/drift.dart';
import 'package:finlens/domain/entities/transaction.dart' as domain;
import 'package:finlens/domain/repositories/repositories.dart';
import 'package:finlens/domain/usecases/usecases.dart' as usecases;

import '../datasources/local/finlens_database.dart';

/// Drift-backed implementation of [TransactionRepository].
class TransactionRepositoryImpl implements TransactionRepository {
  TransactionRepositoryImpl(this._db);
  final FinlensDatabase _db;

  @override
  Future<List<domain.Transaction>> getAll() async {
    final rows = await _db.select(_db.transactions).get();
    return rows.map(_toDomain).toList();
  }

  @override
  Stream<List<domain.Transaction>> watchAll() {
    return _db.select(_db.transactions).watch().map(
          (rows) => rows.map(_toDomain).toList(),
        );
  }

  @override
  Future<domain.Transaction?> getById(String id) async {
    final row = await (_db.select(_db.transactions)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  @override
  Future<List<domain.Transaction>> getByDateRange(
      DateTime start, DateTime end) async {
    final rows = await (_db.select(_db.transactions)
          ..where((t) => t.date.isBetweenValues(start, end))
          ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .get();
    return rows.map(_toDomain).toList();
  }

  @override
  Future<List<domain.Transaction>> getRecurring() async {
    final rows = await (_db.select(_db.transactions)
          ..where((t) => t.isRecurring.equals(true)))
        .get();
    return rows.map(_toDomain).toList();
  }

  @override
  Future<String> insert(domain.Transaction tx) async {
    final companion = _toCompanion(tx);
    await _db.into(_db.transactions).insertOnConflictUpdate(companion);
    return tx.id;
  }

  @override
  Future<void> update(domain.Transaction tx) async {
    final companion = _toCompanion(tx).copyWith(
      updatedAt: Value(DateTime.now()),
    );
    await (_db.update(_db.transactions)
          ..where((t) => t.id.equals(tx.id)))
        .write(companion);
  }

  @override
  Future<void> delete(String id) async {
    await (_db.delete(_db.transactions)..where((t) => t.id.equals(id))).go();
  }

  @override
  Future<void> deleteAll() async {
    await _db.delete(_db.transactions).go();
  }

  // -----------------------------------------------------------------------
  // Mappers
  // -----------------------------------------------------------------------
  domain.Transaction _toDomain(Transaction row) {
    return domain.Transaction(
      id: row.id,
      type: row.type == TransactionTypeDb.expense
          ? domain.TransactionType.expense
          : domain.TransactionType.income,
      amount: row.amount,
      currency: row.currency,
      amountInBase: row.amountInBase,
      exchangeRateAtTime: row.exchangeRateAtTime,
      categoryId: row.categoryId,
      date: row.date,
      note: row.note,
      isRecurring: row.isRecurring,
      recurrenceInterval: row.recurrenceInterval == null
          ? null
          : domain.RecurrenceInterval.values[row.recurrenceInterval!.index],
      recurrenceCustomDays: row.recurrenceCustomDays,
      reminderDaysBefore: row.reminderDaysBefore,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  TransactionsCompanion _toCompanion(domain.Transaction tx) {
    return TransactionsCompanion(
      id: Value(tx.id),
      type: Value(tx.type == domain.TransactionType.expense
          ? TransactionTypeDb.expense
          : TransactionTypeDb.income),
      amount: Value(tx.amount),
      currency: Value(tx.currency),
      amountInBase: Value(tx.amountInBase),
      exchangeRateAtTime: Value(tx.exchangeRateAtTime),
      categoryId: Value(tx.categoryId),
      date: Value(tx.date),
      note: Value(tx.note),
      isRecurring: Value(tx.isRecurring),
      recurrenceInterval: Value(tx.recurrenceInterval == null
          ? null
          : RecurrenceIntervalDb.values[tx.recurrenceInterval!.index]),
      recurrenceCustomDays: Value(tx.recurrenceCustomDays),
      reminderDaysBefore: Value(tx.reminderDaysBefore),
      updatedAt: Value(DateTime.now()),
    );
  }
}

class CategoryRepositoryImpl implements CategoryRepository {
  CategoryRepositoryImpl(this._db);
  final FinlensDatabase _db;

  @override
  Future<List<domain.Category>> getCustomCategories() async {
    final rows = await _db.select(_db.customCategories).get();
    return rows
        .map((r) => domain.Category(
              id: r.id,
              iconCodePoint: r.iconCodePoint,
              colorValue: r.colorValue,
              isIncome: r.isIncome,
              isUserDefined: true,
            ))
        .toList();
  }

  @override
  Future<String> insert(domain.Category category) async {
    await _db.into(_db.customCategories).insertOnConflictUpdate(
          CustomCategoriesCompanion(
            id: Value(category.id),
            iconCodePoint: Value(category.iconCodePoint),
            colorValue: Value(category.colorValue),
            isIncome: Value(category.isIncome),
          ),
        );
    return category.id;
  }

  @override
  Future<void> update(domain.Category category) async {
    await (_db.update(_db.customCategories)
          ..where((t) => t.id.equals(category.id)))
        .write(CustomCategoriesCompanion(
      iconCodePoint: Value(category.iconCodePoint),
      colorValue: Value(category.colorValue),
      isIncome: Value(category.isIncome),
    ));
  }

  @override
  Future<void> delete(String id) async {
    await (_db.delete(_db.customCategories)..where((t) => t.id.equals(id))).go();
  }
}

class InstallmentPlanRepositoryImpl implements InstallmentPlanRepository {
  InstallmentPlanRepositoryImpl(this._db);
  final FinlensDatabase _db;

  @override
  Future<List<domain.InstallmentPlan>> getAll() async {
    final rows = await (_db.select(_db.installmentPlans)
          ..orderBy([(t) => OrderingTerm.desc(t.startDate)]))
        .get();
    return rows.map(_toDomain).toList();
  }

  @override
  Stream<List<domain.InstallmentPlan>> watchAll() {
    return (_db.select(_db.installmentPlans)
          ..orderBy([(t) => OrderingTerm.desc(t.startDate)]))
        .watch()
        .map((rows) => rows.map(_toDomain).toList());
  }

  @override
  Future<String> insert(domain.InstallmentPlan plan) async {
    await _db.into(_db.installmentPlans).insertOnConflictUpdate(
          InstallmentPlansCompanion(
            id: Value(plan.id),
            providerName: Value(plan.providerName),
            totalAmount: Value(plan.totalAmount),
            currency: Value(plan.currency),
            installmentCount: Value(plan.installmentCount),
            paidCount: Value(plan.paidCount),
            startDate: Value(plan.startDate),
            intervalDays: Value(plan.intervalDays),
            note: Value(plan.note),
          ),
        );
    return plan.id;
  }

  @override
  Future<void> markInstallmentPaid(String planId) async {
    final row = await (_db.select(_db.installmentPlans)
          ..where((t) => t.id.equals(planId)))
        .getSingleOrNull();
    if (row == null) return;
    final newPaid = row.paidCount + 1;
    await (_db.update(_db.installmentPlans)
          ..where((t) => t.id.equals(planId)))
        .write(InstallmentPlansCompanion(paidCount: Value(newPaid)));
  }

  @override
  Future<void> update(domain.InstallmentPlan plan) async {
    await (_db.update(_db.installmentPlans)
          ..where((t) => t.id.equals(plan.id)))
        .write(InstallmentPlansCompanion(
      providerName: Value(plan.providerName),
      totalAmount: Value(plan.totalAmount),
      currency: Value(plan.currency),
      installmentCount: Value(plan.installmentCount),
      paidCount: Value(plan.paidCount),
      startDate: Value(plan.startDate),
      intervalDays: Value(plan.intervalDays),
      note: Value(plan.note),
    ));
  }

  @override
  Future<void> delete(String id) async {
    await (_db.delete(_db.installmentPlans)..where((t) => t.id.equals(id))).go();
  }

  domain.InstallmentPlan _toDomain(InstallmentPlan row) {
    return domain.InstallmentPlan(
      id: row.id,
      providerName: row.providerName,
      totalAmount: row.totalAmount,
      currency: row.currency,
      installmentCount: row.installmentCount,
      paidCount: row.paidCount,
      startDate: row.startDate,
      intervalDays: row.intervalDays,
      note: row.note,
      createdAt: row.createdAt,
    );
  }
}

class InsightRepositoryImpl implements InsightRepository {
  InsightRepositoryImpl(this._db);
  final FinlensDatabase _db;

  @override
  Future<domain.MonthlyInsight?> getForMonth(String monthKey) async {
    final row = await (_db.select(_db.monthlyInsights)
          ..where((t) => t.monthKey.equals(monthKey))
          ..orderBy([(t) => OrderingTerm.desc(t.generatedAt)])
          ..limit(1))
        .getSingleOrNull();
    if (row == null) return null;
    return domain.MonthlyInsight(
      id: row.id,
      monthKey: row.monthKey,
      text: row.body,
      generatedAt: row.generatedAt,
      locale: row.locale,
    );
  }

  @override
  Future<List<domain.MonthlyInsight>> getAll() async {
    final rows = await (_db.select(_db.monthlyInsights)
          ..orderBy([(t) => OrderingTerm.desc(t.generatedAt)]))
        .get();
    return rows
        .map((r) => domain.MonthlyInsight(
              id: r.id,
              monthKey: r.monthKey,
              text: r.body,
              generatedAt: r.generatedAt,
              locale: r.locale,
            ))
        .toList();
  }

  @override
  Future<void> save(domain.MonthlyInsight insight) async {
    await _db.into(_db.monthlyInsights).insertOnConflictUpdate(
          MonthlyInsightsCompanion(
            id: Value(insight.id),
            monthKey: Value(insight.monthKey),
            body: Value(insight.text),
            generatedAt: Value(insight.generatedAt),
            locale: Value(insight.locale),
          ),
        );
    // Persist the month so we know whether to nag the user with "generate this month's insight".
    // (tracked separately via SharedPreferences — see InsightsNotifier)
  }

  @override
  Future<void> deleteAll() async {
    await _db.delete(_db.monthlyInsights).go();
  }
}

/// Drift-backed implementation of [StatsRepository].
class StatsRepositoryImpl implements StatsRepository {
  StatsRepositoryImpl(this._db);
  final FinlensDatabase _db;

  @override
  Future<double> totalSpent(DateTime start, DateTime end) async {
    final sumExpr = _db.transactions.amountInBase.sum();
    final rows = await (_db.selectOnly(_db.transactions)
          ..addColumns([sumExpr])
          ..where(_db.transactions.date.isBetweenValues(start, end) &
              _db.transactions.type
                  .equals(TransactionTypeDb.expense.index)))
        .get();
    if (rows.isEmpty) return 0.0;
    final v = rows.first.read(sumExpr);
    return v ?? 0.0;
  }

  @override
  Future<double> totalIncome(DateTime start, DateTime end) async {
    final sumExpr = _db.transactions.amountInBase.sum();
    final rows = await (_db.selectOnly(_db.transactions)
          ..addColumns([sumExpr])
          ..where(_db.transactions.date.isBetweenValues(start, end) &
              _db.transactions.type
                  .equals(TransactionTypeDb.income.index)))
        .get();
    if (rows.isEmpty) return 0.0;
    final v = rows.first.read(sumExpr);
    return v ?? 0.0;
  }

  @override
  Future<Map<String, double>> spentByCategory(
    DateTime start,
    DateTime end, {
    domain.TransactionType? type,
  }) async {
    final typeFilter = type == null
        ? const Constant(true)
        : _db.transactions.type.equals(type == domain.TransactionType.expense
            ? TransactionTypeDb.expense.index
            : TransactionTypeDb.income.index);
    final query = _db.selectOnly(_db.transactions)
      ..addColumns([_db.transactions.categoryId, _db.transactions.amountInBase.sum()])
      ..where(_db.transactions.date.isBetweenValues(start, end) & typeFilter)
      ..groupBy([_db.transactions.categoryId])
      ..orderBy([OrderingTerm.desc(_db.transactions.amountInBase.sum())]);
    final rows = await query.get();
    final out = <String, double>{};
    for (final r in rows) {
      final catId = r.read(_db.transactions.categoryId)!;
      final total = r.read(_db.transactions.amountInBase.sum()) ?? 0.0;
      out[catId] = total;
    }
    return out;
  }

  @override
  Future<List<({DateTime date, double total})>> dailyTotals(
      DateTime start, DateTime end) async {
    final all = await getByDateRange(start, end);
    final byDay = <DateTime, double>{};
    for (final tx in all) {
      if (tx.type != domain.TransactionType.expense) continue;
      final dKey = DateTime(tx.date.year, tx.date.month, tx.date.day);
      byDay[dKey] = (byDay[dKey] ?? 0) + tx.amountInBase;
    }
    final days = <({DateTime date, double total})>[];
    var cursor = DateTime(start.year, start.month, start.day);
    final endDay = DateTime(end.year, end.month, end.day);
    while (!cursor.isAfter(endDay)) {
      days.add((date: cursor, total: byDay[cursor] ?? 0));
      cursor = cursor.add(const Duration(days: 1));
    }
    return days;
  }

  @override
  Future<List<({DateTime monthStart, double spent, double income})>>
      monthlyTotals(DateTime start, DateTime end) async {
    final all = await getByDateRange(start, end);
    final byMonth = <DateTime, ({double spent, double income})>{};
    for (final tx in all) {
      final mKey = DateTime(tx.date.year, tx.date.month, 1);
      final cur = byMonth[mKey] ?? (spent: 0.0, income: 0.0);
      if (tx.type == domain.TransactionType.expense) {
        byMonth[mKey] = (spent: cur.spent + tx.amountInBase, income: cur.income);
      } else {
        byMonth[mKey] = (spent: cur.spent, income: cur.income + tx.amountInBase);
      }
    }
    final out = <({DateTime monthStart, double spent, double income})>[];
    var cursor = DateTime(start.year, start.month, 1);
    final endMonth = DateTime(end.year, end.month, 1);
    while (!cursor.isAfter(endMonth)) {
      final v = byMonth[cursor] ?? (spent: 0.0, income: 0.0);
      out.add((monthStart: cursor, spent: v.spent, income: v.income));
      cursor = DateTime(cursor.year, cursor.month + 1, 1);
    }
    return out;
  }

  @override
  Future<Map<String, double>> threeMonthAverageByCategory(
      DateTime monthStart) async {
    final start = DateTime(monthStart.year, monthStart.month - 3, 1);
    final end = DateTime(monthStart.year, monthStart.month, 0, 23, 59, 59);
    final totals = await spentByCategory(start, end,
        type: domain.TransactionType.expense);
    return totals.map((k, v) => MapEntry(k, v / 3));
  }

  Future<List<domain.Transaction>> getByDateRange(
      DateTime start, DateTime end) async {
    final rows = await (_db.select(_db.transactions)
          ..where((t) => t.date.isBetweenValues(start, end)))
        .get();
    return rows.map((row) {
      return domain.Transaction(
        id: row.id,
        type: row.type == TransactionTypeDb.expense
            ? domain.TransactionType.expense
            : domain.TransactionType.income,
        amount: row.amount,
        currency: row.currency,
        amountInBase: row.amountInBase,
        exchangeRateAtTime: row.exchangeRateAtTime,
        categoryId: row.categoryId,
        date: row.date,
        note: row.note,
        isRecurring: row.isRecurring,
        recurrenceInterval: row.recurrenceInterval == null
            ? null
            : domain.RecurrenceInterval.values[row.recurrenceInterval!.index],
        recurrenceCustomDays: row.recurrenceCustomDays,
        reminderDaysBefore: row.reminderDaysBefore,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
      );
    }).toList();
  }
}

/// A simple in-memory + SharedPreferences-backed exchange rate provider.
/// In v1 the user manually updates the rate; this can later be swapped
/// for an API-backed implementation without touching call sites.
class ExchangeRateProviderImpl implements usecases.ExchangeRateProvider {
  ExchangeRateProviderImpl();
  final Map<String, double> _cache = {'EGP': 1.0};

  void setInitialRate(String currency, double rate) {
    _cache[currency] = rate;
  }

  @override
  Future<double> rateFor(String currency) async {
    return _cache[currency] ?? 1.0;
  }

  @override
  Future<void> setRate(String currency, double rate) async {
    _cache[currency] = rate;
  }
}
