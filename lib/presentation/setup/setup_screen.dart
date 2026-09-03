import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/finlens_theme.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../app/providers.dart';

enum _LanguageChoice { system, english, arabic }

/// Quick setup wizard that runs right after onboarding:
///   1. Language confirmation
///   2. Salary day
///   3. Base currency
///   4. Theme
///   5. (Optional) PIN / biometric setup
///   6. Done
class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key});

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen> {
  final PageController _pageCtrl = PageController();
  int _page = 0;

  // Form state
  int _salaryDay = 1;
  String _baseCurrency = 'EGP';
  FinlensThemeMode _theme = FinlensThemeMode.system;
  _LanguageChoice _languageChoice = _LanguageChoice.system;

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    if (_page < 5) {
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    } else {
      await _commit();
    }
  }

  Future<void> _commit() async {
    final notifier = ref.read(appSettingsProvider.notifier);
    await notifier.setLocale(_selectedLocale);
    await notifier.setSalaryDay(_salaryDay);
    await notifier.setBaseCurrency(_baseCurrency);
    await notifier.setThemeMode(_theme);
    await notifier.setSetupComplete();
  }

  Locale? get _selectedLocale {
    return switch (_languageChoice) {
      _LanguageChoice.system => null,
      _LanguageChoice.english => const Locale('en'),
      _LanguageChoice.arabic => const Locale('ar'),
    };
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: LinearProgressIndicator(
                value: (_page + 1) / 6,
                minHeight: 4,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageCtrl,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (index) => setState(() => _page = index),
                children: [
                  _languageStep(l, theme),
                  _salaryStep(l, theme),
                  _currencyStep(l, theme),
                  _themeStep(l, theme),
                  _securityStep(l, theme),
                  _finishStep(l, theme),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Row(
                children: [
                  if (_page > 0)
                    OutlinedButton(
                      onPressed: () {
                        _pageCtrl.previousPage(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOutCubic,
                        );
                      },
                      child: Text(l.commonBack),
                    )
                  else
                    const SizedBox(width: 0),
                  const Spacer(),
                  FilledButton(
                    onPressed: _next,
                    child: Text(_page == 5 ? l.commonGetStarted : l.commonNext),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _languageStep(AppLocalizations l, ThemeData theme) {
    return _StepLayout(
      icon: Icons.language_outlined,
      title: l.setupLanguageTitle,
      subtitle: l.setupLanguageSubtitle,
      child: Column(
        children: [
          _ChoiceTile<_LanguageChoice>(
            label: l.settingsLanguageSystem,
            value: _LanguageChoice.system,
            groupValue: _languageChoice,
            onChanged: (v) => setState(() => _languageChoice = v!),
          ),
          _ChoiceTile<_LanguageChoice>(
            label: l.settingsLanguageEn,
            value: _LanguageChoice.english,
            groupValue: _languageChoice,
            onChanged: (v) => setState(() => _languageChoice = v!),
          ),
          _ChoiceTile<_LanguageChoice>(
            label: l.settingsLanguageAr,
            value: _LanguageChoice.arabic,
            groupValue: _languageChoice,
            onChanged: (v) => setState(() => _languageChoice = v!),
          ),
        ],
      ),
    );
  }

  Widget _salaryStep(AppLocalizations l, ThemeData theme) {
    return _StepLayout(
      icon: Icons.calendar_month_outlined,
      title: l.setupSalaryDayTitle,
      subtitle: l.setupSalaryDaySubtitle,
      child: Column(
        children: [
          const SizedBox(height: 8),
          Text(
            '$_salaryDay',
            style: theme.textTheme.displayMedium?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Slider(
            min: 1,
            max: 28,
            divisions: 27,
            value: _salaryDay.toDouble(),
            onChanged: (v) => setState(() => _salaryDay = v.round()),
          ),
        ],
      ),
    );
  }

  Widget _currencyStep(AppLocalizations l, ThemeData theme) {
    return _StepLayout(
      icon: Icons.payments_outlined,
      title: l.setupCurrencyTitle,
      subtitle: l.setupCurrencySubtitle,
      child: Column(
        children: [
          _ChoiceTile<String>(
            label: 'EGP — ${l.commonCurrency}',
            value: 'EGP',
            groupValue: _baseCurrency,
            onChanged: (v) => setState(() => _baseCurrency = v!),
          ),
          _ChoiceTile<String>(
            label: 'USD — ${l.commonCurrency}',
            value: 'USD',
            groupValue: _baseCurrency,
            onChanged: (v) => setState(() => _baseCurrency = v!),
          ),
        ],
      ),
    );
  }

  Widget _themeStep(AppLocalizations l, ThemeData theme) {
    return _StepLayout(
      icon: Icons.color_lens_outlined,
      title: l.setupThemeTitle,
      subtitle: '',
      child: Column(
        children: [
          _ChoiceTile<FinlensThemeMode>(
            label: l.settingsThemeLight,
            value: FinlensThemeMode.light,
            groupValue: _theme,
            onChanged: (v) => setState(() => _theme = v!),
          ),
          _ChoiceTile<FinlensThemeMode>(
            label: l.settingsThemeDark,
            value: FinlensThemeMode.dark,
            groupValue: _theme,
            onChanged: (v) => setState(() => _theme = v!),
          ),
          _ChoiceTile<FinlensThemeMode>(
            label: l.settingsThemeAuto,
            value: FinlensThemeMode.system,
            groupValue: _theme,
            onChanged: (v) => setState(() => _theme = v!),
          ),
        ],
      ),
    );
  }

  Widget _securityStep(AppLocalizations l, ThemeData theme) {
    return _StepLayout(
      icon: Icons.lock_outline,
      title: l.setupSecurityTitle,
      subtitle: l.setupSecuritySubtitle,
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(l.setupSecuritySetup),
            subtitle: Text(l.settingsPin),
          ),
        ],
      ),
    );
  }

  Widget _finishStep(AppLocalizations l, ThemeData theme) {
    return _StepLayout(
      icon: Icons.check_circle_outline,
      title: l.setupFinishTitle,
      subtitle: l.setupFinishBody,
      child: const SizedBox.shrink(),
    );
  }
}

class _StepLayout extends StatelessWidget {
  const _StepLayout({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(icon, size: 48, color: theme.colorScheme.primary),
          const SizedBox(height: 20),
          Text(title, style: theme.textTheme.displaySmall, textAlign: TextAlign.center),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 24),
          child,
        ],
      ),
    );
  }
}

class _ChoiceTile<T> extends StatelessWidget {
  const _ChoiceTile({
    required this.label,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });
  final String label;
  final T value;
  final T? groupValue;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = value == groupValue;
    return Card(
      child: RadioListTile<T>(
        value: value,
        groupValue: groupValue,
        onChanged: onChanged,
        title: Text(label),
        activeColor: Theme.of(context).colorScheme.primary,
        selected: selected,
      ),
    );
  }
}
