import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/constants/categories.dart';
import '../../core/theme/finlens_theme.dart';
import '../../core/utils/format.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/usecases/usecases.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../app/providers.dart';

class BillsScreen extends ConsumerWidget {
  const BillsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final settings = ref.watch(appSettingsProvider);
    final repoAsync = ref.watch(transactionRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l.billsTitle)),
      body: SafeArea(
        child: repoAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text(l.commonError)),
          data: (repo) {
            return FutureBuilder<List<Transaction>>(
              future: repo.getRecurring(),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final txs = snap.data!
                    .map((t) => (
                          tx: t,
                          due: NextRecurringDueDate().call(t),
                        ))
                    .toList()
                  ..sort((a, b) => a.due.compareTo(b.due));
                if (txs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.event_available_outlined,
                            size: 64, color: theme.colorScheme.outline),
                        const SizedBox(height: 12),
                        Text(l.billsNoUpcoming, textAlign: TextAlign.center),
                      ],
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: txs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final entry = txs[i];
                    final days =
                        entry.due.difference(DateTime.now()).inDays;
                    final overdue = days < 0;
                    final soon = !overdue && days <= 3;
                    return Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: CircleAvatar(
                          backgroundColor: (PredefinedCategories
                                      .byId(entry.tx.categoryId)
                                      ?.colorValue ??
                                  FinlensColors.neutral)
                              .withOpacity(0.15),
                          child: Icon(
                            PredefinedCategories.byId(entry.tx.categoryId)
                                    ?.icon ??
                                Icons.event,
                            color: PredefinedCategories.byId(entry.tx.categoryId)
                                ?.colorValue,
                          ),
                        ),
                        title: Text(
                          Format.money(entry.tx.amountInBase, settings.baseCurrency),
                          style: theme.textTheme.titleMedium,
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_intervalLabel(l, entry.tx.recurrenceInterval)} • ${_categoryLabel(l, entry.tx.categoryId)}',
                              style: theme.textTheme.bodySmall,
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: overdue
                                    ? FinlensColors.expense.withOpacity(0.15)
                                    : soon
                                        ? FinlensColors.warning.withOpacity(0.15)
                                        : theme.colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                overdue
                                    ? l.billsDueIn(0)
                                    : l.billsDueIn(days < 0 ? 0 : days),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: overdue
                                      ? FinlensColors.expense
                                      : soon
                                          ? FinlensColors.warning
                                          : theme.colorScheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        trailing: Text(
                          DateFormat('MMM d').format(entry.due),
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  String _intervalLabel(AppLocalizations l, RecurrenceInterval? i) {
    if (i == null) return '';
    return switch (i) {
      RecurrenceInterval.weekly => l.txIntervalWeekly,
      RecurrenceInterval.monthly => l.txIntervalMonthly,
      RecurrenceInterval.custom => l.txIntervalCustom,
    };
  }

  String _categoryLabel(AppLocalizations l, String id) {
    return switch (id) {
      'food' => l.txCategoryFood,
      'transport' => l.txCategoryTransport,
      'bills' => l.txCategoryBills,
      'entertainment' => l.txCategoryEntertainment,
      'shopping' => l.txCategoryShopping,
      'health' => l.txCategoryHealth,
      'education' => l.txCategoryEducation,
      'salary' => l.txCategorySalary,
      'freelance' => l.txCategoryFreelance,
      'other' => l.txCategoryOther,
      _ => id,
    };
  }
}
