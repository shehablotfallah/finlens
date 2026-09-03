import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart' as gen;
import 'package:flutter_localizations/flutter_localizations.dart';

import '../../core/theme/finlens_theme.dart';
import '../onboarding/onboarding_screen.dart';
import '../setup/setup_screen.dart';
import 'app_lock_screen.dart';
import 'main_shell.dart';
import 'providers.dart';

class FinlensApp extends ConsumerWidget {
  const FinlensApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final themeMode = settings.themeMode.toFlutter();

    // Resolve locale: explicit override → system detection.
    Locale? effectiveLocale = settings.locale;
    if (effectiveLocale == null) {
      // Auto-detect: Arabic if device reports ar, otherwise English.
      final deviceLocale = View.of(context).platformDispatcher.locale;
      effectiveLocale =
          deviceLocale.languageCode == 'ar' ? const Locale('ar') : const Locale('en');
    }

    return MaterialApp(
      title: 'Finlens',
      debugShowCheckedModeBanner: false,
      theme: FinlensTheme.light(),
      darkTheme: FinlensTheme.dark(),
      themeMode: themeMode,
      locale: effectiveLocale,
      supportedLocales: gen.AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        gen.AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        // Set text direction based on current locale.
        return Directionality(
          textDirection: _isRtl(effectiveLocale) ? TextDirection.rtl : TextDirection.ltr,
          child: child!,
        );
      },
      home: const _EntryGate(),
    );
  }

  bool _isRtl(Locale? locale) => locale?.languageCode == 'ar';
}

class _EntryGate extends ConsumerWidget {
  const _EntryGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final lockState = ref.watch(appLockProvider);

    // Gate 1: Onboarding
    if (!settings.onboardingComplete) {
      return const OnboardingScreen();
    }
    // Gate 2: Quick setup
    if (!settings.setupComplete) {
      return const SetupScreen();
    }
    // Gate 3: App lock (PIN/biometric) when enabled and locked
    if (settings.appLockEnabled && lockState.isLocked) {
      return const AppLockScreen();
    }
    return const MainShell();
  }
}
