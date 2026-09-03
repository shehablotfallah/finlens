import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = ref.read(appSettingsProvider);
      final l = AppLocalizations.of(context);
      if (!settings.hintsShown.contains(AppConstants.hintPullToRefresh)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l.hintPullToRefresh),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: l.hintDismiss,
              onPressed: () {
                ref
                    .read(appSettingsProvider.notifier)
                    .markHintShown(AppConstants.hintPullToRefresh);
              },
            ),
          ),
        );
        ref
            .read(appSettingsProvider.notifier)
            .markHintShown(AppConstants.hintPullToRefresh);
      }
    });
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
        break;
      case _Range.monthly:
        start = DateTime(now.year, now.month, 1);
        end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
        break;
      case _Range.yearly:
        start = DateTime(now.year, 1, 1);
        end = DateTime(now.year, 12, 31, 23, 59, 59);
        break;
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
            icon: const Icon(Icons.picture_as_pdf_outlined),
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
            icon: const Icon(Icons.table_view_outlined),
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
              SegmentedButton<_Range>(
                segments: [
                  ButtonSegment(value: _Range.daily, label: Text(l.reportsRangeDaily)),
                  ButtonSegment(value: _Range.monthly, label: Text(l.reportsRangeMonthly)),
                  ButtonSegment(value: _Range.yearly, label: Text(l.reportsRangeYearly)),
                ],
                selected: {_range},
                onSelectionChanged: (s) => setState(() => _range = s.first),
              ),
              const SizedBox(height: 16),
              _SummaryRow(
                futureSpent: stats?.totalSpent(start, end) ?? Future.value(0),
                futureIncome: stats?.totalIncome(start, end) ?? Future.value(0),
                currency: settings.baseCurrency,
              ),
              const SizedBox(height: 16),
              _OverTimeCard(
                rangeStart: start,
                rangeEnd: end,
                range: _range,
                currency: settings.baseCurrency,
              ),
              const SizedBox(height: 16),
              _TopCategoriesCard(
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

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.futureSpent,
    required this.futureIncome,
    required this.currency,
  });
  final Future<double> futureSpent;
  final Future<double> futureIncome;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.reportsTotalSpent, style: theme.textTheme.labelMedium),
                  const SizedBox(height: 4),
                  FutureBuilder<double>(
                    future: futureSpent,
                    builder: (context, snap) {
                      return Text(
                        Format.money(snap.data ?? 0, currency),
                        style: theme.textTheme.headlineSmall
                            ?.copyWith(color: FinlensColors.expense),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.reportsTotalIncome, style: theme.textTheme.labelMedium),
                  const SizedBox(height: 4),
                  FutureBuilder<double>(
                    future: futureIncome,
                    builder: (context, snap) {
                      return Text(
                        Format.money(snap.data ?? 0, currency),
                        style: theme.textTheme.headlineSmall
                            ?.copyWith(color: FinlensColors.income),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _OverTimeCard extends ConsumerWidget {
  const _OverTimeCard({
    required this.rangeStart,
    required this.rangeEnd,
    required this.range,
    required this.currency,
  });
  final DateTime rangeStart;
  final DateTime rangeEnd;
  final _Range range;
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
            Text(l.reportsOverTime, style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            SizedBox(
              height: 180,
              child: stats == null
                  ? const Center(child: CircularProgressIndicator())
                  : FutureBuilder<List<({DateTime date, double total})>>(
                      future: stats.dailyTotals(rangeStart, rangeEnd),
                      builder: (context, snap) {
                        if (!snap.hasData) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        final data = snap.data!;
                        if (data.isEmpty) {
                          return Center(child: Text(l.reportsNoData));
                        }
                        final maxVal =
                            data.map((e) => e.total).fold<double>(0, (a, b) => a > b ? a : b);
                        if (maxVal == 0) {
                          return Center(child: Text(l.reportsNoData));
                        }
                        return LineChart(
                          LineChartData(
                            gridData: const FlGridData(show: false),
                            borderData: FlBorderData(show: false),
                            titlesData: FlTitlesData(
                              leftTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false)),
                              rightTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false)),
                              topTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false)),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  interval: (data.length / 4).ceilToDouble().clamp(1, double.infinity),
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
                                isCurved: true,
                                color: theme.colorScheme.primary,
                                barWidth: 2,
                                dotData: const FlDotData(show: false),
                                spots: data
                                    .asMap()
                                    .entries
                                    .map((e) =>
                                        FlSpot(e.key.toDouble(), e.value.total))
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

class _TopCategoriesCard extends ConsumerWidget {
  const _TopCategoriesCard({
    required this.rangeStart,
    required this.rangeEnd,
    required this.currency,
  });
  final DateTime rangeStart;
  final DateTime rangeEnd;
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
            Text(l.reportsTopCategories, style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: stats == null
                  ? const Center(child: CircularProgressIndicator())
                  : FutureBuilder<Map<String, double>>(
                      future: stats.spentByCategory(rangeStart, rangeEnd,
                          type: TransactionType.expense),
                      builder: (context, snap) {
                        if (!snap.hasData) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        final data = snap.data!;
                        final sorted = data.entries.toList()
                          ..sort((a, b) => b.value.compareTo(a.value));
                        if (sorted.isEmpty) {
                          return Center(child: Text(l.reportsNoData));
                        }
                        return PieChart(
                          PieChartData(
                            sections: sorted
                                .map((e) {
                                  final cat = PredefinedCategories.byId(e.key);
                                  return PieChartSectionData(
                                    value: e.value,
                                    color: cat?.colorValue ?? FinlensColors.neutral,
                                    radius: 64,
                                    title:
                                        '${Format.moneyShort(e.value, currency)}',
                                    titleStyle: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  );
                                })
                                .toList(),
                            sectionsSpace: 2,
                            centerSpaceRadius: 0,
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
