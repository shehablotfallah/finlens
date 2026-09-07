import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../core/constants/app_constants.dart';

/// Full About screen — app info, features, privacy, developer section,
/// and contact links. Replaces the previous simple AlertDialog.
///
/// Opens external links (Facebook profile, mailto:) using url_launcher.
/// All strings are localized. Layout is RTL-friendly via built-in
/// Material widget mirroring.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  Future<void> _openUrl(BuildContext context, String url) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final uri = Uri.parse(url);
    try {
      final ok = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
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
      appBar: AppBar(
        title: Text(l.settingsAbout),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            // App icon + name + version
            _AppHeader(theme: theme, l: l),
            const SizedBox(height: 24),

            // What is it?
            _Section(
              theme: theme,
              icon: Icons.savings_outlined,
              title: l.aboutAppLabel,
              children: [
                Text(
                  l.aboutAppTagline,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l.aboutAppDescription,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      '${l.aboutVersion}: ',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      AppConstants.appVersion,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Features
            _Section(
              theme: theme,
              icon: Icons.checklist_outlined,
              title: l.aboutFeaturesTitle,
              children: [
                Text(
                  l.aboutFeaturesBody,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    height: 1.6,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Privacy
            _Section(
              theme: theme,
              icon: Icons.lock_outline,
              title: l.aboutPrivacyTitle,
              children: [
                Text(
                  l.aboutPrivacyBody,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Developer
            _Section(
              theme: theme,
              icon: Icons.person_outline,
              title: l.aboutDeveloperTitle,
              children: [
                _InfoRow(
                  label: l.aboutDeveloperRole,
                  value: AppConstants.developerRole,
                  theme: theme,
                ),
                const Divider(height: 24),
                _InfoRow(
                  label: l.aboutDeveloperEducation,
                  value: AppConstants.education,
                  theme: theme,
                ),
                const Divider(height: 24),
                _InfoRow(
                  label: l.aboutDeveloperGraduated,
                  value: AppConstants.graduationYear,
                  theme: theme,
                ),
                const Divider(height: 24),
                Text(
                  l.aboutTechStackTitle,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: AppConstants.techStack
                      .map(
                        (t) => Chip(
                          label: Text(t),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                          labelStyle: theme.textTheme.labelSmall,
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Contact & social
            _Section(
              theme: theme,
              icon: Icons.alternate_email,
              title: l.aboutContactTitle,
              children: [
                _ContactRow(
                  theme: theme,
                  icon: Icons.facebook_outlined,
                  label: l.aboutContactFacebook,
                  value: AppConstants.developerHandle,
                  onTap: () => _openUrl(context, AppConstants.facebookUrl),
                  actionLabel: l.aboutOpenInBrowser,
                ),
                const Divider(height: 24),
                _ContactRow(
                  theme: theme,
                  icon: Icons.alternate_email,
                  label: l.aboutContactHandle,
                  value: AppConstants.developerHandle,
                  onTap: () => _openUrl(
                    context,
                    'https://github.com/${AppConstants.developerHandle.replaceAll('@', '')}',
                  ),
                  actionLabel: l.aboutOpenInBrowser,
                ),
                const Divider(height: 24),
                _ContactRow(
                  theme: theme,
                  icon: Icons.email_outlined,
                  label: l.aboutContactEmail,
                  value: AppConstants.supportEmail,
                  onTap: () => _openEmail(context, AppConstants.supportEmail),
                  actionLabel: l.aboutSendEmail,
                  secondaryAction: _CopyAction(
                    label: l.aboutCopyEmail,
                    onTap: () =>
                        _copyEmail(context, AppConstants.supportEmail),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Footer
            Center(
              child: Text(
                l.aboutYearBuilt,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
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

// ---------------------------------------------------------------------------
// Reusable widgets
// ---------------------------------------------------------------------------

class _AppHeader extends StatelessWidget {
  const _AppHeader({required this.theme, required this.l});
  final ThemeData theme;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Icon(
            Icons.savings_outlined,
            size: 56,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          AppConstants.appName,
          style: theme.textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          l.aboutAppTagline,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.theme,
    required this.icon,
    required this.title,
    required this.children,
  });
  final ThemeData theme;
  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    required this.theme,
  });
  final String label;
  final String value;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _CopyAction {
  const _CopyAction({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.theme,
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    required this.actionLabel,
    this.secondaryAction,
  });
  final ThemeData theme;
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  final String actionLabel;
  final _CopyAction? secondaryAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 20, color: theme.colorScheme.primary),
        ),
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
              const SizedBox(height: 2),
              Text(
                value,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: onTap,
          child: Text(actionLabel),
        ),
        if (secondaryAction != null)
          TextButton(
            onPressed: secondaryAction!.onTap,
            child: Text(secondaryAction!.label),
          ),
      ],
    );
  }
}
