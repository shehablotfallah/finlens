import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'presentation/app/finlens_app.dart';
import 'presentation/app/providers.dart';
import 'presentation/app/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait (mobile finance app — no real value in landscape).
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Set the status bar to transparent so the splash looks clean.
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  // Pre-load SharedPreferences so settings providers are ready synchronously.
  final prefs = await SharedPreferences.getInstance();
  setSharedPreferencesOverride(prefs);

  runApp(
    const ProviderScope(
      child: _AppWithSplash(),
    ),
  );
}

/// Shows the splash screen first, then transitions to FinlensApp.
class _AppWithSplash extends StatefulWidget {
  const _AppWithSplash();

  @override
  State<_AppWithSplash> createState() => _AppWithSplashState();
}

class _AppWithSplashState extends State<_AppWithSplash> {
  bool _showSplash = true;

  @override
  Widget build(BuildContext context) {
    if (_showSplash) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF0F9D8F),
            brightness: Brightness.light,
          ),
        ),
        home: SplashScreen(
          onComplete: () {
            setState(() => _showSplash = false);
          },
        ),
      );
    }
    return const FinlensApp();
  }
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
