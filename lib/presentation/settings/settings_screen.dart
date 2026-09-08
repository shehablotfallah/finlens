import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/finlens_theme.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../data/services/security_service.dart';
import '../../data/services/notification_service.dart';
import '../app/providers.dart';
import '../common/pin_pad.dart';
import 'about_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final settings = ref.watch(appSettingsProvider);
    final notifier = ref.read(appSettingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text(l.settingsTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            _SectionTitle(label: l.settingsAppearance),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text(l.setupSummaryName),
              subtitle: Text(settings.userDisplayName ??
                  l.setupSummaryNotSet),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showNameEditor(context, ref,
                  settings.userDisplayName ?? ''),
            ),
            ListTile(
              leading: const Icon(Icons.translate_outlined),
              title: Text(l.settingsLanguage),
              subtitle: Text(_localeLabel(l, settings.locale)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showLocalePicker(context, ref),
            ),
            ListTile(
              leading: const Icon(Icons.color_lens_outlined),
              title: Text(l.settingsTheme),
              subtitle: Text(_themeLabel(l, settings.themeMode)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showThemePicker(context, ref),
            ),
            const Divider(),
            _SectionTitle(label: l.settingsFinance),
            ListTile(
              leading: const Icon(Icons.calendar_month_outlined),
              title: Text(l.settingsSalaryDay),
              subtitle: Text('${settings.salaryDay}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showSalaryDayPicker(context, ref, settings.salaryDay),
            ),
            ListTile(
              leading: const Icon(Icons.payments_outlined),
              title: Text(l.settingsBaseCurrency),
              subtitle: Text(settings.baseCurrency),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final picked = await showDialog<String>(
                  context: context,
                  builder: (ctx) => SimpleDialog(
                    title: Text(l.settingsBaseCurrency),
                    children: ['EGP', 'USD']
                        .map((c) => SimpleDialogOption(
                              onPressed: () => Navigator.pop(ctx, c),
                              child: Text(c),
                            ))
                        .toList(),
                  ),
                );
                if (picked != null) {
                  await notifier.setBaseCurrency(picked);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.currency_exchange_outlined),
              title: Text(l.settingsExchangeRate),
              subtitle: Text('1 USD = ${settings.usdToEgpRate} EGP'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () =>
                  _showExchangeRatePicker(context, ref, settings.usdToEgpRate),
            ),
            const Divider(),
            _SectionTitle(label: l.settingsSecurity),
            SwitchListTile(
              secondary: const Icon(Icons.lock_outline),
              title: Text(l.settingsAppLock),
              subtitle: Text(
                settings.appLockEnabled
                    ? l.settingsAppLockOn
                    : l.settingsAppLockOff,
              ),
              value: settings.appLockEnabled,
              onChanged: (v) => _toggleAppLock(context, ref, v),
            ),
            if (settings.appLockEnabled) ...[
              SwitchListTile(
                secondary: const Icon(Icons.fingerprint),
                title: Text(l.settingsBiometric),
                value: settings.biometricEnabled,
                onChanged: (v) => _toggleBiometric(context, ref, v),
              ),
              ListTile(
                leading: const Icon(Icons.timer_outlined),
                title: Text(l.settingsAutoLockTimeout),
                subtitle: Text(_autoLockLabel(l, settings.autoLockSeconds)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () =>
                    _showAutoLockPicker(context, ref, settings.autoLockSeconds),
              ),
              ListTile(
                leading: const Icon(Icons.pin_outlined),
                title: Text(l.settingsPin),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _promptCreatePin(context, ref),
              ),
            ],
            const Divider(),
            _SectionTitle(label: l.settingsReminders),
            ListTile(
              leading: const Icon(Icons.notifications_outlined),
              title: Text(l.settingsReminderDays),
              subtitle: Text(
                settings.reminderDaysBefore == 0
                    ? l.settingsRemindersOff
                    : '${settings.reminderDaysBefore}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () =>
                  _showReminderDaysPicker(context, ref, settings.reminderDaysBefore),
            ),
            const Divider(),
            _SectionTitle(label: l.settingsData),
            ListTile(
              leading: const Icon(Icons.file_download_outlined),
              title: Text(l.settingsExportAll),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Coming soon')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever_outlined,
                  color: FinlensColors.expense),
              title: Text(l.settingsEraseAll,
                  style: const TextStyle(color: FinlensColors.expense)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _confirmEraseAll(context, ref),
            ),
            ListTile(
              leading: const Icon(Icons.lightbulb_outline),
              title: Text(l.settingsHintReset),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => notifier.resetHints(),
            ),
            const Divider(),
            _SectionTitle(label: l.settingsAbout),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: Text(l.settingsAbout),
              subtitle: Text('${l.aboutVersion} ${_appVersionLabel(l)}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const AboutScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            _DeveloperFooter(theme: theme),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  String _appVersionLabel(AppLocalizations l) {
    // Imported lazily to avoid circular deps — AppConstants is constant.
    return '1.0.0';
  }

  String _localeLabel(AppLocalizations l, Locale? locale) {
    if (locale == null) return l.settingsLanguageSystem;
    if (locale.languageCode == 'ar') return l.settingsLanguageAr;
    return l.settingsLanguageEn;
  }

  String _themeLabel(AppLocalizations l, FinlensThemeMode mode) {
    return switch (mode) {
      FinlensThemeMode.light => l.settingsThemeLight,
      FinlensThemeMode.dark => l.settingsThemeDark,
      FinlensThemeMode.system => l.settingsThemeAuto,
    };
  }

  String _autoLockLabel(AppLocalizations l, int seconds) {
    return switch (seconds) {
      0 => l.settingsAutoLockNever,
      30 => l.settingsAutoLock30s,
      60 => l.settingsAutoLock1m,
      300 => l.settingsAutoLock5m,
      _ => '${seconds}s',
    };
  }

  Future<void> _showNameEditor(
      BuildContext context, WidgetRef ref, String current) async {
    final l = AppLocalizations.of(context);
    final ctrl = TextEditingController(text: current);
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.setupSummaryName),
        content: TextField(
          controller: ctrl,
          textCapitalization: TextCapitalization.words,
          maxLength: 30,
          decoration: InputDecoration(
            labelText: l.setupNameHint,
            hintText: l.setupNameHint,
            helperText: l.setupNameOptional,
            border: const OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: Text(l.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: Text(l.commonSave),
          ),
        ],
      ),
    );
    if (picked != null) {
      await ref.read(appSettingsProvider.notifier).setUserDisplayName(picked);
    }
  }

  void _showLocalePicker(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(l.settingsLanguageEn),
              onTap: () async {
                await ref
                    .read(appSettingsProvider.notifier)
                    .setLocale(const Locale('en'));
                if (ctx.mounted) Navigator.pop(ctx);
              },
            ),
            ListTile(
              title: Text(l.settingsLanguageAr),
              onTap: () async {
                await ref
                    .read(appSettingsProvider.notifier)
                    .setLocale(const Locale('ar'));
                if (ctx.mounted) Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showThemePicker(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final settings = ref.read(appSettingsProvider);
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: FinlensThemeMode.values
              .map((mode) => RadioListTile<FinlensThemeMode>(
                    value: mode,
                    groupValue: settings.themeMode,
                    title: Text(_themeLabel(l, mode)),
                    onChanged: (v) async {
                      if (v != null) {
                        await ref
                            .read(appSettingsProvider.notifier)
                            .setThemeMode(v);
                        if (ctx.mounted) Navigator.pop(ctx);
                      }
                    },
                  ))
              .toList(),
        ),
      ),
    );
  }

  Future<void> _showSalaryDayPicker(
      BuildContext context, WidgetRef ref, int current) async {
    final l = AppLocalizations.of(context);
    final picked = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l.settingsSalaryDay),
        children: List.generate(28, (i) => i + 1)
            .map((d) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, d),
                  child: Text('$d'),
                ))
            .toList(),
      ),
    );
    if (picked != null) {
      await ref.read(appSettingsProvider.notifier).setSalaryDay(picked);
    }
  }

  Future<void> _showExchangeRatePicker(
      BuildContext context, WidgetRef ref, double current) async {
    final l = AppLocalizations.of(context);
    final ctrl = TextEditingController(text: current.toString());
    final picked = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.settingsUpdateRate),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            prefixText: '1 USD = ',
            suffixText: 'EGP',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.commonCancel),
          ),
          FilledButton(
            onPressed: () {
              final v = double.tryParse(ctrl.text.trim());
              Navigator.pop(ctx, v);
            },
            child: Text(l.commonSave),
          ),
        ],
      ),
    );
    if (picked != null && picked > 0) {
      await ref.read(appSettingsProvider.notifier).setUsdToEgpRate(picked);
    }
  }

  Future<void> _showAutoLockPicker(
      BuildContext context, WidgetRef ref, int current) async {
    final l = AppLocalizations.of(context);
    final options = [
      (0, l.settingsAutoLockNever),
      (30, l.settingsAutoLock30s),
      (60, l.settingsAutoLock1m),
      (300, l.settingsAutoLock5m),
    ];
    final picked = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l.settingsAutoLockTimeout),
        children: options
            .map((o) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, o.$1),
                  child: Text(o.$2),
                ))
            .toList(),
      ),
    );
    if (picked != null) {
      await ref.read(appSettingsProvider.notifier).setAutoLockSeconds(picked);
    }
  }

  Future<void> _showReminderDaysPicker(
      BuildContext context, WidgetRef ref, int current) async {
    final l = AppLocalizations.of(context);
    final picked = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l.settingsReminderDays),
        children: [0, 1, 2, 3, 5, 7]
            .map((d) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, d),
                  child: Text(d == 0 ? l.settingsRemindersOff : '$d'),
                ))
            .toList(),
      ),
    );
    if (picked != null) {
      await ref.read(appSettingsProvider.notifier).setReminderDaysBefore(picked);
      // If user enabled reminders (days > 0), request notification permission
      // at this point — not on app startup.
      if (picked > 0) {
        await _ensureNotificationPermission(context, ref);
      }
    }
  }

  /// Requests notification permission at the point where it makes sense
  /// (when the user actually enables bill reminders). Avoids pestering
  /// the user on app startup.
  Future<void> _ensureNotificationPermission(
      BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context);
    final notif = ref.read(notificationServiceProvider);
    final result = await notif.requestPermission();
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    switch (result) {
      case NotificationPermissionResult.granted:
        messenger.showSnackBar(
          SnackBar(content: Text(l.notifPermGranted)),
        );
      case NotificationPermissionResult.denied:
        messenger.showSnackBar(
          SnackBar(content: Text(l.notifPermDenied)),
        );
      case NotificationPermissionResult.permanentlyDenied:
        // Show a snackbar with action to open app settings.
        messenger.showSnackBar(
          SnackBar(
            content: Text(l.notifPermPermanentlyDenied),
            duration: const Duration(seconds: 6),
          ),
        );
    }
  }

  Future<void> _toggleAppLock(
      BuildContext context, WidgetRef ref, bool enable) async {
    if (enable) {
      // Require PIN setup first.
      final set = await _promptCreatePin(context, ref);
      if (set) {
        await ref.read(appSettingsProvider.notifier).setAppLock(true);
      }
    } else {
      final l = AppLocalizations.of(context);
      // Confirm before disabling.
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l.settingsAppLock),
          content: Text(l.settingsEraseConfirm),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l.commonCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l.commonOk),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      await ref.read(appSettingsProvider.notifier).setAppLock(false);
      await ref.read(securityServiceProvider).clearPin();
    }
  }

  Future<void> _toggleBiometric(
      BuildContext context, WidgetRef ref, bool enable) async {
    final l = AppLocalizations.of(context);
    final sec = ref.read(securityServiceProvider);
    if (enable) {
      final availability = await sec.checkBiometricAvailability();
      if (!context.mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      switch (availability) {
        case BiometricAvailability.available:
          // Verify the user can actually authenticate before enabling.
          final ok = await sec.authenticateBiometric(reason: l.biometricPrompt);
          if (ok) {
            await ref.read(appSettingsProvider.notifier).setBiometric(true);
          } else {
            messenger.showSnackBar(
              SnackBar(content: Text(l.biometricFailed)),
            );
          }
        case BiometricAvailability.notEnrolled:
          messenger.showSnackBar(
            SnackBar(
              content: Text(l.biometricNotEnrolled),
              duration: const Duration(seconds: 5),
            ),
          );
        case BiometricAvailability.noHardware:
        case BiometricAvailability.unavailable:
          messenger.showSnackBar(
            SnackBar(content: Text(l.biometricUnavailable)),
          );
      }
    } else {
      await ref.read(appSettingsProvider.notifier).setBiometric(false);
    }
  }

  Future<bool> _promptCreatePin(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context);
    final first = await showPinEntryDialog(
      context,
      title: l.pinCreateTitle,
      subtitle: l.pinCreateSubtitle,
    );
    if (first == null || first.length != 6) return false;
    final second = await showPinEntryDialog(
      context,
      title: l.pinConfirmTitle,
      subtitle: l.pinConfirmSubtitle,
    );
    if (second == null || second != first) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.pinMismatch)),
        );
      }
      return false;
    }
    await ref.read(securityServiceProvider).setPin(first);
    return true;
  }

  Future<void> _confirmEraseAll(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.settingsEraseAll),
        content: Text(l.settingsEraseConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: FinlensColors.expense),
            child: Text(l.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final txRepo = await ref.read(transactionRepositoryProvider.future);
    await txRepo.deleteAll();
    final sec = ref.read(securityServiceProvider);
    await sec.clearPin();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.commonDone)),
      );
    }
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        label,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _DeveloperFooter extends StatelessWidget {
  const _DeveloperFooter({required this.theme});
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          Text(
            l.developedBy,
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            l.supportEmail,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.primary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            l.socialHandle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.primary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
