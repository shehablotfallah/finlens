# Finlens

A privacy-first personal finance tracker for expenses, recurring bills, installments, and AI-driven insights.

**Developer:** Shehab Lotfallah · [@shehablotfallah](https://github.com/shehablotfallah) · shehab-dev@outlook.com

**Target:** Android (API 23+, ARM/ARM64/x86_64) — iOS ready (no iOS-specific code yet).

---

## ✨ What Finlens does

- **Quick-add transactions** with predefined + custom categories (under 5 taps).
- **Recurring bills** with local- notification reminders N days before due.
- **Installment plans** (Valu, Orange Cash, etc.) — separate visual treatment, remaining balance, next due date.
- **Salary-day awareness** — countdown to payday + daily budget remaining.
- **Multi-currency** — EGP + USD with manual exchange-rate update (historical rates frozen at insert time).
- **Reports** with bar/line/pie charts (`fl_chart`) — daily / monthly / yearly.
- **Export to PDF and CSV** (on-device, shared via Android share sheet).
- **Monthly AI Insight** — one-paragraph insight from aggregated stats (NOT a chatbot).
- **Encrypted local DB** (SQLCipher + Android Keystore).
- **App lock** — PIN + biometric (`local_auth`).
- **FLAG_SECURE on Recent Apps** only — in-app screenshots still allowed.
- **Bilingual** — Arabic + English with full RTL mirroring.
- **Light / Dark / Auto** themes, structured for a future 4th accent variant.
- **No analytics SDKs.** No backend. No data ever leaves the device.

---

## 📁 Project structure (Clean Architecture)

```
lib/
├── main.dart                          # entry point
├── l10n/                              # ARB files (en, ar)
├── core/
│   ├── constants/                     # AppConstants + PredefinedCategories
│   ├── theme/                         # FinlensTheme (Light / Dark / system + accent variant hook)
│   ├── utils/                         # Format helpers, CategoryResolver
│   └── errors/
├── domain/                            # pure Dart — no Flutter imports
│   ├── entities/                      # Transaction, Category, InstallmentPlan, MonthlyInsight
│   ├── repositories/                  # abstract interfaces
│   └── usecases/                      # InsertTransaction, DaysUntilPayday, etc.
├── data/                              # implementations of domain interfaces
│   ├── datasources/local/             # Drift database (encrypted via SQLCipher)
│   ├── models/
│   ├── repositories/                  # TransactionRepositoryImpl, etc.
│   └── services/                      # SecurityService, NotificationService, ExportService, InsightService
└── presentation/                      # Flutter widgets
    ├── app/                           # FinlensApp, MainShell, providers, AppLockScreen
    ├── onboarding/                    # 4-page swipeable intro
    ├── setup/                         # post-onboarding wizard (lang, salary day, currency, theme, PIN)
    ├── dashboard/                     # home screen with payday + daily budget
    ├── transactions/                  # list + edit sheet
    ├── bills/                         # upcoming obligations
    ├── installments/                  # installment plans
    ├── reports/                       # charts + PDF/CSV export
    └── settings/                      # appearance, finance, security, data, about
```

---

## 🛠 Tech stack

| Concern | Choice |
|---|---|
| Framework | Flutter 3.27+ / Dart 3.6+ |
| State management | `flutter_riverpod` 2.5 (single style throughout) |
| Local DB | `drift` 2.20 + `sqlcipher_flutter_libs` (encrypted SQLite) |
| Encrypted key store | `flutter_secure_storage` (Android Keystore-backed) |
| Biometric | `local_auth` |
| Localization | `flutter_localizations` + `intl` (ARB-based, no hardcoded strings) |
| Charts | `fl_chart` 0.69 |
| Notifications | `flutter_local_notifications` + `timezone` |
| Export | `pdf` + `csv` + `share_plus` |
| LLM insight | pluggable: ships with `DummyLocalInsightProvider`, swap-in `OpenAiCompatibleInsightProvider` |
| Architecture | Clean Architecture (presentation / domain / data) |

---

## 🔐 Security checklist

- [x] Local-first — no backend in v1, no transaction data leaves the device
- [x] SQLite file encrypted with SQLCipher (`PRAGMA key`)
- [x] Encryption key generated once and stored in Android Keystore via `flutter_secure_storage`
- [x] PIN hashed with 10k rounds of SHA-256 + per-install random salt
- [x] Biometric unlock via `local_auth`
- [x] FLAG_SECURE on app-switcher thumbnails only (in-app screenshots allowed) — see `MainActivity.kt`
- [x] No third-party analytics / ads / crash SDKs
- [x] No `print`/`debugPrint` of sensitive data — `debugPrint` in `InsightServiceImpl` only logs HTTP status, never amounts
- [x] Android `allowBackup=false` + `dataExtractionRules` excludes everything
- [x] SMS auto-import structured as a future isolated module — not in v1

---

## ▶️ Build instructions (local)

### Prerequisites

- Flutter SDK 3.27+ ([install](https://docs.flutter.dev/get-started/install))
- Android SDK with:
  - Platform 35 (`android-35`)
  - Build-Tools 35.0.0
  - NDK 27.0.12077973
- JDK 17 or 21 (Temurin / OpenJDK — must include `jlink`)
- ~3 GB free disk for caches + ~2 GB RAM headroom for the JVM

### Step-by-step

```bash
# 1. Clone / unzip the project
cd finlens

# 2. Install dependencies
flutter pub get

# 3. Run code generation (drift + l10n)
flutter pub run build_runner build --delete-conflicting-outputs
flutter gen-l10n

# 4. Verify analysis is clean
flutter analyze

# 5. (Optional) Run on a connected device
flutter run

# 6. Build release APK
flutter build apk --release

# Output:
# build/app/outputs/flutter-apk/app-release.apk
```

### Build flags

```bash
# Faster dev iteration (no AOT, no R8):
flutter build apk --debug

# Release but without resource shrinking (faster):
flutter build apk --release --no-shrink

# Build a fat APK that includes all ABIs:
flutter build apk --release --target-platform android-arm,android-arm64,android-x64
```

### Code signing (production)

The included build signs with debug keys (so the APK installs on any developer device). To produce a properly signed release:

1. Generate a keystore:
   ```bash
   keytool -genkey -v -keystore ~/finlens.jks \
     -keyalg RSA -keysize 2048 -validity 10000 -alias finlens
   ```

2. Add to `android/key.properties`:
   ```
   storePassword=***
   keyPassword=***
   keyAlias=finlens
   storeFile=/Users/YOU/finlens.jks
   ```

3. Update `android/app/build.gradle` to read it:
   ```groovy
   def keystoreProperties = new Properties()
   def keystorePropertiesFile = rootProject.file("key.properties")
   if (keystorePropertiesFile.exists()) {
       keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
   }
   // ... inside android { defaultConfig { ... } }:
   signingConfigs {
       release {
           keyAlias keystoreProperties['keyAlias']
           keyPassword keystoreProperties['keyPassword']
           storeFile file(keystoreProperties['storeFile'])
           storePassword keystoreProperties['storePassword']
       }
   }
   // ... inside buildTypes { release { signingConfig signingConfigs.release } }
   ```

4. Re-run `flutter build apk --release`.

---

## 🧪 Testing

The included `test/widget_test.dart` is a placeholder. Real test scaffolding should live under:

- `test/domain/usecases/` — pure logic unit tests (no Flutter)
- `test/data/repositories/` — Drift in-memory DB tests
- `test/presentation/` — widget tests with `flutter_test` + `mocktail`

To run existing tests:

```bash
flutter test
```

---

## 🌍 Localization

- `lib/l10n/app_en.arb` — English source (master)
- `lib/l10n/app_ar.arb` — Arabic translation
- Strings are looked up via `AppLocalizations.of(context)` — never hardcoded
- RTL is enforced in `finlens_app.dart` via `Directionality` wrapper based on the active locale
- All swipe / chip / chart layouts mirror automatically via `Directionality`

To add a 3rd language: drop a new `app_<code>.arb` file, re-run `flutter gen-l10n`, and add the locale to `kSupportedLocales` in `lib/main.dart`.

---

## 🤖 Monthly AI Insight — swapping providers

The shipped `DummyLocalInsightProvider` generates a useful insight locally without any network call (privacy-by-default). To plug in a real LLM:

1. Edit `lib/presentation/app/providers.dart`:
   ```dart
   final insightServiceProvider = FutureProvider<InsightService>((ref) async {
     final stats = await ref.watch(statsRepositoryProvider.future);
     final insights = await ref.watch(insightRepositoryProvider.future);
     return InsightServiceImpl(
       statsRepository: stats,
       insightRepository: insights,
       llmProvider: OpenAiCompatibleInsightProvider(
         endpoint: 'https://api.openai.com/v1/chat/completions',
         apiKey: '<user-supplied, stored encrypted>',
         model: 'gpt-4o-mini',
       ),
     );
   });
   ```

2. The provider sends ONLY aggregated stats (total spent, top categories, 3-month averages) — never individual transactions. See `lib/data/services/insight_service.dart` → `OpenAiCompatibleInsightProvider.generateInsight`.

---

## 🗺 Roadmap / v2 ideas (acknowledged in spec, not implemented)

- SMS auto-transaction-detection — structured as `data/services/sms_parser_service.dart` (isolated, on-device-only parsing module)
- Cloud sync layer — domain layer is already behind repository interfaces; a Supabase-backed repository implementation can be added without touching presentation
- 4th custom accent theme — `FinlensThemeMode` enum + `FinlensTheme._base(...)` already prepared for the extension
- Custom categories with icon/color picker — repository interface exists (`CategoryRepository`); UI not built in v1
- iOS support — no iOS-specific code, but no Android-only APIs either; port should be straightforward

---

## 📝 Developer credit

**Developed by Shehab Lotfallah**

- LinkedIn / GitHub / socials: **@shehablotfallah**
- Feedback & bug reports: **shehab-dev@outlook.com**

These details appear in:
- The app's About screen (Settings → About)
- The footer of every Settings screen
- This README

---

## 📜 License

Source code is provided to the requester for evaluation and further development.
No third-party analytics or advertising SDKs are bundled.
