import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'presentation/app/finlens_app.dart';
import 'presentation/app/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait (mobile finance app — no real value in landscape).
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Pre-load SharedPreferences so settings providers are ready synchronously.
  final prefs = await SharedPreferences.getInstance();
  setSharedPreferencesOverride(prefs);

  runApp(
    const ProviderScope(
      child: FinlensApp(),
    ),
  );
}

/// Re-export of generated localizations so we don't repeat the import
/// in every screen file.
typedef L10n = AppLocalizations;

// Convenience helpers exposed to the rest of the app.
const List<Locale> kSupportedLocales = [Locale('en'), Locale('ar')];

const localizationsDelegates = <LocalizationsDelegate<dynamic>>[
  AppLocalizations.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];
