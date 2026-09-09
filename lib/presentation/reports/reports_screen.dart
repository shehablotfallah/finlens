import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/categories.dart';
import '../../core/theme/finlens_theme.dart';
import '../../core/utils/format.dart';
import '../../domain/entities/transaction.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../app/providers.dart';

enum _Range { daily, monthly, yearly }

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  _Range _range = _Range.monthly;

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
      'investment_return' => l.txCategoryInvestmentReturn,
      'other' => l.txCategoryOther,
      _ => id,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final settings = ref.watch(appSettingsProvider);
    final stats = ref.watch(statsRepositoryProvider).maybeWhen(
          data: (s) => s,
          orElse: () => null,
        );

    final now = DateTime.now();
    final DateTime start;
    final DateTime end;
    switch (_range) {
      case _Range.daily:
        start = DateTime(now.year, now.month, now.day);
        end = start.add(const Duration(days: 1));
      case _Range.monthly:
        start = DateTime(now.year, now.month, 1);
        end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
      case _Range.yearly:
        start = DateTime(now.year, 1, 1);
        end = DateTime(now.year, 12, 31, 23, 59, 59);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l.reportsTitle),
        actions: [
          IconButton(
            tooltip: l.reportsExportPdf,
            onPressed: () async {
              final txs = await (await ref
                      .read(transactionRepositoryProvider.future))
                  .getByDateRange(start, end);
              final spent = await stats?.totalSpent(start, end) ?? 0;
              final income = await stats?.totalIncome(start, end) ?? 0;
              final byCat = await stats?.spentByCategory(start, end,
                      type: TransactionType.expense) ??
                  <String, double>{};
              final exporter = ref.read(exportServiceProvider);
              final file = await exporter.exportReportPdf(
                title: l.reportsTitle,
                rangeStart: start,
                rangeEnd: end,
                totalSpent: spent,
                totalIncome: income,
                spentByCategory: byCat,
                transactions: txs,
                currency: settings.baseCurrency,
                generatedBy:
                    '${l.developedBy} • ${l.supportEmail} • ${l.socialHandle}',
              );
              if (context.mounted) {
                await exporter.shareFile(file, subject: l.reportsTitle);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l.reportsSharedTo)),
                );
              }
            },
            icon: const Icon(LucideIcons.fileText),
          ),
          IconButton(
            tooltip: l.reportsExportCsv,
            onPressed: () async {
              final txs = await (await ref
                      .read(transactionRepositoryProvider.future))
                  .getByDateRange(start, end);
              final exporter = ref.read(exportServiceProvider);
              final file = await exporter.exportTransactionsCsv(
                transactions: txs,
                currency: settings.baseCurrency,
              );
              if (context.mounted) {
                await exporter.shareFile(file, subject: l.reportsTitle);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l.reportsSharedTo)),
                );
              }
            },
            icon: const Icon(LucideIcons.table),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(statsRepositoryProvider);
            ref.invalidate(transactionRepositoryProvider);
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Period selector
              SegmentedButton<_Range>(
                segments: [
                  ButtonSegment(
                      value: _Range.daily,
                      label: Text(l.reportsRangeDaily)),
                  ButtonSegment(
                      value: _Range.monthly,
                      label: Text(l.reportsRangeMonthly)),
                  ButtonSegment(
                      value: _Range.yearly,
                      label: Text(l.reportsRangeYearly)),
                ],
                selected: {_range},
                onSelectionChanged: (s) => setState(() => _range = s.first),
              ),
              const SizedBox(height: 16),

              // Financial Summary
              _SummaryCard(
                stats: stats,
                start: start,
                end: end,
                currency: settings.baseCurrency,
                categoryLabelFn: _categoryLabel,
              ),
              const SizedBox(height: 16),

              // Spending Over Time
              _OverTimeChart(
                stats: stats,
                rangeStart: start,
                rangeEnd: end,
                currency: settings.baseCurrency,
              ),
              const SizedBox(height: 16),

              // Top Spending Categories (ranked horizontal bars)
              _RankedCategoriesCard(
                stats: stats,
                rangeStart: start,
                rangeEnd: end,
                currency: settings.baseCurrency,
                categoryLabelFn: _categoryLabel,
              ),
              const SizedBox(height: 16),

              // Income Breakdown
              _IncomeBreakdownCard(
                stats: stats,
                rangeStart: start,
                rangeEnd: end,
                currency: settings.baseCurrency,
                categoryLabelFn: _categoryLabel,
              ),
              const SizedBox(height: 16),

              // Statistics
              _StatisticsCard(
                stats: stats,
                rangeStart: start,
                rangeEnd: end,
                currency: settings.baseCurrency,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Summary Card
// ---------------------------------------------------------------------------
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.stats,
    required this.start,
    required this.end,
    required this.currency,
    required this.categoryLabelFn,
  });
  final dynamic stats;
  final DateTime start;
  final DateTime end;
  final String currency;
  final String Function(AppLocalizations, String) categoryLabelFn;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.reportsSummary, style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            FutureBuilder<double>(
              future: stats?.totalIncome(start, end) ?? Future.value(0),
              builder: (context, snap) {
                return _SummaryRow(
                  label: l.reportsTotalIncome,
                  value: Format.money(snap.data ?? 0, currency),
                  color: FinlensColors.income,
                  icon: LucideIcons.arrowDownLeft,
                );
              },
            ),
            const SizedBox(height: 8),
            FutureBuilder<double>(
              future: stats?.totalSpent(start, end) ?? Future.value(0),
              builder: (context, snap) {
                return _SummaryRow(
                  label: l.reportsTotalSpent,
                  value: Format.money(snap.data ?? 0, currency),
                  color: FinlensColors.expense,
                  icon: LucideIcons.arrowUpRight,
                );
              },
            ),
            const Divider(height: 24),
            FutureBuilder<List<double>>(
              future: _getBoth(stats, start, end),
              builder: (context, snap) {
                final income = snap.data?[0] ?? 0.0;
                final spent = snap.data?[1] ?? 0.0;
                final net = income - spent;
                return _SummaryRow(
                  label: l.reportsNetBalance,
                  value: Format.money(net, currency),
                  color: net >= 0 ? FinlensColors.income : FinlensColors.expense,
                  icon: LucideIcons.wallet,
                  isBold: true,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<List<double>> _getBoth(
      dynamic stats, DateTime start, DateTime end) async {
    final income = await stats?.totalIncome(start, end) ?? 0.0;
    final spent = await stats?.totalSpent(start, end) ?? 0.0;
    return [income, spent];
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    this.isBold = false,
  });
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  final bool isBold;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: isBold
                ? theme.textTheme.titleSmall
                : theme.textTheme.bodyMedium,
          ),
        ),
        Text(
          value,
          style: (isBold
                  ? theme.textTheme.titleMedium
                  : theme.textTheme.bodyLarge)
              ?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Over-Time Chart (Line chart with interactive tooltip)
// ---------------------------------------------------------------------------
class _OverTimeChart extends StatefulWidget {
  const _OverTimeChart({
    required this.stats,
    required this.rangeStart,
    required this.rangeEnd,
    required this.currency,
  });
  final dynamic stats;
  final DateTime rangeStart;
  final DateTime rangeEnd;
  final String currency;

  @override
  State<_OverTimeChart> createState() => _OverTimeChartState();
}

class _OverTimeChartState extends State<_OverTimeChart> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.reportsSpendingOverTime,
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: widget.stats == null
                  ? const Center(child: CircularProgressIndicator())
                  : FutureBuilder<List<({DateTime date, double total})>>(
                      future:
                          widget.stats.dailyTotals(widget.rangeStart, widget.rangeEnd),
                      builder: (context, snap) {
                        if (!snap.hasData) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        final data = snap.data!;
                        if (data.isEmpty) {
                          return Center(child: Text(l.reportsNoData));
                        }
                        final maxVal = data
                            .map((e) => e.total)
                            .fold<double>(0, (a, b) => a > b ? a : b);
                        if (maxVal == 0) {
                          return Center(child: Text(l.reportsNoData));
                        }
                        // Show every Nth label depending on data length
                        final labelInterval = (data.length / 6).ceil().clamp(1, data.length);
                        return LineChart(
                          LineChartData(
                            gridData: FlGridData(
                              show: true,
                              drawVerticalLine: false,
                              horizontalInterval: maxVal / 4,
                              getDrawingHorizontalLine: (value) => FlLine(
                                color: theme.colorScheme.outlineVariant
                                    .withValues(alpha: 0.3),
                                strokeWidth: 1,
                              ),
                            ),
                            borderData: FlBorderData(show: false),
                            lineTouchData: LineTouchData(
                              touchTooltipData: LineTouchTooltipData(
                                getTooltipItems: (touchedSpots) {
                                  return touchedSpots.map((spot) {
                                    final i = spot.spotIndex;
                                    if (i < 0 || i >= data.length) return null;
                                    final dateStr =
                                        DateFormat('MMM d').format(data[i].date);
                                    return LineTooltipItem(
                                      '$dateStr\n${Format.money(data[i].total, widget.currency)}',
                                      theme.textTheme.bodySmall!.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    );
                                  }).toList();
                                },
                              ),
                            ),
                            titlesData: FlTitlesData(
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 50,
                                  interval: maxVal / 4,
                                  getTitlesWidget: (v, _) {
                                    return Padding(
                                      padding: const EdgeInsetsDirectional.only(end: 4),
                                      child: Text(
                                        Format.moneyShort(v, widget.currency),
                                        style: theme.textTheme.labelSmall,
                                      ),
                                    );
                                  },
                                ),
                              ),
                              rightTitles: const AxisTitles(
                                  sideTitles:
                                      SideTitles(showTitles: false)),
                              topTitles: const AxisTitles(
                                  sideTitles:
                                      SideTitles(showTitles: false)),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 30,
                                  interval: labelInterval.toDouble(),
                                  getTitlesWidget: (v, _) {
                                    final i = v.toInt();
                                    if (i < 0 || i >= data.length) {
                                      return const SizedBox.shrink();
                                    }
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        DateFormat('d').format(data[i].date),
                                        style: theme.textTheme.labelSmall,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            lineBarsData: [
                              LineChartBarData(
                                isCurved: false,
                                color: theme.colorScheme.primary,
                                barWidth: 2.5,
                                dotData: FlDotData(
                                  show: true,
                                  getDotPainter: (spot, percent, barData, index) {
                                    return FlDotCirclePainter(
                                      radius: index == _touchedIndex ? 5 : 2,
                                      color: theme.colorScheme.primary,
                                      strokeWidth: 0,
                                    );
                                  },
                                ),
                                belowBarData: BarAreaData(
                                  show: true,
                                  color: theme.colorScheme.primary
                                      .withValues(alpha: 0.1),
                                ),
                                spots: data
                                    .asMap()
                                    .entries
                                    .map((e) => FlSpot(
                                        e.key.toDouble(), e.value.total))
                                    .toList(),
                              ),
                            ],
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
// Ranked Categories (horizontal bar visualization)
// ---------------------------------------------------------------------------
class _RankedCategoriesCard extends StatelessWidget {
  const _RankedCategoriesCard({
    required this.stats,
    required this.rangeStart,
    required this.rangeEnd,
    required this.currency,
    required this.categoryLabelFn,
  });
  final dynamic stats;
  final DateTime rangeStart;
  final DateTime rangeEnd;
  final String currency;
  final String Function(AppLocalizations, String) categoryLabelFn;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.reportsTopCategories, style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            stats == null
                ? const Center(child: CircularProgressIndicator())
                : FutureBuilder<Map<String, double>>(
                    future: stats.spentByCategory(rangeStart, rangeEnd,
                        type: TransactionType.expense),
                    builder: (context, snap) {
                      if (!snap.hasData) {
                        return const Center(
                            child: CircularProgressIndicator());
                      }
                      final data = snap.data!;
                      final sorted = data.entries.toList()
                        ..sort((a, b) => b.value.compareTo(a.value));
                      if (sorted.isEmpty) {
                        return Center(child: Text(l.reportsNoData));
                      }
                      final totalSpent = sorted.fold<double>(
                          0, (sum, e) => sum + e.value);
                      return Column(
                        children: sorted.map((e) {
                          final cat = PredefinedCategories.byId(e.key);
                          final color = cat?.colorValue ?? FinlensColors.neutral;
                          final pct = totalSpent > 0
                              ? (e.value / totalSpent * 100)
                              : 0.0;
                          return _RankedCategoryRow(
                            icon: cat?.icon ?? LucideIcons.circle,
                            iconColor: color,
                            name: categoryLabelFn(l, e.key),
                            amount: Format.money(e.value, currency),
                            percentage: '${pct.toStringAsFixed(1)}%',
                            progress: totalSpent > 0
                                ? e.value / totalSpent
                                : 0.0,
                            progressColor: color,
                          );
                        }).toList(),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }
}

class _RankedCategoryRow extends StatelessWidget {
  const _RankedCategoryRow({
    required this.icon,
    required this.iconColor,
    required this.name,
    required this.amount,
    required this.percentage,
    required this.progress,
    required this.progressColor,
  });
  final IconData icon;
  final Color iconColor;
  final String name;
  final String amount;
  final String percentage;
  final double progress;
  final Color progressColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Text(
                      amount,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress.clamp(0.0, 1.0),
                          minHeight: 6,
                          backgroundColor: theme.colorScheme.surfaceContainerHighest,
                          valueColor: AlwaysStoppedAnimation(progressColor),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      percentage,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Income Breakdown
// ---------------------------------------------------------------------------
class _IncomeBreakdownCard extends StatelessWidget {
  const _IncomeBreakdownCard({
    required this.stats,
    required this.rangeStart,
    required this.rangeEnd,
    required this.currency,
    required this.categoryLabelFn,
  });
  final dynamic stats;
  final DateTime rangeStart;
  final DateTime rangeEnd;
  final String currency;
  final String Function(AppLocalizations, String) categoryLabelFn;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.reportsIncomeBreakdown,
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            stats == null
                ? const Center(child: CircularProgressIndicator())
                : FutureBuilder<Map<String, double>>(
                    future: stats.spentByCategory(rangeStart, rangeEnd,
                        type: TransactionType.income),
                    builder: (context, snap) {
                      if (!snap.hasData) {
                        return const Center(
                            child: CircularProgressIndicator());
                      }
                      final data = snap.data!;
                      final sorted = data.entries.toList()
                        ..sort((a, b) => b.value.compareTo(a.value));
                      if (sorted.isEmpty) {
                        return Center(child: Text(l.reportsNoIncome));
                      }
                      final totalIncome = sorted.fold<double>(
                          0, (sum, e) => sum + e.value);
                      return Column(
                        children: sorted.map((e) {
                          final cat = PredefinedCategories.byId(e.key);
                          final color = cat?.colorValue ?? FinlensColors.neutral;
                          final pct = totalIncome > 0
                              ? (e.value / totalIncome * 100)
                              : 0.0;
                          return _RankedCategoryRow(
                            icon: cat?.icon ?? LucideIcons.circle,
                            iconColor: color,
                            name: categoryLabelFn(l, e.key),
                            amount: Format.money(e.value, currency),
                            percentage: '${pct.toStringAsFixed(1)}%',
                            progress: totalIncome > 0
                                ? e.value / totalIncome
                                : 0.0,
                            progressColor: color,
                          );
                        }).toList(),
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
// Statistics Card
// ---------------------------------------------------------------------------
class _StatisticsCard extends StatelessWidget {
  const _StatisticsCard({
    required this.stats,
    required this.rangeStart,
    required this.rangeEnd,
    required this.currency,
  });
  final dynamic stats;
  final DateTime rangeStart;
  final DateTime rangeEnd;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.reportsStatistics, style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            FutureBuilder<List<double>>(
              future: _getBoth(stats, rangeStart, rangeEnd),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final spent = snap.data![0];
                final income = snap.data![1];
                final net = income - spent;
                final savingsRate =
                    income > 0 ? ((net / income) * 100).round() : 0;

                return Column(
                  children: [
                    _StatTile(
                      label: l.reportsNetBalance,
                      value: Format.money(net, currency),
                      icon: LucideIcons.wallet,
                      color: net >= 0
                          ? FinlensColors.income
                          : FinlensColors.expense,
                    ),
                    _StatTile(
                      label: l.reportsSavingsRate,
                      value: '$savingsRate%',
                      icon: LucideIcons.piggyBank,
                      color: savingsRate >= 0
                          ? FinlensColors.income
                          : FinlensColors.expense,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<List<double>> _getBoth(
      dynamic stats, DateTime start, DateTime end) async {
    final spent = await stats?.totalSpent(start, end) ?? 0.0;
    final income = await stats?.totalIncome(start, end) ?? 0.0;
    return [spent, income];
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label, style: theme.textTheme.bodyMedium),
          ),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
