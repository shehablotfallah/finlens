import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/finlens_theme.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../app/providers.dart';

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
              onTap: () => _showExchangeRatePicker(context, ref, settings.usdToEgpRate),
            ),
            const Divider(),
            _SectionTitle(label: l.settingsSecurity),
            SwitchListTile(
              secondary: const Icon(Icons.lock_outline),
              title: Text(l.settingsAppLock),
              subtitle: Text(
                settings.appLockEnabled ? l.settingsAppLockOn : l.settingsAppLockOff,
              ),
              value: settings.appLockEnabled,
              onChanged: (v) async {
                if (v) {
                  // Require PIN setup first
                  final set = await _promptCreatePin(context, ref);
                  if (set) await notifier.setAppLock(true);
                } else {
                  await notifier.setAppLock(false);
                  await ref.read(securityServiceProvider).clearPin();
                }
              },
            ),
            if (settings.appLockEnabled) ...[
              SwitchListTile(
                secondary: const Icon(Icons.fingerprint),
                title: Text(l.settingsBiometric),
                value: settings.biometricEnabled,
                onChanged: (v) async {
                  if (v) {
                    final sec = ref.read(securityServiceProvider);
                    final can = await sec.canCheckBiometrics;
                    if (!can) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(l.commonError)),
                        );
                      }
                      return;
                    }
                  }
                  await notifier.setBiometric(v);
                },
              ),
              ListTile(
                leading: const Icon(Icons.timer_outlined),
                title: Text(l.settingsAutoLockTimeout),
                subtitle: Text(_autoLockLabel(l, settings.autoLockSeconds)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showAutoLockPicker(context, ref, settings.autoLockSeconds),
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
              subtitle: Text('${settings.reminderDaysBefore}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showReminderDaysPicker(context, ref, settings.reminderDaysBefore),
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
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showAbout(context),
            ),
            const SizedBox(height: 24),
            Padding(
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
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l.socialHandle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
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

  void _showLocalePicker(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(l.settingsLanguageSystem),
              onTap: () async {
                await ref.read(appSettingsProvider.notifier).setLocale(null);
                if (ctx.mounted) Navigator.pop(ctx);
              },
            ),
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
          decoration: const InputDecoration(prefixText: '1 USD = ', suffixText: 'EGP'),
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
    final picked = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Days before'),
        children: [0, 1, 2, 3, 5, 7]
            .map((d) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, d),
                  child: Text('$d'),
                ))
            .toList(),
      ),
    );
    if (picked != null) {
      await ref.read(appSettingsProvider.notifier).setReminderDaysBefore(picked);
    }
  }

  Future<bool> _promptCreatePin(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context);
    final first = await _promptPin(context, l.pinCreateTitle);
    if (first == null || first.length != 4) return false;
    final second = await _promptPin(context, l.pinConfirmTitle);
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

  Future<String?> _promptPin(BuildContext context, String title) async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            maxLength: 4,
            obscureText: true,
            decoration: const InputDecoration(hintText: '••••'),
            autofocus: true,
            onSubmitted: (v) => Navigator.pop(ctx, v),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: Text(AppLocalizations.of(context).commonCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text),
              child: Text(AppLocalizations.of(context).commonOk),
            ),
          ],
        );
      },
    );
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

  void _showAbout(BuildContext context) {
    final l = AppLocalizations.of(context);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.settingsAbout),
        content: SingleChildScrollView(
          child: Text(l.settingsAboutBody),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.commonClose),
          ),
        ],
      ),
    );
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
