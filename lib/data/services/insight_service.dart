import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../domain/entities/transaction.dart';
import '../../domain/repositories/repositories.dart';
import '../../domain/usecases/usecases.dart';

/// Swappable abstraction for the LLM provider used by [InsightServiceImpl].
///
/// v1 ships a [DummyLocalInsightProvider] that never makes a network call —
/// it synthesises a plausible insight locally so the feature works
/// out-of-the-box without any API key. To enable a real LLM, plug in
/// [OpenAiCompatibleInsightProvider] with your endpoint + key (read from
/// user-supplied configuration only — never baked into the binary).
abstract class LlmInsightProvider {
  /// Sends aggregated stats to the LLM and receives a single-paragraph insight.
  ///
  /// IMPORTANT: never send individual transactions — only the aggregated
  /// stats object that this method receives.
  Future<String> generateInsight({
    required MonthlyAggregatedStats stats,
    required String locale,
    required String baseCurrency,
  });
}

/// Insight service implementation.
///
/// Orchestrates:
///   1. Aggregate stats for the given month from [StatsRepository].
///   2. Optionally enrich with 3-month averages.
///   3. Persist the result via [InsightRepository].
class InsightServiceImpl implements InsightService {
  InsightServiceImpl({
    required this.statsRepository,
    required this.insightRepository,
    required this.llmProvider,
  });

  final StatsRepository statsRepository;
  final InsightRepository insightRepository;
  final LlmInsightProvider llmProvider;

  @override
  Future<MonthlyInsight> generate({
    required DateTime monthStart,
    required String locale,
  }) async {
    final monthEnd = DateTime(monthStart.year, monthStart.month + 1, 0, 23, 59, 59);
    final spent = await statsRepository.totalSpent(monthStart, monthEnd);
    final income = await statsRepository.totalIncome(monthStart, monthEnd);
    final catTotals = await statsRepository.spentByCategory(monthStart, monthEnd,
        type: TransactionType.expense);
    final threeMonthAvg = await statsRepository.threeMonthAverageByCategory(monthStart);
    final dailyAvg = spent / DateTime(monthStart.year, monthStart.month + 1, 0).day;

    final stats = MonthlyAggregatedStats(
      monthKey: _monthKey(monthStart),
      totalSpent: spent,
      totalIncome: income,
      currency: 'EGP',
      categoryTotals: catTotals,
      topCategoryIds: (catTotals.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value)))
          .map((e) => e.key)
          .toList(),
      dailyAverage: dailyAvg,
      threeMonthAverageByCategory: threeMonthAvg,
      txCount: catTotals.length,
    );

    final text = await llmProvider.generateInsight(
      stats: stats,
      locale: locale,
      baseCurrency: stats.currency,
    );

    final insight = MonthlyInsight(
      id: '${stats.monthKey}-${DateTime.now().millisecondsSinceEpoch}',
      monthKey: stats.monthKey,
      text: text,
      generatedAt: DateTime.now(),
      locale: locale,
    );
    await insightRepository.save(insight);
    return insight;
  }

  String _monthKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';
}

/// Default provider used in v1 — generates a useful insight locally
/// without any network call. This keeps the app fully private by default
/// and gives users immediate value even before they configure an LLM key.
///
/// To enable real LLM-driven insights, swap this with
/// [OpenAiCompatibleInsightProvider] in main.dart.
class DummyLocalInsightProvider implements LlmInsightProvider {
  DummyLocalInsightProvider();

  @override
  Future<String> generateInsight({
    required MonthlyAggregatedStats stats,
    required String locale,
    required String baseCurrency,
  }) async {
    await Future.delayed(const Duration(milliseconds: 800));
    final isAr = locale.startsWith('ar');
    final cur = baseCurrency;

    if (stats.topCategoryIds.isEmpty) {
      return isAr
          ? 'لم تُسجَّل مصروفات هذا الشهر بعد. ابدأ بإضافة معاملاتك اليومية لرؤية تحليلات مفيدة هنا.'
          : 'No spending recorded this month yet. Start adding daily transactions to see useful analysis here.';
    }

    final topCat = stats.topCategoryIds.first;
    final topAmount = stats.categoryTotals[topCat] ?? 0.0;
    final pctOfTotal = stats.totalSpent > 0
        ? ((topAmount / stats.totalSpent) * 100).round()
        : 0;

    if (isAr) {
      final catName = _categoryNameAr(topCat);
      // Only show comparison if we actually have 3-month data
      final avgForCat = stats.threeMonthAverageByCategory[topCat] ?? 0.0;
      if (avgForCat > 0) {
        final pctVsAvg = ((topAmount - avgForCat) / avgForCat * 100).round();
        final comparison = pctVsAvg >= 0
            ? 'بزيادة ${pctVsAvg.abs()}% عن متوسط آخر 3 أشهر'
            : 'بانخفاض ${pctVsAvg.abs()}% عن متوسط آخر 3 أشهر';
        return 'فئة "$catName" هي أعلى إنفاقك هذا الشهر بمبلغ ${_fmt(topAmount)} $cur ($pctOfTotal% من الإجمالي)، $comparison.';
      }
      // No historical data — keep it factual
      return 'فئة "$catName" هي أعلى إنفاقك هذا الشهر بمبلغ ${_fmt(topAmount)} $cur ($pctOfTotal% من الإجمالي).';
    }
    final catName = _categoryNameEn(topCat);
    // Only show comparison if we actually have 3-month data
    final avgForCat = stats.threeMonthAverageByCategory[topCat] ?? 0.0;
    if (avgForCat > 0) {
      final pctVsAvg = ((topAmount - avgForCat) / avgForCat * 100).round();
      final comparison = pctVsAvg >= 0
          ? 'up ${pctVsAvg.abs()}% vs your 3-month average'
          : 'down ${pctVsAvg.abs()}% vs your 3-month average';
      return '"$catName" is your highest spending category this month at ${_fmt(topAmount)} $cur ($pctOfTotal% of total), $comparison.';
    }
    // No historical data — keep it factual
    return '"$catName" is your highest spending category this month at ${_fmt(topAmount)} $cur ($pctOfTotal% of total).';
  }

