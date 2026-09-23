import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:lucide_icons/lucide_icons.dart';

import '../../core/constants/categories.dart';
import '../../core/theme/finlens_theme.dart';
import '../../core/utils/format.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/usecases/usecases.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../app/providers.dart';
import '../common/skeleton.dart';

class BillsScreen extends ConsumerWidget {
  const BillsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final settings = ref.watch(appSettingsProvider);
    final recurringAsync = ref.watch(recurringTransactionsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l.billsTitle)),
      body: SafeArea(
        child: recurringAsync.when(
          loading: () => ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: 4,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, __) => const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Skeleton.circle(width: 40),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Skeleton(width: 120, height: 16),
                          SizedBox(height: 8),
                          Skeleton(width: 180, height: 12),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          error: (e, _) => Center(child: Text(l.commonError)),
          data: (transactions) {
            final txs = transactions
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
                    Icon(LucideIcons.calendarCheck,
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
                          .withValues(alpha: 0.15),
                      child: Icon(
                        PredefinedCategories.byId(entry.tx.categoryId)
                                ?.icon ??
                            LucideIcons.calendar,
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
                                    ? FinlensColors.expense.withValues(alpha: 0.15)
                                    : soon
                                        ? FinlensColors.warning.withValues(alpha: 0.15)
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
