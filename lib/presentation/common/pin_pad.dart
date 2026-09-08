import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_gen/gen_l10n/app_localizations.dart';

/// A self-contained, professional PIN entry widget.
///
/// UX:
///   * 4 large dot indicators at top
///   * Numeric keypad with consistent layout (1-9, then blank / 0 / backspace)
///   * Haptic feedback on each key press
///   * Clear error state (red dots + localized error message)
///   * Per-digit backspace (not all-clear)
///   * Auto-submits when 4 digits are entered (calls [onComplete])
///
/// RTL note:
///   The numeric keypad is intentionally NOT mirrored in RTL — numeric
///   keypads follow a universal convention (1-2-3 on top, 7-8-9 third
///   row, 0 at bottom-center). Mirroring it would make the keypad
///   inconsistent with system dialers / calculator apps.
///   Only the text labels and surrounding layout respect RTL.
class PinPad extends StatefulWidget {
  const PinPad({
    super.key,
    required this.length,
    required this.onComplete,
    this.errorText,
    this.enabled = true,
  });

  /// Number of digits in the PIN (typically 4).
  final int length;

  /// Called when the user has entered [length] digits.
  /// The callback receives the entered PIN string.
  final ValueChanged<String> onComplete;

  /// Optional error text shown below the dots.
  /// When set, the dots turn red and a small shake animation plays.
  final String? errorText;

  /// Whether the keypad accepts input. Set to false while the parent
  /// is verifying the PIN to prevent re-entry.
  final bool enabled;

  @override
  State<PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<PinPad>
    with SingleTickerProviderStateMixin {
  final _input = StringBuffer();
  late final AnimationController _shakeCtrl;
  late final Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeCtrl, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant PinPad oldWidget) {
    super.didUpdateWidget(oldWidget);
    // When the parent sets an error text, play the shake animation
    // and clear the input so the user can retry.
    if (widget.errorText != null && oldWidget.errorText == null) {
      _shakeCtrl.forward(from: 0);
      _input.clear();
      HapticFeedback.heavyImpact();
    }
  }

  void _onKey(String digit) {
    if (!widget.enabled) return;
    if (_input.length >= widget.length) return;
    HapticFeedback.selectionClick();
    setState(() => _input.write(digit));
    if (_input.length == widget.length) {
      final pin = _input.toString();
      // Small delay so the user sees the 4th dot fill before submit.
      Future<void>.delayed(const Duration(milliseconds: 100), () {
        widget.onComplete(pin);
      });
    }
  }

  void _backspace() {
    if (!widget.enabled) return;
    if (_input.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() {
      final s = _input.toString();
      _input.clear();
      _input.write(s.substring(0, s.length - 1));
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Dot indicators with shake animation
        AnimatedBuilder(
          animation: _shakeAnim,
          builder: (context, child) {
            // Shake horizontally using a sine curve.
            final offset = _shakeAnim.value == 0
                ? 0.0
                : 8 *
                    (1 - _shakeAnim.value) *
                    (1 + math.sin(_shakeAnim.value * 6.28) * 1.0);
            return Transform.translate(
              offset: Offset(offset, 0),
              child: child,
            );
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.length, (i) {
              final filled = i < _input.length;
              return Container(
                width: 16,
                height: 16,
                margin: const EdgeInsetsDirectional.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.errorText != null
                      ? theme.colorScheme.error
                      : filled
                          ? theme.colorScheme.primary
                          : Colors.transparent,
                  border: Border.all(
                    color: widget.errorText != null
                        ? theme.colorScheme.error
                        : theme.colorScheme.outline,
                    width: 1.5,
                  ),
                ),
              );
            }),
          ),
        ),
        if (widget.errorText != null) ...[
          const SizedBox(height: 12),
          Text(
            widget.errorText!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 32),
        _keypad(theme),
      ],
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
                onPressed: widget.enabled ? _backspace : null,
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
        onTap: widget.enabled ? onTap : null,
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
            style: theme.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

/// A dialog-style PIN entry used by the PIN-creation flow (setup wizard
/// + Settings → Change PIN). Returns the entered PIN or null if the
/// user cancels.
///
/// Uses a 6-digit PIN per the security policy (was 4 digits — upgraded
/// for stronger protection).
Future<String?> showPinEntryDialog(
  BuildContext context, {
  required String title,
  String? subtitle,
  bool barrierDismissible = false,
}) async {
  final l = AppLocalizations.of(context);
  return showDialog<String>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (ctx) {
      return AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (subtitle != null) ...[
              Text(
                subtitle,
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                      color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
            ],
            PinPad(
              length: 6,
              onComplete: (pin) => Navigator.pop(ctx, pin),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: Text(l.commonCancel),
          ),
        ],
      );
    },
  );
}
