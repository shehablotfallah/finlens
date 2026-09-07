import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/finlens_theme.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../app/providers.dart';

/// Quick setup wizard that runs right after onboarding.
/// Steps:
///   1. Language
///   2. Salary day
///   3. Base currency
///   4. Theme
///   5. (Optional) PIN setup
///   6. Summary & finish
class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key});

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen> {
  final PageController _pageCtrl = PageController();
  int _page = 0;
  static const int _totalSteps = 6;

  // Form state
  int _salaryDay = 1;
  String _baseCurrency = 'EGP';
  FinlensThemeMode _theme = FinlensThemeMode.system;
  Locale? _locale;
  bool _setupPin = false;
  bool _saving = false;

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  bool _canProceed() {
    switch (_page) {
      case 0: // language — always has a default
        return true;
      case 1: // salary day — always 1..28
        return true;
      case 2: // currency — always has a default
        return true;
      case 3: // theme — always has a default
        return true;
      case 4: // security — optional, always allowed
        return true;
      case 5: // finish
        return true;
      default:
        return true;
    }
  }

  void _next() {
    if (!_canProceed()) return;
    if (_page < _totalSteps - 1) {
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    } else {
      _commit();
    }
  }

  void _back() {
    if (_page > 0) {
      _pageCtrl.previousPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _goTo(int index) {
    _pageCtrl.animateToPage(
      index,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _commit() async {
    setState(() => _saving = true);
    final notifier = ref.read(appSettingsProvider.notifier);
    await notifier.setLocale(_locale);
    await notifier.setSalaryDay(_salaryDay);
    await notifier.setBaseCurrency(_baseCurrency);
    await notifier.setThemeMode(_theme);
    if (_setupPin) {
      // Mark app lock enabled; user will set PIN on first lock prompt
      await notifier.setAppLock(true);
    }
    await notifier.setSetupComplete();
    // _saving stays true; FinlensApp will rebuild and route to MainShell
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

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Top bar: progress + step counter
            _TopBar(
              page: _page,
              total: _totalSteps,
              stepLabel: l.setupStepOf(_page + 1, _totalSteps),
              onBack: _page > 0 ? _back : null,
            ),
            // Progress bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (_page + 1) / _totalSteps,
                  minHeight: 4,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.3),
                ),
              ),
            ),
            // Pages
            Expanded(
              child: PageView(
                controller: _pageCtrl,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _page = i),
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
            // Bottom navigation: Back + Next
            _BottomNav(
              page: _page,
              total: _totalSteps,
              canProceed: _canProceed(),
              saving: _saving,
              onBack: _back,
              onNext: _next,
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Step 1: Language
  // -------------------------------------------------------------------------
  Widget _languageStep(AppLocalizations l, ThemeData theme) {
    return _StepLayout(
      icon: Icons.language_outlined,
      title: l.setupLanguageTitle,
      subtitle: l.setupLanguageSubtitle,
      child: Column(
        children: [
          _OptionCard(
            selected: _locale == null,
            icon: Icons.devices_outlined,
            title: l.settingsLanguageSystem,
            subtitle: l.setupLanguageSystemDescription,
            onTap: () => setState(() => _locale = null),
          ),
          const SizedBox(height: 12),
          _OptionCard(
            selected: _locale == const Locale('en'),
            icon: Icons.translate_outlined,
            title: l.settingsLanguageEn,
            subtitle: l.setupLanguageEnDescription,
            trailing: const Text(
              'EN',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            onTap: () => setState(() => _locale = const Locale('en')),
          ),
          const SizedBox(height: 12),
          _OptionCard(
            selected: _locale == const Locale('ar'),
            icon: Icons.translate_outlined,
            title: l.settingsLanguageAr,
            subtitle: l.setupLanguageArDescription,
            trailing: const Text(
              'ع',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
            ),
            onTap: () => setState(() => _locale = const Locale('ar')),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Step 2: Salary day
  // -------------------------------------------------------------------------
  Widget _salaryStep(AppLocalizations l, ThemeData theme) {
    return _StepLayout(
      icon: Icons.calendar_month_outlined,
      title: l.setupSalaryDayTitle,
      subtitle: l.setupSalaryDaySubtitle,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Text(
                  l.setupSalaryDayHint,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$_salaryDay',
                  style: theme.textTheme.displayLarge?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Slider(
            min: 1,
            max: 28,
            divisions: 27,
            label: '$_salaryDay',
            value: _salaryDay.toDouble(),
            onChanged: (v) => setState(() => _salaryDay = v.round()),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('1', style: theme.textTheme.labelSmall),
              Text('28', style: theme.textTheme.labelSmall),
            ],
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Step 3: Currency
  // -------------------------------------------------------------------------
  Widget _currencyStep(AppLocalizations l, ThemeData theme) {
    return _StepLayout(
      icon: Icons.payments_outlined,
      title: l.setupCurrencyTitle,
      subtitle: l.setupCurrencySubtitle,
      child: Column(
        children: [
          _OptionCard(
            selected: _baseCurrency == 'EGP',
            icon: Icons.account_balance_wallet_outlined,
            title: 'EGP — ${l.commonCurrency}',
            subtitle: l.setupCurrencyEgpDescription,
            trailing: const Text(
              'ج.م',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
            ),
            onTap: () => setState(() => _baseCurrency = 'EGP'),
          ),
          const SizedBox(height: 12),
          _OptionCard(
            selected: _baseCurrency == 'USD',
            icon: Icons.attach_money_outlined,
            title: 'USD — ${l.commonCurrency}',
            subtitle: l.setupCurrencyUsdDescription,
            trailing: const Text(
              r'$',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
            ),
            onTap: () => setState(() => _baseCurrency = 'USD'),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Step 4: Theme
  // -------------------------------------------------------------------------
  Widget _themeStep(AppLocalizations l, ThemeData theme) {
    return _StepLayout(
      icon: Icons.color_lens_outlined,
      title: l.setupThemeTitle,
      subtitle: '',
      child: Column(
        children: [
          _OptionCard(
            selected: _theme == FinlensThemeMode.light,
            icon: Icons.light_mode_outlined,
            title: l.settingsThemeLight,
            subtitle: l.setupThemeLightDescription,
            onTap: () => setState(() => _theme = FinlensThemeMode.light),
          ),
          const SizedBox(height: 12),
          _OptionCard(
            selected: _theme == FinlensThemeMode.dark,
            icon: Icons.dark_mode_outlined,
            title: l.settingsThemeDark,
            subtitle: l.setupThemeDarkDescription,
            onTap: () => setState(() => _theme = FinlensThemeMode.dark),
          ),
          const SizedBox(height: 12),
          _OptionCard(
            selected: _theme == FinlensThemeMode.system,
            icon: Icons.brightness_auto_outlined,
            title: l.settingsThemeAuto,
            subtitle: l.setupThemeAutoDescription,
            onTap: () => setState(() => _theme = FinlensThemeMode.system),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Step 5: Security
  // -------------------------------------------------------------------------
  Widget _securityStep(AppLocalizations l, ThemeData theme) {
    return _StepLayout(
      icon: Icons.lock_outline,
      title: l.setupSecurityTitle,
      subtitle: l.setupSecurityDescription,
      child: Column(
        children: [
          _OptionCard(
            selected: _setupPin,
            icon: Icons.shield_outlined,
            title: l.setupSecuritySetup,
            subtitle: l.setupSecurityPinNote,
            trailing: Switch(
              value: _setupPin,
              onChanged: (v) => setState(() => _setupPin = v),
            ),
            onTap: () => setState(() => _setupPin = !_setupPin),
          ),
          const SizedBox(height: 12),
          _OptionCard(
            selected: !_setupPin,
            icon: Icons.lock_open_outlined,
            title: l.setupSecuritySkip,
            subtitle: l.commonOptional,
            onTap: () => setState(() => _setupPin = false),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Step 6: Summary & finish
  // -------------------------------------------------------------------------
  Widget _finishStep(AppLocalizations l, ThemeData theme) {
    return _StepLayout(
      icon: Icons.check_circle_outline,
      title: l.setupFinishTitle,
      subtitle: l.setupFinishBody,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l.setupFinishSummary,
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.start,
          ),
          const SizedBox(height: 12),
          _SummaryRow(
            label: l.setupSummaryLanguage,
            value: _localeLabel(l, _locale),
            icon: Icons.language_outlined,
            onEdit: () => _goTo(0),
            editLabel: l.setupEdit,
          ),
          _SummaryRow(
            label: l.setupSummarySalaryDay,
            value: '$_salaryDay',
            icon: Icons.calendar_month_outlined,
            onEdit: () => _goTo(1),
            editLabel: l.setupEdit,
          ),
          _SummaryRow(
            label: l.setupSummaryCurrency,
            value: _baseCurrency,
            icon: Icons.payments_outlined,
            onEdit: () => _goTo(2),
            editLabel: l.setupEdit,
          ),
          _SummaryRow(
            label: l.setupSummaryTheme,
            value: _themeLabel(l, _theme),
            icon: Icons.color_lens_outlined,
            onEdit: () => _goTo(3),
            editLabel: l.setupEdit,
          ),
          _SummaryRow(
            label: l.setupSummarySecurity,
            value: _setupPin ? l.setupSummaryOn : l.setupSummaryOff,
            icon: Icons.lock_outline,
            onEdit: () => _goTo(4),
            editLabel: l.setupEdit,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Reusable widgets
// ---------------------------------------------------------------------------

/// Top bar with back button + step counter
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.page,
    required this.total,
    required this.stepLabel,
    required this.onBack,
  });
  final int page;
  final int total;
  final String stepLabel;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      child: Row(
        children: [
          if (onBack != null)
            IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_outlined),
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            )
          else
            const SizedBox(width: 48),
          const Spacer(),
          Text(
            stepLabel,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom navigation with Back + Next/Finish buttons
class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.page,
    required this.total,
    required this.canProceed,
    required this.saving,
    required this.onBack,
    required this.onNext,
  });
  final int page;
  final int total;
  final bool canProceed;
  final bool saving;
  final VoidCallback onBack;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isLast = page == total - 1;
    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Row(
        children: [
          if (page > 0)
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_outlined),
                label: Text(l.commonBack),
              ),
            )
          else
            const Spacer(),
          if (page > 0) const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              onPressed: (canProceed && !saving) ? onNext : null,
              icon: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(isLast ? Icons.check : Icons.arrow_forward_outlined),
              label: Text(
                isLast ? l.commonGetStarted : l.commonNext,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Step layout with icon + title + subtitle + content
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
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 36,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
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
          const SizedBox(height: 28),
          child,
        ],
      ),
    );
  }
}

/// Selectable option card with icon, title, subtitle, optional trailing widget
class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });
  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: selected
          ? theme.colorScheme.primaryContainer
          : theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outlineVariant,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: selected
                      ? theme.colorScheme.primary.withValues(alpha: 0.15)
                      : theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: selected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing!,
              ] else if (selected)
                Icon(
                  Icons.check_circle,
                  color: theme.colorScheme.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Summary row showing the user's choice with an Edit button
class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.onEdit,
    required this.editLabel,
  });
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onEdit;
  final String editLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  value,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onEdit,
            child: Text(editLabel),
          ),
        ],
      ),
    );
  }
}
