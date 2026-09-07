import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../data/services/security_service.dart';
import '../app/providers.dart';

/// Lock screen shown when [AppLockState.isLocked] is true.
///
/// UX flow:
///   1. If biometric is enabled AND available AND enrolled → auto-prompt.
///      If success → unlock. If fail/cancel → fall back to PIN entry.
///   2. If biometric is unavailable OR not enrolled → go straight to PIN.
///   3. PIN entry: 4 digits, then verify. Wrong PIN shows error + clears.
///   4. A "Use biometric" button is shown below the keypad so the user
///      can retry biometric at any time (instead of being forced into
///      a single auto-prompt at screen entry).
///
/// Security notes:
///   * The lock screen is shown by the EntryGate, which is a
///     synchronous gate on [AppLockState.isLocked]. The MainShell
///     (protected content) is never built while this screen is shown.
///   * System back button is intercepted to prevent the user from
///     dismissing the lock screen without authenticating.
///   * No transaction data is loaded before this screen.
class AppLockScreen extends ConsumerStatefulWidget {
  const AppLockScreen({super.key});

  @override
  ConsumerState<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends ConsumerState<AppLockScreen> {
  final _input = StringBuffer();
  bool _error = false;
  bool _checkingBiometric = false;
  bool _biometricAvailable = false;
  bool _autoBiometricAttempted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    final settings = ref.read(appSettingsProvider);
    if (!settings.biometricEnabled) {
      return;
    }
    final sec = ref.read(securityServiceProvider);
    final availability = await sec.checkBiometricAvailability();
    if (!mounted) return;
    setState(() {
      _biometricAvailable =
          availability == BiometricAvailability.available;
    });
    if (_biometricAvailable && !_autoBiometricAttempted) {
      _autoBiometricAttempted = true;
      await _tryBiometric();
    }
  }

  Future<void> _tryBiometric() async {
    final l = AppLocalizations.of(context);
    setState(() {
      _checkingBiometric = true;
      _error = false;
    });
    final sec = ref.read(securityServiceProvider);
    final ok = await sec.authenticateBiometric(reason: l.biometricPrompt);
    if (!mounted) return;
    setState(() => _checkingBiometric = false);
    if (ok) {
      ref.read(appLockProvider.notifier).unlock();
    }
    // If failed/cancelled, stay on PIN entry — don't show error
    // because the user explicitly chose to cancel.
  }

  void _onKey(String digit) async {
    if (_input.length >= 4) return;
    setState(() {
      _input.write(digit);
      _error = false;
    });
    if (_input.length == 4) {
      final pin = _input.toString();
      // Clear immediately so the dots animate off.
      setState(() {});
      await Future<void>.delayed(const Duration(milliseconds: 120));
      if (!mounted) return;
      final sec = ref.read(securityServiceProvider);
      final ok = await sec.verifyPin(pin);
      if (!mounted) return;
      if (ok) {
        ref.read(appLockProvider.notifier).unlock();
      } else {
        setState(() {
          _input.clear();
          _error = true;
        });
        HapticFeedback.heavyImpact();
      }
    }
  }

  void _backspace() {
    if (_input.isEmpty) return;
    setState(() {
      // Remove last digit from the StringBuffer.
      final s = _input.toString();
      _input.clear();
      _input.write(s.substring(0, s.length - 1));
      _error = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    // Intercept system back button so the user can't dismiss the lock.
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 2),
                Icon(
                  _checkingBiometric
                      ? Icons.fingerprint
                      : Icons.lock_outline,
                  size: 72,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  _checkingBiometric ? l.biometricPrompt : l.pinEnterTitle,
                  style: theme.textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (i) {
                    final filled = i < _input.length;
                    return Container(
                      width: 16,
                      height: 16,
                      margin: const EdgeInsetsDirectional.symmetric(
                        horizontal: 8,
                      ),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _error
                            ? theme.colorScheme.error
                            : filled
                                ? theme.colorScheme.primary
                                : Colors.transparent,
                        border: Border.all(
                          color: _error
                              ? theme.colorScheme.error
                              : theme.colorScheme.outline,
                          width: 1.5,
                        ),
                      ),
                    );
                  }),
                ),
                if (_error) ...[
                  const SizedBox(height: 12),
                  Text(
                    l.pinWrong,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.error),
                  ),
                ],
                const Spacer(flex: 2),
                _keypad(theme),
                if (_biometricAvailable && !_checkingBiometric) ...[
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: _tryBiometric,
                    icon: const Icon(Icons.fingerprint),
                    label: Text(l.biometricRetry),
                  ),
                ],
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _keypad(ThemeData theme) {
    return Column(
      children: [
        for (final row in [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: row
                  .map((d) => _keyButton(d, theme, () => _onKey(d)))
                  .toList(),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              const SizedBox(width: 72),
              _keyButton('0', theme, () => _onKey('0')),
              IconButton(
                onPressed: _backspace,
                icon: const Icon(Icons.backspace_outlined),
                iconSize: 28,
                color: theme.colorScheme.onSurface,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _keyButton(String d, ThemeData theme, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(36),
        child: Container(
          width: 72,
          height: 72,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: theme.colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.4),
          ),
          child: Text(
            d,
            style: theme.textTheme.displaySmall
                ?.copyWith(fontWeight: FontWeight.w500),
          ),
        ),
      ),
    );
  }
}
