import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/finlens_theme.dart';
import '../../data/datasources/local/finlens_database.dart';
import '../../data/repositories/repositories_impl.dart';
import '../../data/services/export_service.dart';
import '../../data/services/insight_service.dart';
import '../../data/services/notification_service.dart';
import '../../data/services/security_service.dart';
import '../../domain/repositories/repositories.dart';
import '../../domain/usecases/usecases.dart';

// ---------------------------------------------------------------------------
// Async singletons
// ---------------------------------------------------------------------------

/// Provides the encrypted [FinlensDatabase].
final databaseProvider = FutureProvider<FinlensDatabase>((ref) async {
  final db = await openFinlensDatabase();
  ref.onDispose(db.close);
  return db;
});

/// SharedPreferences — loaded eagerly in main() and provided as an override.
/// Kept as FutureProvider so consumers can still `await` it for safety.
final sharedPreferencesProvider = FutureProvider<SharedPreferences>((ref) async {
  return _prefsOverride ?? await SharedPreferences.getInstance();
});

SharedPreferences? _prefsOverride;

/// Called from main() BEFORE runApp() to inject the loaded prefs instance.
void setSharedPreferencesOverride(SharedPreferences prefs) {
  _prefsOverride = prefs;
}

final securityServiceProvider = Provider<SecurityService>((ref) {
  return SecurityService();
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

final exportServiceProvider = Provider<ExportService>((ref) {
  return ExportService();
});

// ---------------------------------------------------------------------------
// Repositories
// ---------------------------------------------------------------------------

final transactionRepositoryProvider =
    FutureProvider<TransactionRepository>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return TransactionRepositoryImpl(db);
});

final categoryRepositoryProvider = FutureProvider<CategoryRepository>(
    (ref) async {
  final db = await ref.watch(databaseProvider.future);
  return CategoryRepositoryImpl(db);
});

final installmentPlanRepositoryProvider =
    FutureProvider<InstallmentPlanRepository>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return InstallmentPlanRepositoryImpl(db);
});

final insightRepositoryProvider =
    FutureProvider<InsightRepository>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return InsightRepositoryImpl(db);
});

final statsRepositoryProvider =
    FutureProvider<StatsRepository>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return StatsRepositoryImpl(db);
});

final exchangeRateProvider = Provider<ExchangeRateProviderImpl>((ref) {
  return ExchangeRateProviderImpl();
});

// ---------------------------------------------------------------------------
// Insight service — uses DummyLocalInsightProvider by default for v1.
// Swap with OpenAiCompatibleInsightProvider in main.dart if user opts in.
// ---------------------------------------------------------------------------

final insightServiceProvider =
    FutureProvider<InsightService>((ref) async {
  final stats = await ref.watch(statsRepositoryProvider.future);
  final insights = await ref.watch(insightRepositoryProvider.future);
  return InsightServiceImpl(
    statsRepository: stats,
    insightRepository: insights,
    llmProvider: DummyLocalInsightProvider(),
  );
});

// ---------------------------------------------------------------------------
// App settings
// ---------------------------------------------------------------------------

class AppSettings {
  AppSettings({
    this.locale,
    required this.themeMode,
    required this.salaryDay,
    required this.baseCurrency,
    required this.usdToEgpRate,
    required this.appLockEnabled,
    required this.biometricEnabled,
    required this.autoLockSeconds,
    required this.reminderDaysBefore,
    required this.onboardingComplete,
    required this.setupComplete,
    required this.hintsShown,
  });

  final Locale? locale;
  final FinlensThemeMode themeMode;
  final int salaryDay;
  final String baseCurrency;
  final double usdToEgpRate;
  final bool appLockEnabled;
  final bool biometricEnabled;
  final int autoLockSeconds;
  final int reminderDaysBefore;
  final bool onboardingComplete;
  final bool setupComplete;
  final Set<String> hintsShown;

