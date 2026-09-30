# Finlens

A privacy-first Android finance tracker for expenses, recurring bills, installments, and local financial insights.

> [Download Latest APK](https://github.com/shehablotfallah/finlens/releases/latest)
>
> [Latest Release](https://github.com/shehablotfallah/finlens/releases/latest) • [All Releases](https://github.com/shehablotfallah/finlens/releases)
>
> Android may prompt you to allow installation from an unknown source because the APK is distributed directly from GitHub rather than through Google Play.

Finlens is built to help you understand where your money is going without creating an account or sending your financial data to a cloud service. It is designed for everyday personal budgeting, bill planning, and financial visibility on Android.

## ✨ Features

- Quick expense and income tracking
- Recurring bills and reminders
- Installment plan tracking
- Salary-day and budget awareness
- EGP and USD support
- Reports and charts
- PDF and CSV export
- Monthly financial insights
- PIN and biometric app lock
- Arabic and English support
- Light and dark themes
- Privacy-first local storage

## 🔐 Privacy by Design

Finlens is intentionally local-first.

- No account required.
- No backend is used in v1.
- No analytics, no ads, and no tracking.
- Financial data stays on the device.
- The local database is encrypted with SQLCipher.
- The encryption key is kept in Android Keystore-backed secure storage.
- App lock supports PIN and biometric authentication.
- Android backup is disabled and data extraction is restricted in the current implementation.

This is a personal finance app designed to stay on-device rather than depend on a remote service for core functionality.

## 📱 Screenshots

Screenshots are not included in this repository yet. This section will be updated with representative app screenshots when they are added.

## 📲 Install Finlens

1. Open the [latest release page](https://github.com/shehablotfallah/finlens/releases/latest).
2. Download the Android APK.
3. Open the downloaded file on your device.
4. If Android blocks installation, allow installation from that source in the system prompt or Android settings.
5. Install the app and launch Finlens.

The APK is distributed directly from GitHub Releases for the current Android build.

## 🛠 Tech Stack

| Area             | Technology                  |
| ---------------- | --------------------------- |
| Framework        | Flutter                     |
| Language         | Dart                        |
| State management | Riverpod                    |
| Local database   | Drift + SQLCipher           |
| Secure storage   | flutter_secure_storage      |
| App lock         | local_auth                  |
| Charts           | fl_chart                    |
| Notifications    | flutter_local_notifications |
| Export           | pdf, csv, share_plus        |
| Architecture     | Clean Architecture          |

## 🏗 Architecture

Finlens follows a Clean Architecture structure with clear separation between UI, domain logic, and data access.

```text
lib/
├── core/
├── data/
├── domain/
├── l10n/
├── presentation/
├── main.dart
└──
```

- `presentation/` contains the Flutter UI and screens.
- `domain/` defines entities, repository contracts, and use cases.
- `data/` implements repositories, local database access, security, notifications, and exports.
- `core/` holds shared constants, theme logic, and app-wide utilities.

## 👨‍💻 Development Setup

### Requirements

- Flutter 3.27.0 or newer
- Dart SDK: >=3.4.0 <4.0.0
- Android SDK with compileSdk 35
- Android minSdk 23
- JDK 17
- NDK 27.0.12077973

### Common commands

```bash
flutter pub get
flutter gen-l10n
flutter pub run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
flutter build apk --release
```

## 🚀 Releases

The repository uses GitHub Actions to build the Android APK, and published builds are available under GitHub Releases.

- Latest release: https://github.com/shehablotfallah/finlens/releases/latest
- All releases: https://github.com/shehablotfallah/finlens/releases

## 🤖 AI Insights

Finlens includes a local monthly insight feature that works without network access by default.

- The default insight provider runs locally and does not require an external API.
- The architecture allows replacing the provider with an OpenAI-compatible implementation.
- If an external provider is configured, only aggregated financial statistics are intended to be sent, not individual transactions.
- External AI usage is optional and not part of the default privacy-first local experience.

## 🗺 Roadmap

### Implemented

- Expense and income tracking
- Recurring bills
- Installment tracking
- Salary-day awareness
- EGP and USD support
- Reports and exports
- PIN and biometric app lock
- Arabic and English localization
- Local encrypted storage

### Planned

- SMS transaction detection
- Cloud sync
- Custom categories
- Additional theme customization
- iOS support

## 🔒 Security

- Local-only data handling
- SQLCipher-encrypted database
- Android Keystore-backed secure storage
- PIN hashing and biometric authentication
- Backup and data extraction restrictions enabled in the Android manifest
- No third-party analytics or ad SDKs

## 🔧 Security Implementation

The current implementation includes the following technical safeguards:

- `drift` + `sqlcipher_flutter_libs` for encrypted local storage
- `flutter_secure_storage` with Android encrypted shared preferences
- `SecurityService` stores a random salt and hashed PIN instead of storing the raw PIN
- `local_auth` support for biometric unlock
- `android:allowBackup="false"` and restricted data extraction settings in the app manifest

## 📁 Project Structure

```text
lib/
├── core/
├── data/
├── domain/
├── l10n/
├── presentation/
├── main.dart
└──
```

This keeps the app organized by feature and responsibility: shared logic, repositories and data sources, business rules, and the Flutter UI layer.

## 📄 License

This repository does not currently include a formal LICENSE file. At the moment, the project does not declare a license in the repository metadata, so the current licensing status should be treated as unlicensed unless otherwise stated by the repository owner.

## 👤 Author

Developed by Shehab Lotfallah

- GitHub: [shehablotfallah](https://github.com/shehablotfallah)
- LinkedIn: [Shehab Lotfallah](https://www.linkedin.com/in/shehablotfallah)
- Email: [shehab-dev@outlook.com](mailto:shehab-dev@outlook.com)

---

Finlens is a practical Android finance companion focused on local control, privacy, and everyday money visibility. For the latest downloadable APK, visit the [GitHub release page](https://github.com/shehablotfallah/finlens/releases/latest).
