import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/categories.dart';
import '../../core/theme/finlens_theme.dart';
import '../../core/utils/format.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/usecases/usecases.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../app/providers.dart';
import '../transactions/transaction_edit_sheet.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    // Show the "quick category" hint once.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = ref.read(appSettingsProvider);
      if (!settings.hintsShown.contains(AppConstants.hintQuickCategory)) {
        _showHint(AppConstants.hintQuickCategory);
      }
    });
  }

  void _showHint(String key) {
    final l = AppLocalizations.of(context);
    final message = switch (key) {
      AppConstants.hintQuickCategory => l.hintQuickCategory,
      _ => '',
    };
    final scaffold = ScaffoldMessenger.of(context);
    scaffold.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: l.hintDismiss,
          onPressed: () async {
            await ref.read(appSettingsProvider.notifier).markHintShown(key);
          },
        ),
      ),
    );
    ref.read(appSettingsProvider.notifier).markHintShown(key);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final settings = ref.watch(appSettingsProvider);

    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    final greeting = _greeting(l, now, settings.userDisplayName);

    return Scaffold(
      appBar: AppBar(
        title: Text(greeting),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => _showComingSoon(context, l.insightsTitle),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(transactionRepositoryProvider);
            ref.invalidate(statsRepositoryProvider);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              _BalanceAndBudgetCard(
                salaryDay: settings.salaryDay,
                currency: settings.baseCurrency,
                monthStart: monthStart,
                monthEnd: monthEnd,
              ),
              const SizedBox(height: 16),
              _QuickAddGrid(currency: settings.baseCurrency),
              const SizedBox(height: 16),
              _UpcomingBillsCard(currency: settings.baseCurrency),
              const SizedBox(height: 16),
              _InsightsPreviewCard(),
              const SizedBox(height: 16),
              _TopCategoriesCard(
                monthStart: monthStart,
                monthEnd: monthEnd,
                currency: settings.baseCurrency,
              ),
              const SizedBox(height: 16),
              _RecentTransactionsCard(currency: settings.baseCurrency),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddTransaction(context),
        icon: const Icon(Icons.add),
        label: Text(l.homeQuickAdd),
      ),
    );
  }

  String _greeting(AppLocalizations l, DateTime now, String? userName) {
    // Primary greeting: "Hello, {name}" or "أهلاً، {name}" if a name
    // is configured. This is the product-preferred greeting — it feels
    // more personal than a time-based "Good morning".
    final name = userName?.trim();
    if (name != null && name.isNotEmpty) {
      return '${l.greetingHello}, $name';
    }
    // Fallback: time-based greeting with sensible ranges.
    //   05:00–11:59 → Good morning
    //   12:00–16:59 → Good afternoon
    //   17:00–21:59 → Good evening
    //   22:00–04:59 → Good evening (neutral, avoids "good night" which
    //                  implies leaving — a finance app should stay welcoming)
    final hour = now.hour;
    if (hour >= 5 && hour < 12) {
      return l.homeGreetingMorning;
    }
    if (hour >= 12 && hour < 17) {
      return l.homeGreetingAfternoon;
    }
    // 17:00–04:59 → evening
    return l.homeGreetingEvening;
  }

  Future<void> _openAddTransaction(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const TransactionEditSheet(),
    );
  }

  void _showComingSoon(BuildContext context, String title) {
    final l = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$title — ${l.commonLoading}')),
    );
  }
}

// ---------------------------------------------------------------------------
// Balance + payday countdown card
// ---------------------------------------------------------------------------

