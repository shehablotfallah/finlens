import '../entities/transaction.dart';

/// Repository contract for transaction persistence.
///
/// Implementations live in the data layer; this interface is the only thing
/// domain + presentation layers depend on. A future sync/backend layer can
/// add an implementation that wraps a remote store + local cache without
/// touching call sites.
abstract class TransactionRepository {
  Future<List<Transaction>> getAll();
  Stream<List<Transaction>> watchAll();
  Future<Transaction?> getById(String id);
  Future<List<Transaction>> getByDateRange(DateTime start, DateTime end);
  Future<List<Transaction>> getRecurring();
  Future<String> insert(Transaction tx);
  Future<void> update(Transaction tx);
  Future<void> delete(String id);
  Future<void> deleteAll();
}

/// Repository contract for custom (user-defined) categories.
abstract class CategoryRepository {
  Future<List<Category>> getCustomCategories();
  Future<String> insert(Category category);
  Future<void> update(Category category);
  Future<void> delete(String id);
}

/// Repository contract for installment plans.
abstract class InstallmentPlanRepository {
  Future<List<InstallmentPlan>> getAll();
  Stream<List<InstallmentPlan>> watchAll();
  Future<String> insert(InstallmentPlan plan);
  Future<void> markInstallmentPaid(String planId);
  Future<void> update(InstallmentPlan plan);
  Future<void> delete(String id);
}

/// Repository contract for persisted monthly insights.
abstract class InsightRepository {
  Future<MonthlyInsight?> getForMonth(String monthKey);
  Future<List<MonthlyInsight>> getAll();
  Future<void> save(MonthlyInsight insight);
  Future<void> deleteAll();
}

/// Repository contract for aggregated stats queries.
abstract class StatsRepository {
  /// Total spent in given range.
  Future<double> totalSpent(DateTime start, DateTime end);
  /// Total income in given range.
  Future<double> totalIncome(DateTime start, DateTime end);
  /// Map categoryId → total spent in range.
  Future<Map<String, double>> spentByCategory(
    DateTime start,
    DateTime end, {
    TransactionType? type,
  });
  /// Daily total spent for the given date range, returned as list of (date, total).
  Future<List<({DateTime date, double total})>> dailyTotals(
      DateTime start, DateTime end);
  /// Monthly totals for the given range (one entry per month).
  Future<List<({DateTime monthStart, double spent, double income})>>
      monthlyTotals(DateTime start, DateTime end);
  /// 3-month rolling average per category, ending at given month start.
  Future<Map<String, double>> threeMonthAverageByCategory(DateTime monthStart);
}