  String _fmt(double v) => v.toStringAsFixed(2);
  String _categoryNameAr(String id) => {
        'food': 'الطعام والشراب',
        'transport': 'المواصلات',
        'bills': 'الفواتير',
        'entertainment': 'الترفيه',
        'shopping': 'التسوّق',
        'health': 'الصحة',
        'education': 'التعليم',
        'investment_return': 'عائد استثماري',
      'other': 'متنوّع',
      }[id] ??
      id;
  String _categoryNameEn(String id) {
    final names = {
      'food': 'Food',
      'transport': 'Transport',
      'bills': 'Bills',
      'entertainment': 'Entertainment',
      'shopping': 'Shopping',
      'health': 'Health',
      'education': 'Education',
      'salary': 'Salary',
      'freelance': 'Freelance',
      'investment_return': 'Investment Return',
      'other': 'Other',
    };
    return names[id] ?? id[0].toUpperCase() + id.substring(1);
  }
}

/// Optional provider that calls an OpenAI-compatible chat completions endpoint.
///
/// This is NOT enabled by default — instantiate it only if the user has
/// explicitly configured an endpoint + key in Settings (stored encrypted).
/// The provider sends ONLY [stats] (aggregated), never raw transactions.
class OpenAiCompatibleInsightProvider implements LlmInsightProvider {
  OpenAiCompatibleInsightProvider({
    required this.endpoint,
    required this.apiKey,
    required this.model,
  });

  final String endpoint; // e.g. https://api.openai.com/v1/chat/completions
  final String apiKey;
  final String model;

  @override
  Future<String> generateInsight({
    required MonthlyAggregatedStats stats,
    required String locale,
    required String baseCurrency,
  }) async {
    final isAr = locale.startsWith('ar');
    final system = isAr
        ? 'أنت مساعد مالي يقدّم رؤية واحدة قصيرة وعملية لشهر من الإنفاق. '
            'استخدم الأرقام المقدّمة فقط ولا تخترع معاملات. أعد فقرة واحدة فقط.'
        : 'You are a concise financial assistant that produces a single '
            'actionable insight for a month of spending. Use only the '
            'numbers provided; do not invent transactions. Return one paragraph only.';

    final userBuf = StringBuffer()
      ..writeln('Month: ${stats.monthKey}')
      ..writeln('Total spent: ${stats.totalSpent.toStringAsFixed(2)} $baseCurrency')
      ..writeln('Total income: ${stats.totalIncome.toStringAsFixed(2)} $baseCurrency')
      ..writeln('Daily average: ${stats.dailyAverage.toStringAsFixed(2)} $baseCurrency')
      ..writeln('Top categories:');
    final sorted = stats.categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (final e in sorted.take(5)) {
      final avg = stats.threeMonthAverageByCategory[e.key];
      userBuf.writeln(
        '  - ${e.key}: ${e.value.toStringAsFixed(2)} $baseCurrency'
        '${avg == null ? '' : ' (3-mo avg: ${avg.toStringAsFixed(2)})'}',
      );
    }

    final res = await http.post(
      Uri.parse(endpoint),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': model,
        'messages': [
          {'role': 'system', 'content': system},
          {'role': 'user', 'content': userBuf.toString()},
        ],
        'temperature': 0.4,
        'max_tokens': 300,
      }),
    ).timeout(const Duration(seconds: 30));

    if (res.statusCode < 200 || res.statusCode >= 300) {
      debugPrint('[InsightProvider] HTTP ${res.statusCode}');
      throw Exception('LLM HTTP ${res.statusCode}');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final choices = body['choices'] as List;
    if (choices.isEmpty) throw Exception('LLM returned no choices');
    final content = choices[0]['message']['content'] as String;
    return content.trim();
  }
}
