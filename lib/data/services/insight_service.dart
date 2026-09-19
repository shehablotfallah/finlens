import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../domain/entities/transaction.dart';
import '../../domain/repositories/repositories.dart';
import '../../domain/usecases/usecases.dart';

import '../../domain/entities/app_notification.dart';
import '../repositories/notification_repository_impl.dart';

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

/// Helper to format structured Monthly Vision insights dynamically based
/// on the user's active locale (AR/EN), preventing stale language persistence.
class MonthlyVisionFormatter {
  static String format(String rawText, String locale, {String baseCurrency = 'EGP'}) {
    try {
      final data = jsonDecode(rawText);
      if (data is Map<String, dynamic> && data['type'] == 'local_vision') {
        final isAr = locale.startsWith('ar');
        final cur = data['currency'] as String? ?? baseCurrency;
        final hasSpending = data['hasSpending'] as bool? ?? false;

        if (!hasSpending) {
          return isAr
              ? 'لم تُسجَّل مصروفات هذا الشهر بعد. ابدأ بإضافة معاملاتك اليومية لرؤية تحليلات مفيدة هنا.'
              : 'No spending recorded this month yet. Start adding daily transactions to see useful analysis here.';
        }

        final topCat = data['topCat'] as String? ?? 'other';
        final topAmount = (data['topAmount'] as num?)?.toDouble() ?? 0.0;
        final pctOfTotal = (data['pctOfTotal'] as num?)?.toInt() ?? 0;
        final avgForCat = (data['avgForCat'] as num?)?.toDouble() ?? 0.0;
        final pctVsAvg = (data['pctVsAvg'] as num?)?.toInt();
        final fmtAmount = topAmount.toStringAsFixed(2);

        if (isAr) {
          final catName = _categoryNameAr(topCat);
          if (avgForCat > 0 && pctVsAvg != null) {
            final comparison = pctVsAvg >= 0
                ? 'بزيادة ${pctVsAvg.abs()}% عن متوسط آخر 3 أشهر'
                : 'بانخفاض ${pctVsAvg.abs()}% عن متوسط آخر 3 أشهر';
            return 'فئة "$catName" هي أعلى إنفاقك هذا الشهر بمبلغ $fmtAmount $cur ($pctOfTotal% من الإجمالي)، $comparison.';
          }
          return 'فئة "$catName" هي أعلى إنفاقك هذا الشهر بمبلغ $fmtAmount $cur ($pctOfTotal% من الإجمالي).';
        } else {
          final catName = _categoryNameEn(topCat);
          if (avgForCat > 0 && pctVsAvg != null) {
            final comparison = pctVsAvg >= 0
                ? 'up ${pctVsAvg.abs()}% vs your 3-month average'
                : 'down ${pctVsAvg.abs()}% vs your 3-month average';
            return '"$catName" is your highest spending category this month at $fmtAmount $cur ($pctOfTotal% of total), $comparison.';
          }
          return '"$catName" is your highest spending category this month at $fmtAmount $cur ($pctOfTotal% of total).';
        }
      }
    } catch (_) {}
    return rawText;
  }

  static String _categoryNameAr(String id) => {
        'food': 'الطعام والشراب',
        'transport': 'المواصلات',
        'bills': 'الفواتير',
        'entertainment': 'الترفيه',
        'shopping': 'التسوّق',
        'health': 'الصحة',
        'education': 'التعليم',
        'salary': 'الراتب',
        'freelance': 'عمل حر',
        'investment_return': 'عائد استثماري',
        'other': 'متنوّع',
      }[id] ??
      id;

  static String _categoryNameEn(String id) {
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
    return names[id] ?? (id.isNotEmpty ? id[0].toUpperCase() + id.substring(1) : id);
  }
}

/// Insight service implementation.
///
/// Orchestrates:
///   1. Aggregate stats for the given month from [StatsRepository].
///   2. Optionally enrich with 3-month averages.
///   3. Persist the result via [InsightRepository].
///   4. Persist in-app notification via [NotificationRepositoryImpl].
class InsightServiceImpl implements InsightService {
  InsightServiceImpl({
    required this.statsRepository,
    required this.insightRepository,
    required this.llmProvider,
    this.notificationRepository,
  });

  final StatsRepository statsRepository;
  final InsightRepository insightRepository;
  final LlmInsightProvider llmProvider;
  final NotificationRepositoryImpl? notificationRepository;

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
      id: 'insight_${stats.monthKey}',
      monthKey: stats.monthKey,
      text: text,
      generatedAt: DateTime.now(),
      locale: locale,
    );
    await insightRepository.save(insight);

    // BUG-002: Persist in-app notification for the newly generated Monthly Vision
    if (notificationRepository != null) {
      final isAr = locale.startsWith('ar');
      final notifTitle = isAr ? 'رؤية شهرية جديدة' : 'New Monthly Vision';
      final notifBody = isAr
          ? 'تم تحديث تحليلاتك المالية لشهر ${stats.monthKey}.'
          : 'Your financial insights for ${stats.monthKey} are ready.';
      await notificationRepository!.insert(
        AppNotification(
          id: 'vision_${stats.monthKey}',
          type: NotificationType.insight,
          title: notifTitle,
          body: notifBody,
          createdAt: DateTime.now(),
          isRead: false,
          payload: jsonEncode({
            'type': 'vision',
            'monthKey': stats.monthKey,
          }),
        ),
      );
    }

    return insight;
  }

  String _monthKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';
}

/// Default provider used in v1 — generates structured factual insight locally
/// without any network call.
class DummyLocalInsightProvider implements LlmInsightProvider {
  DummyLocalInsightProvider();

  @override
  Future<String> generateInsight({
    required MonthlyAggregatedStats stats,
    required String locale,
    required String baseCurrency,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final cur = baseCurrency;

    final topCat = stats.topCategoryIds.isNotEmpty ? stats.topCategoryIds.first : null;
    final topAmount = topCat != null ? (stats.categoryTotals[topCat] ?? 0.0) : 0.0;
    final pctOfTotal = stats.totalSpent > 0
        ? ((topAmount / stats.totalSpent) * 100).round()
        : 0;
    final avgForCat = topCat != null ? (stats.threeMonthAverageByCategory[topCat] ?? 0.0) : 0.0;
    final pctVsAvg = avgForCat > 0 ? ((topAmount - avgForCat) / avgForCat * 100).round() : null;

    final structured = {
      'type': 'local_vision',
      'version': 1,
      'monthKey': stats.monthKey,
      'hasSpending': stats.topCategoryIds.isNotEmpty,
      'topCat': topCat,
      'topAmount': topAmount,
      'pctOfTotal': pctOfTotal,
      'avgForCat': avgForCat,
      'pctVsAvg': pctVsAvg,
      'currency': cur,
    };
    return jsonEncode(structured);
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
