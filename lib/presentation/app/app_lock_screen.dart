import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../app/providers.dart';

class AppLockScreen extends ConsumerStatefulWidget {
  const AppLockScreen({super.key});

  @override
  ConsumerState<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends ConsumerState<AppLockScreen> {
  final _input = StringBuffer();
  bool _error = false;
  bool _checkingBiometric = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryBiometric());
  }

  Future<void> _tryBiometric() async {
    final settings = ref.read(appSettingsProvider);
    if (!settings.biometricEnabled) {
      setState(() => _checkingBiometric = false);
      return;
    }
    final sec = ref.read(securityServiceProvider);
    final can = await sec.canCheckBiometrics;
    if (!can) {
      setState(() => _checkingBiometric = false);
      return;
    }
    final l = AppLocalizations.of(context);
    final ok = await sec.authenticateBiometric(reason: l.biometricPrompt);
    if (ok) {
      ref.read(appLockProvider.notifier).unlock();
    } else {
      setState(() => _checkingBiometric = false);
    }
  }

  void _onKey(String digit) async {
    if (_input.length >= 4) return;
    setState(() {
      _input.write(digit);
      _error = false;
    });
    if (_input.length == 4) {
      final pin = _input.toString();
      _input.clear();
      final sec = ref.read(securityServiceProvider);
      final ok = await sec.verifyPin(pin);
      if (ok) {
        ref.read(appLockProvider.notifier).unlock();
      } else {
        setState(() => _error = true);
        HapticFeedback.heavyImpact();
      }
    }
  }

  void _backspace() {
    if (_input.isEmpty) return;
    setState(() {
      _input.clear();
      _error = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),
              Icon(
                _checkingBiometric ? Icons.fingerprint : Icons.lock_outline,
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
                    margin: const EdgeInsetsDirectional.symmetric(horizontal: 8),
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
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                ),
              ],
              const Spacer(flex: 2),
              _keypad(theme),
              const Spacer(),
            ],
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
            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
          ),
          child: Text(
            d,
            style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w500),
          ),
        ),
      ),
    );
  }
}