  AppSettings copyWith({
    Locale? locale,
    FinlensThemeMode? themeMode,
    int? salaryDay,
    String? baseCurrency,
    double? usdToEgpRate,
    bool? appLockEnabled,
    bool? biometricEnabled,
    int? autoLockSeconds,
    int? reminderDaysBefore,
    bool? onboardingComplete,
    bool? setupComplete,
    Set<String>? hintsShown,
  }) {
    return AppSettings(
      locale: locale ?? this.locale,
      themeMode: themeMode ?? this.themeMode,
      salaryDay: salaryDay ?? this.salaryDay,
      baseCurrency: baseCurrency ?? this.baseCurrency,
      usdToEgpRate: usdToEgpRate ?? this.usdToEgpRate,
      appLockEnabled: appLockEnabled ?? this.appLockEnabled,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      autoLockSeconds: autoLockSeconds ?? this.autoLockSeconds,
      reminderDaysBefore: reminderDaysBefore ?? this.reminderDaysBefore,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      setupComplete: setupComplete ?? this.setupComplete,
      hintsShown: hintsShown ?? this.hintsShown,
    );
  }

  static AppSettings get defaults => AppSettings(
        locale: null,
        themeMode: FinlensThemeMode.system,
        salaryDay: 1,
        baseCurrency: AppConstants.currencyEgp,
        usdToEgpRate: AppConstants.defaultUsdToEgpRate,
        appLockEnabled: false,
        biometricEnabled: false,
        autoLockSeconds: AppConstants.defaultAutoLockSeconds,
        reminderDaysBefore: AppConstants.defaultReminderDaysBefore,
        onboardingComplete: false,
        setupComplete: false,
        hintsShown: {},
      );

  Map<String, dynamic> toJson() => {
        'locale': locale?.languageCode,
        'themeMode': themeMode.name,
        'salaryDay': salaryDay,
        'baseCurrency': baseCurrency,
        'usdToEgpRate': usdToEgpRate,
        'appLockEnabled': appLockEnabled,
        'biometricEnabled': biometricEnabled,
        'autoLockSeconds': autoLockSeconds,
        'reminderDaysBefore': reminderDaysBefore,
        'onboardingComplete': onboardingComplete,
        'setupComplete': setupComplete,
        'hintsShown': hintsShown.toList(),
      };

  factory AppSettings.fromJson(Map<String, dynamic> j) {
    return AppSettings(
      locale: j['locale'] == null ? null : Locale(j['locale'] as String),
      themeMode: FinlensThemeMode.values
          .byName(j['themeMode'] as String? ?? 'system'),
      salaryDay: j['salaryDay'] as int? ?? 1,
      baseCurrency: j['baseCurrency'] as String? ?? 'EGP',
      usdToEgpRate:
          (j['usdToEgpRate'] as num?)?.toDouble() ??
              AppConstants.defaultUsdToEgpRate,
      appLockEnabled: j['appLockEnabled'] as bool? ?? false,
      biometricEnabled: j['biometricEnabled'] as bool? ?? false,
      autoLockSeconds: j['autoLockSeconds'] as int? ??
          AppConstants.defaultAutoLockSeconds,
      reminderDaysBefore: j['reminderDaysBefore'] as int? ??
          AppConstants.defaultReminderDaysBefore,
      onboardingComplete: j['onboardingComplete'] as bool? ?? false,
      setupComplete: j['setupComplete'] as bool? ?? false,
      hintsShown:
          (j['hintsShown'] as List<dynamic>?)?.cast<String>().toSet() ?? {},
    );
  }
}

const _kSettingsJsonKey = '_app_settings_json_v1';

class AppSettingsNotifier extends StateNotifier<AppSettings> {
  AppSettingsNotifier(this._prefs) : super(_load(_prefs));

  final SharedPreferences _prefs;

  static AppSettings _load(SharedPreferences prefs) {
    final raw = prefs.getString(_kSettingsJsonKey);
    if (raw != null) {
      try {
        return AppSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        // Fall through to defaults
      }
    }
    return AppSettings.defaults;
  }

  Future<void> _persist() async {
    await _prefs.setString(_kSettingsJsonKey, jsonEncode(state.toJson()));
  }

  Future<void> setLocale(Locale? locale) async {
    state = state.copyWith(locale: locale);
    await _persist();
  }

  Future<void> setThemeMode(FinlensThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await _persist();
  }