class _BalanceAndBudgetCard extends ConsumerWidget {
  const _BalanceAndBudgetCard({
    required this.salaryDay,
    required this.currency,
    required this.monthStart,
    required this.monthEnd,
  });
  final int salaryDay;
  final String currency;
  final DateTime monthStart;
  final DateTime monthEnd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final stats = ref.watch(statsRepositoryProvider).maybeWhen(
          data: (s) => s,
          orElse: () => null,
        );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FutureBuilder<double>(
              future: stats?.totalIncome(monthStart, monthEnd),
              builder: (context, snap) {
                final income = snap.data ?? 0;
                return _StatRow(
                  label: l.homeIncomeThisMonth,
                  value: Format.money(income, currency),
                  color: FinlensColors.income,
                );
              },
            ),
            const SizedBox(height: 8),
            FutureBuilder<double>(
              future: stats?.totalSpent(monthStart, monthEnd),
              builder: (context, snap) {
                final spent = snap.data ?? 0;
                return _StatRow(
                  label: l.homeSpentThisMonth,
                  value: Format.money(spent, currency),
                  color: FinlensColors.expense,
                );
              },
            ),
            const Divider(height: 32),
            _PaydayBudgetRow(
              salaryDay: salaryDay,
              currency: currency,
              monthStart: monthStart,
              monthEnd: monthEnd,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: theme.textTheme.bodyMedium),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(color: color),
        ),
      ],
    );
  }
}

class _PaydayBudgetRow extends ConsumerWidget {
  const _PaydayBudgetRow({
    required this.salaryDay,
    required this.currency,
    required this.monthStart,
    required this.monthEnd,
  });
  final int salaryDay;
  final String currency;
  final DateTime monthStart;
  final DateTime monthEnd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final now = DateTime.now();
    final daysUntil = DaysUntilPayday().call(salaryDay: salaryDay, from: now);
    return FutureBuilder<({double spent, double income})>(
      future: _computeBalance(ref),
      builder: (context, snap) {
        final income = snap.data?.income ?? 0;
        final spent = snap.data?.spent ?? 0;
        final balance = income - spent;
        final dailyBudget = DailyBudgetRemaining().call(
          currentBalance: balance,
          daysUntilPayday: daysUntil,
        );
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.homeDaysUntilPayday(daysUntil),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    Format.moneyShort(dailyBudget, currency),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  Text(
                    l.homeDailyBudget,
                    style: theme.textTheme.labelSmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    l.homeBalance,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    Format.money(balance, currency),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: balance >= 0 ? FinlensColors.income : FinlensColors.expense,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Future<({double spent, double income})> _computeBalance(WidgetRef ref) async {
    final stats = await ref.read(statsRepositoryProvider.future);
    final spent = await stats.totalSpent(monthStart, monthEnd);
    final income = await stats.totalIncome(monthStart, monthEnd);
    return (spent: spent, income: income);
  }
}

// ---------------------------------------------------------------------------
// Quick-add grid — tap a category to add quickly
// ---------------------------------------------------------------------------

class _QuickAddGrid extends ConsumerWidget {
  const _QuickAddGrid({required this.currency});
  final String currency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 4, bottom: 8),
          child: Text(l.homeQuickAdd, style: theme.textTheme.titleMedium),
        ),
        SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: PredefinedCategories.expenses.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final c = PredefinedCategories.expenses[i];
              final label = _categoryLabel(l, c.id);
              return _QuickCategoryChip(
                label: label,
                color: c.colorValue,
                icon: c.icon,
                onTap: () async {
                  final tx = Transaction(
                    id: '',
                    type: TransactionType.expense,
                    amount: 0,
                    currency: currency,
                    amountInBase: 0,
                    exchangeRateAtTime: 1,
                    categoryId: c.id,
                    date: DateTime.now(),
                  );
                  await showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    useSafeArea: true,
                    builder: (_) => TransactionEditSheet(prefill: tx),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
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
      'other' => l.txCategoryOther,
      _ => id,
    };
  }
}

class _QuickCategoryChip extends StatelessWidget {
  const _QuickCategoryChip({
    required this.label,
    required this.color,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 80,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Upcoming bills card
// ---------------------------------------------------------------------------

class _UpcomingBillsCard extends ConsumerWidget {
  const _UpcomingBillsCard({required this.currency});
  final String currency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final txRepoAsync = ref.watch(transactionRepositoryProvider);
    return txRepoAsync.when(
      loading: () => const Card(
        child: ListTile(title: Text('…')),
      ),
      error: (e, _) => Card(child: ListTile(title: Text(l.commonError))),
      data: (repo) {
        return FutureBuilder(
          future: repo.getRecurring(),
          builder: (context, snap) {
            if (!snap.hasData) {
              return Card(child: ListTile(title: Text(l.commonLoading)));
            }
            final txs = snap.data!
                .map((t) => (
                      tx: t,
                      due: NextRecurringDueDate().call(t),
                    ))
                .toList()
              ..sort((a, b) => a.due.compareTo(b.due));
            if (txs.isEmpty) {
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.event_available_outlined),
                  title: Text(l.homeNoUpcomingBills),
                ),
              );
            }
            return Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Text(l.homeUpcomingBills, style: theme.textTheme.titleMedium),
                  ),
                  ...txs.take(3).map((entry) {
                    final days = entry.due.difference(DateTime.now()).inDays;
                    return ListTile(
                      leading: const Icon(Icons.event_outlined),
                      title: Text(Format.money(entry.tx.amountInBase, currency)),
                      subtitle: Text(
                        '${_categoryLabel(l, entry.tx.categoryId)} • ${l.billsDueIn(days)}',
                      ),
                      trailing: Text(
                        DateFormat('MMM d').format(entry.due),
                        style: theme.textTheme.bodySmall,
                      ),
                    );
                  }),
                ],
              ),
            );
          },
        );
      },
    );
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

