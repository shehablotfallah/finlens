import '../entities/transaction.dart';
import '../repositories/repositories.dart';

/// Domain service that generates the monthly AI insight.
///
/// The actual LLM provider is swappable — see `LlmInsightProvider` in the
/// data layer. We pass aggregated stats ONLY (no individual transactions)
/// to control token cost and protect user privacy.
abstract class InsightService {
  Future<MonthlyInsight> generate({
    required DateTime monthStart,
    required String locale,
  });
}

/// Use case: insert a transaction (enforces currency conversion + base amount).
class InsertTransaction {
  InsertTransaction(this._repo, this._exchangeRateProvider);
  final TransactionRepository _repo;
  final ExchangeRateProvider _exchangeRateProvider;

  Future<String> call(Transaction tx) async {
    final rate = await _exchangeRateProvider.rateFor(tx.currency);
    final base = tx.currency == 'EGP' ? tx.amount : tx.amount * rate;
    return _repo.insert(
      tx.copyWith(
        amountInBase: base,
        exchangeRateAtTime: rate,
      ),
    );
  }
}

/// Use case: compute days remaining until next payday.
class DaysUntilPayday {
  int call({required int salaryDay, required DateTime from}) {
    final today = DateTime(from.year, from.month, from.day);
    DateTime payday = DateTime(today.year, today.month, salaryDay);
    if (payday.isBefore(today)) {
      // Move to next month
      payday = DateTime(today.year, today.month + 1, salaryDay);
    }
    return payday.difference(today).inDays;
  }
}

/// Use case: compute daily budget remaining given balance, days until payday.
class DailyBudgetRemaining {
  double call({
    required double currentBalance,
    required int daysUntilPayday,
  }) {
    if (daysUntilPayday <= 0) return currentBalance;
    return currentBalance / daysUntilPayday;
  }
}

/// Use case: compute next due date for a recurring transaction.
class NextRecurringDueDate {
  DateTime call(Transaction tx, {DateTime? from}) {
    if (!tx.isRecurring) return tx.date;
    final now = from ?? DateTime.now();
    DateTime next = tx.date;
    final interval = tx.recurrenceInterval ?? RecurrenceInterval.monthly;
    final stepDays = interval == RecurrenceInterval.custom
        ? (tx.recurrenceCustomDays ?? 30)
        : interval.defaultDays;
    while (next.isBefore(now)) {
      next = next.add(Duration(days: stepDays));
    }
    return next;
  }
}

/// Provider abstraction for exchange rates (manual in v1).
abstract class ExchangeRateProvider {
  Future<double> rateFor(String currency);
  Future<void> setRate(String currency, double rate);
}