  Future<void> setSalaryDay(int day) async {
    state = state.copyWith(salaryDay: day.clamp(1, 28));
    await _persist();
  }

  Future<void> setBaseCurrency(String code) async {
    state = state.copyWith(baseCurrency: code);
    await _persist();
  }

  Future<void> setUsdToEgpRate(double rate) async {
    state = state.copyWith(usdToEgpRate: rate);
    await _persist();
  }

  Future<void> setAppLock(bool enabled) async {
    state = state.copyWith(appLockEnabled: enabled);
    await _persist();
  }

  Future<void> setBiometric(bool enabled) async {
    state = state.copyWith(biometricEnabled: enabled);
    await _persist();
  }

  Future<void> setAutoLockSeconds(int seconds) async {
    state = state.copyWith(autoLockSeconds: seconds);
    await _persist();
  }

  Future<void> setReminderDaysBefore(int days) async {
    state = state.copyWith(reminderDaysBefore: days);
    await _persist();
  }

  Future<void> setOnboardingComplete() async {
    state = state.copyWith(onboardingComplete: true);
    await _persist();
  }

  Future<void> setSetupComplete() async {
    state = state.copyWith(setupComplete: true);
    await _persist();
  }

  Future<void> markHintShown(String key) async {
    if (state.hintsShown.contains(key)) return;
    state = state.copyWith(hintsShown: {...state.hintsShown, key});
    await _persist();
  }

  Future<void> resetHints() async {
    state = state.copyWith(hintsShown: {});
    await _persist();
  }
}

final appSettingsProvider =
    StateNotifierProvider<AppSettingsNotifier, AppSettings>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider).maybeWhen(
        data: (p) => p,
        orElse: () => throw StateError('SharedPreferences not yet loaded'),
      );
  return AppSettingsNotifier(prefs);
});

// Convenience derived providers
final themeModeProvider = Provider<FinlensThemeMode>((ref) {
  return ref.watch(appSettingsProvider).themeMode;
});

final localeProvider = Provider<Locale?>((ref) {
  return ref.watch(appSettingsProvider).locale;
});

// ---------------------------------------------------------------------------
// App lock state — tracks when app was backgrounded to enforce auto-lock
// ---------------------------------------------------------------------------

class AppLockState {
  AppLockState({
    required this.isLocked,
    required this.lastBackgroundedAt,
  });
  final bool isLocked;
  final DateTime? lastBackgroundedAt;

  AppLockState copyWith({
    bool? isLocked,
    DateTime? lastBackgroundedAt,
    bool clearBackgrounded = false,
  }) {
    return AppLockState(
      isLocked: isLocked ?? this.isLocked,
      lastBackgroundedAt:
          clearBackgrounded ? null : (lastBackgroundedAt ?? this.lastBackgroundedAt),
    );
  }
}

class AppLockNotifier extends StateNotifier<AppLockState> {
  AppLockNotifier(this._ref) : super(AppLockState(isLocked: false, lastBackgroundedAt: null));

  final Ref _ref;

  void onAppPaused() {
    state = state.copyWith(
      lastBackgroundedAt: DateTime.now(),
    );
  }

  void onAppResumed() {
    final settings = _ref.read(appSettingsProvider);
    if (!settings.appLockEnabled) {
      state = state.copyWith(isLocked: false, clearBackgrounded: true);
      return;
    }
    final lastBg = state.lastBackgroundedAt;
    if (lastBg == null) {
      // First resume — keep unlocked
      state = state.copyWith(isLocked: false, clearBackgrounded: true);
      return;
    }
    final elapsed = DateTime.now().difference(lastBg).inSeconds;
    if (elapsed >= settings.autoLockSeconds) {
      state = state.copyWith(isLocked: true, clearBackgrounded: true);
    } else {
      state = state.copyWith(clearBackgrounded: true);
    }
  }

  void forceLock() {
    state = state.copyWith(isLocked: true);
  }

  void unlock() {
    state = state.copyWith(isLocked: false);
  }
}

final appLockProvider =
    StateNotifierProvider<AppLockNotifier, AppLockState>((ref) {
  return AppLockNotifier(ref);
});
