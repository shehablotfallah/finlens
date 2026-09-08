import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../core/constants/app_constants.dart';

/// Full About screen — explains what Finlens is, the privacy philosophy,
/// and a concise developer credit at the bottom.
///
/// DESIGN PHILOSOPHY:
///   This is NOT a developer CV / portfolio page. The application is
///   the focus. The developer section is intentionally minimal:
///   name, role, and contact links (Facebook, LinkedIn, WhatsApp, email).
///
/// VISUAL HIERARCHY:
///   1. App identity (logo, name, tagline, version)
///   2. Short description
///   3. Privacy banner
///   4. Contact links (4 polished cards)
///   5. Developer credit (name + role)
///   6. Footer ("Privacy-first. Local-first.")
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  Future<void> _openUrl(BuildContext context, String url) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final uri = Uri.parse(url);
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(l.aboutFailedToOpen)),
        );
      }
    } catch (_) {
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(l.aboutFailedToOpen)),
        );
      }
    }
  }

  Future<void> _openEmail(BuildContext context, String email) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final uri = Uri(scheme: 'mailto', path: email);
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(l.aboutFailedToOpen)),
        );
      }
    } catch (_) {
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(l.aboutFailedToOpen)),
        );
      }
    }
  }

  void _copyEmail(BuildContext context, String email) async {
    final l = AppLocalizations.of(context);
    await Clipboard.setData(ClipboardData(text: email));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.aboutEmailCopied)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.settingsAbout)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
          children: [
            // App identity
            Center(
              child: Column(
                children: [
                  // Use the actual Finlens logo image instead of a generic icon
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.asset(
                      'assets/images/finlens_logo.png',
                      width: 96,
                      height: 96,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    AppConstants.appName,
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l.aboutAppTagline,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${l.aboutVersion} ${AppConstants.appVersion}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Short description
            Text(
              l.aboutAppDescription,
              style: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),

            // Privacy banner
            _PrivacyBanner(theme: theme, l: l),
            const SizedBox(height: 32),

            // Contact links grid (2x2)
            Text(
              l.aboutContactTitle,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _ContactCard(
                    theme: theme,
                    icon: Icons.facebook_outlined,
                    label: l.aboutContactFacebook,
                    color: const Color(0xFF1877F2),
                    onTap: () =>
                        _openUrl(context, AppConstants.facebookUrl),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ContactCard(
                    theme: theme,
                    icon: Icons.business_center_outlined,
                    label: l.aboutContactLinkedIn,
                    color: const Color(0xFF0A66C2),
                    onTap: () =>
                        _openUrl(context, AppConstants.linkedInUrl),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _ContactCard(
                    theme: theme,
                    icon: Icons.chat_outlined,
                    label: l.aboutContactWhatsApp,
                    color: const Color(0xFF25D366),
                    onTap: () =>
                        _openUrl(context, AppConstants.whatsappUrl),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ContactCard(
                    theme: theme,
                    icon: Icons.email_outlined,
                    label: l.aboutContactEmail,
                    color: theme.colorScheme.primary,
                    onTap: () =>
                        _openEmail(context, AppConstants.supportEmail),
                    onLongPress: () =>
                        _copyEmail(context, AppConstants.supportEmail),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 36),

            // Developer credit
            Center(
              child: Column(
                children: [
                  Text(
                    l.aboutMadeBy,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    AppConstants.developer,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l.aboutSoftwareEngineer,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Footer
            Center(
              child: Text(
                l.aboutLocalFirstFooter,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrivacyBanner extends StatelessWidget {
  const _PrivacyBanner({required this.theme, required this.l});
  final ThemeData theme;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.lock_outline,
            size: 20,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.aboutPrivacyTitle,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l.aboutPrivacyBody,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({
    required this.theme,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.onLongPress,
  });
  final ThemeData theme;
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 28, color: color),
              const SizedBox(height: 8),
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
