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
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../data/services/notification_service.dart';

/// Root widget — applies theme, locale, and routes to the right gate
/// (onboarding → setup → app lock → main shell).
class FinlensApp extends ConsumerStatefulWidget {
  const FinlensApp({super.key});

  @override
  ConsumerState<FinlensApp> createState() => _FinlensAppState();
}

class _FinlensAppState extends ConsumerState<FinlensApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    // Attach lifecycle observer at the root so it survives navigation
    // between gates (onboarding, setup, lock, main). Previously the
    // observer was attached only in MainShell, which meant lock state
    // was not tracked while the user was in onboarding/setup — and
    // worse, on cold start the observer wasn't attached at all until
    // MainShell was built.
    WidgetsBinding.instance.addObserver(this);
    // Initialize notification plugin early so scheduled notifications
    // can fire correctly even before the user opens the app.
    ref.read(notificationServiceProvider).init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final lockNotifier = ref.read(appLockProvider.notifier);
    switch (state) {
      case AppLifecycleState.resumed:
        lockNotifier.onAppResumed();
        break;
      case AppLifecycleState.inactive:
        // Transitional — don't act yet.
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        lockNotifier.onAppPaused();
        break;
      case AppLifecycleState.detached:
        // App is being destroyed — ensure we persist the backgrounded
        // timestamp so cold-start lock works.
        lockNotifier.onAppPaused();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final themeMode = settings.themeMode.toFlutter();

    // Locale resolution:
    //   settings.locale == null  →  "System"  →  pass null to MaterialApp
    //                                so Flutter resolves against the
    //                                platform locale using supportedLocales.
    //                                This is what makes "System" actually
    //                                follow the device language.
    //   settings.locale != null  →  explicit override (en / ar).
    //
    // We deliberately do NOT wrap in a Directionality widget —
    // MaterialApp already handles RTL automatically based on the
    // resolved locale. The previous manual Directionality wrapper
    // was causing stale text direction when the user switched
    // language via Settings → System.
    final Locale? effectiveLocale = settings.locale;

    return MaterialApp(
      title: 'Finlens',
      debugShowCheckedModeBanner: false,
      theme: FinlensTheme.light(),
      darkTheme: FinlensTheme.dark(),
      themeMode: themeMode,
      // Always pass the explicit locale (en or ar). We removed "System"
      // as an option — the user must explicitly choose Arabic or English.
      locale: effectiveLocale,
      supportedLocales: gen.AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        gen.AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const _EntryGate(),
    );
  }
}

/// Entry gate — routes to the correct first screen based on app state.
///
/// Order of precedence:
///   1. Onboarding (first launch only)
///   2. Setup wizard (after onboarding, before first use)
///   3. App lock screen (when lock is enabled AND state.isLocked is true)
///   4. Main shell (default)
///
/// Because this is a synchronous gate on `isLocked`, the protected
/// MainShell is NEVER built before authentication completes.
class _EntryGate extends ConsumerStatefulWidget {
  const _EntryGate();

  @override
  ConsumerState<_EntryGate> createState() => _EntryGateState();
}

class _EntryGateState extends ConsumerState<_EntryGate> {
  bool _notifPermissionChecked = false;

  @override
  void initState() {
    super.initState();
    _checkNotificationPermissionOnFirstEntry();
  }

  /// On first app entry (after onboarding + setup), if bill reminders
  /// are enabled by default (reminderDaysBefore > 0), check and
  /// request notification permission.
  ///
  /// This is called ONCE when the user first reaches MainShell.
  /// It does NOT run again on subsequent rebuilds or when the user
  /// changes reminder days in Settings.
  Future<void> _checkNotificationPermissionOnFirstEntry() async {
    if (_notifPermissionChecked) return;
    _notifPermissionChecked = true;

    final settings = ref.read(appSettingsProvider);
    // Only request if reminders are enabled by default
    if (settings.reminderDaysBefore > 0) {
      final notif = ref.read(notificationServiceProvider);
      final alreadyEnabled = await notif.areNotificationsEnabled();
      if (!alreadyEnabled && mounted) {
        // Small delay to let the UI settle after first build
        await Future<void>.delayed(const Duration(milliseconds: 500));
        if (!mounted) return;
        // Request permission with explanatory dialog
        await _requestPermissionWithDialog(context);
      }
    }
  }

  Future<void> _requestPermissionWithDialog(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final notif = ref.read(notificationServiceProvider);

    final userAgreed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.notifPermTitle),
        content: Text(l.notifPermMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.notifPermSkip),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.notifPermAllow),
          ),
        ],
      ),
    );

    if (userAgreed != true) return;
    if (!mounted) return;

    final result = await notif.requestPermission();
    if (!mounted) return;

    switch (result) {
      case NotificationPermissionResult.granted:
        break;
      case NotificationPermissionResult.denied:
      case NotificationPermissionResult.permanentlyDenied:
        if (mounted) {
          await showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(l.notifPermDeniedTitle),
              content: Text(l.notifPermDeniedBody),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(l.commonCancel),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    notif.openNotificationSettings();
                  },
                  child: Text(l.notifPermOpenSettings),
                ),
              ],
            ),
          );
        }
    }
  }

  @override
  Widget build(BuildContext context) {
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
    // Gate 3: App lock (PIN/biometric) when enabled and locked.
    if (settings.appLockEnabled && lockState.isLocked) {
      return const AppLockScreen();
    }
    return const MainShell();
  }
}
