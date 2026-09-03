/// App-wide constants for Finlens.
class AppConstants {
  AppConstants._();

  static const String appName = 'Finlens';
  static const String appVersion = '1.0.0';
  static const String appVersionCode = '1';

  // Developer info — required to appear in About / Settings / README.
  static const String developer = 'Shehab Lotfallah';
  static const String developerHandle = '@shehablotfallah';
  static const String supportEmail = 'shehab-dev@outlook.com';

  // Storage keys for SharedPreferences / SecureStorage namespaces.
  static const String prefOnboardingComplete = 'onboarding_complete';
  static const String prefSetupComplete = 'setup_complete';
  static const String prefLocale = 'locale_code';
  static const String prefThemeMode = 'theme_mode';
  static const String prefSalaryDay = 'salary_day';
  static const String prefBaseCurrency = 'base_currency';
  static const String prefUsdToEgpRate = 'usd_to_egp_rate';
  static const String prefAppLockEnabled = 'app_lock_enabled';
  static const String prefBiometricEnabled = 'biometric_enabled';
  static const String prefAutoLockSeconds = 'auto_lock_seconds';
  static const String prefReminderDaysBefore = 'reminder_days_before';
  static const String prefLastInsightMonth = 'last_insight_month';

  // Secure storage keys.
  static const String secureDbPassphrase = 'finlens_db_passphrase';
  static const String securePinHash = 'finlens_pin_hash';
  static const String securePinSalt = 'finlens_pin_salt';

  // Hint flags — each shown to the user exactly once.
  static const String hintTxSwipe = 'hint_tx_swipe';
  static const String hintQuickCategory = 'hint_quick_category';
  static const String hintPullToRefresh = 'hint_pull_to_refresh';

  // Channel names for native (Android) plugins.
  static const String secureChannel = 'com.shehablotfallah.finlens/secure';

  // Notification defaults.
  static const int defaultReminderDaysBefore = 2;
  static const int defaultAutoLockSeconds = 60;

  // Supported currencies.
  static const String currencyEgp = 'EGP';
  static const String currencyUsd = 'USD';
  static const double defaultUsdToEgpRate = 48.5;
}
