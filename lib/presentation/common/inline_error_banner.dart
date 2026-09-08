import 'package:flutter/material.dart';

/// An inline error banner displayed directly inside the form/screen
/// (NOT as a transient SnackBar). Used for database errors, validation
/// failures that can't be attributed to a single field, and other
/// critical operation failures.
///
/// UX rules:
///   * Appears near the action button (typically above it).
///   * Does NOT auto-dismiss — the user must tap "Try again" or fix
///     the input to clear it.
///   * Provides a clear, localized message + an optional retry action.
///   * Visually distinct from success/info snackbars (red background,
///     warning icon).
class InlineErrorBanner extends StatelessWidget {
  const InlineErrorBanner({
    super.key,
    required this.message,
    this.onRetry,
    this.retryLabel,
    this.onDismiss,
  });

  /// The localized error message to display.
  final String message;

  /// Optional retry callback. When provided, a "Try again" button
  /// is shown.
  final VoidCallback? onRetry;

  /// Label for the retry button (localized).
  final String? retryLabel;

  /// Optional dismiss callback (small × button).
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.error.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error_outline,
            color: colorScheme.onErrorContainer,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onErrorContainer,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (onRetry != null && retryLabel != null) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: onRetry,
                    style: TextButton.styleFrom(
                      foregroundColor: colorScheme.onErrorContainer,
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(retryLabel!),
                  ),
                ],
              ],
            ),
          ),
          if (onDismiss != null)
            IconButton(
              onPressed: onDismiss,
              icon: const Icon(Icons.close, size: 18),
              color: colorScheme.onErrorContainer,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              tooltip: 'Dismiss',
            ),
        ],
      ),
    );
  }
}