// ---------------------------------------------------------------------------
// Insights preview card — shows last generated insight or "generate" button
// ---------------------------------------------------------------------------

class _InsightsPreviewCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final insightRepoAsync = ref.watch(insightRepositoryProvider);
    final now = DateTime.now();
    final monthKey =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome_outlined, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(l.insightsTitle, style: theme.textTheme.titleMedium),
                const Spacer(),
                TextButton(
                  onPressed: () async {
                    final service = await ref.read(insightServiceProvider.future);
                    await service.generate(
                      monthStart: DateTime(now.year, now.month, 1),
                      locale: Localizations.localeOf(context).languageCode,
                    );
                  },
                  child: Text(l.insightsGenerate),
                ),
              ],
            ),
            const SizedBox(height: 8),
            insightRepoAsync.when(
              loading: () => Text(l.commonLoading),
              error: (e, _) => Text(l.insightsError),
              data: (repo) {
                return FutureBuilder(
                  future: repo.getForMonth(monthKey),
                  builder: (context, snap) {
                    if (snap.connectionState != ConnectionState.done) {
                      return Text(l.commonLoading);
                    }
                    final insight = snap.data;
                    if (insight == null) {
                      return Text(
                        l.insightsNever,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      );
                    }
                    return Text(insight.text, style: theme.textTheme.bodyMedium);
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Top categories card — mini bar chart
// ---------------------------------------------------------------------------

class _TopCategoriesCard extends ConsumerWidget {
  const _TopCategoriesCard({
    required this.monthStart,
    required this.monthEnd,
    required this.currency,
  });
  final DateTime monthStart;
  final DateTime monthEnd;
  final String currency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final stats = ref.watch(statsRepositoryProvider).maybeWhen(
          data: (s) => s,
          orElse: () => null,
        );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l.homeHighestSpendingCategory, style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 120,
              child: stats == null
                  ? const Center(child: CircularProgressIndicator())
                  : FutureBuilder<Map<String, double>>(
                      future: stats.spentByCategory(monthStart, monthEnd,
                          type: TransactionType.expense),
                      builder: (context, snap) {
                        if (!snap.hasData) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        final data = snap.data!;
                        final sorted = data.entries.toList()
                          ..sort((a, b) => b.value.compareTo(a.value));
                        final top = sorted.take(5).toList();
                        if (top.isEmpty) {
                          return Center(
                            child: Text(
                              l.homeNoTransactionsYet,
                              style: theme.textTheme.bodySmall,
                              textAlign: TextAlign.center,
                            ),
                          );
                        }
                        final maxVal = top.first.value;
                        return BarChart(
                          BarChartData(
                            alignment: BarChartAlignment.spaceAround,
                            maxY: maxVal * 1.1,
                            barTouchData: BarTouchData(
                              touchTooltipData: BarTouchTooltipData(
                                getTooltipItem: (group, _, rod, __) {
                                  return BarTooltipItem(
                                    Format.moneyShort(rod.toY, currency),
                                    theme.textTheme.bodySmall!.copyWith(
                                      color: theme.colorScheme.onPrimary,
                                    ),
                                  );
                                },
                              ),
                            ),
                            titlesData: FlTitlesData(
                              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (v, _) {
                                    final i = v.toInt();
                                    if (i < 0 || i >= top.length) return const SizedBox.shrink();
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        top[i].key[0].toUpperCase(),
                                        style: theme.textTheme.labelSmall,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            gridData: const FlGridData(show: false),
                            borderData: FlBorderData(show: false),
                            barGroups: top
                                .asMap()
                                .entries
                                .map(
                                  (e) => BarChartGroupData(
                                    x: e.key,
                                    barRods: [
                                      BarChartRodData(
                                        toY: e.value.value,
                                        color: FinlensColors.primary,
                                        width: 16,
                                        borderRadius: const BorderRadius.only(
                                          topLeft: Radius.circular(4),
                                          topRight: Radius.circular(4),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                                .toList(),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Recent transactions
// ---------------------------------------------------------------------------

class _RecentTransactionsCard extends ConsumerWidget {
  const _RecentTransactionsCard({required this.currency});
  final String currency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final txAsync = ref.watch(transactionRepositoryProvider);
    return txAsync.when(
      loading: () => const Card(child: ListTile(title: Text('…'))),
      error: (e, _) => Card(child: ListTile(title: Text(l.commonError))),
      data: (repo) {
        return FutureBuilder(
          future: repo.getByDateRange(
            DateTime.now().subtract(const Duration(days: 30)),
            DateTime.now().add(const Duration(days: 1)),
          ),
          builder: (context, snap) {
            if (!snap.hasData) {
              return Card(child: ListTile(title: Text(l.commonLoading)));
            }
            final list = snap.data!;
            if (list.isEmpty) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Icon(Icons.receipt_long_outlined,
                          size: 36, color: theme.colorScheme.outline),
                      const SizedBox(height: 8),
                      Text(l.homeNoTransactionsYet,
                          style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ),
              );
            }
            final recent = (list..sort((a, b) => b.date.compareTo(a.date))).take(5).toList();
            return Card(
              child: Column(
                children: recent
                    .map((t) => ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                (PredefinedCategories.byId(t.categoryId)?.colorValue ??
                                        FinlensColors.neutral)
                                    .withValues(alpha: 0.15),
                            child: Icon(
                              PredefinedCategories.byId(t.categoryId)?.icon ??
                                  Icons.category,
                              color:
                                  PredefinedCategories.byId(t.categoryId)?.colorValue ??
                                      FinlensColors.neutral,
                              size: 20,
                            ),
                          ),
                          title: Text(Format.money(t.amountInBase, currency)),
                          subtitle: Text(Format.date(t.date)),
                          trailing: Text(
                            t.type == TransactionType.income
                                ? '+${Format.moneyShort(t.amountInBase, currency)}'
                                : '-${Format.moneyShort(t.amountInBase, currency)}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: t.type == TransactionType.income
                                  ? FinlensColors.income
                                  : FinlensColors.expense,
                            ),
                          ),
                        ))
                    .toList(),
              ),
            );
          },
        );
      },
    );
  }
}
