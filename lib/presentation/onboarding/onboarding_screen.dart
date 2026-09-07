import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../app/providers.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageCtrl = PageController();
  int _page = 0;

  static const _pages = <({String titleKey, String bodyKey, IconData icon})>[
    (titleKey: 'onboardingTitle1', bodyKey: 'onboardingBody1', icon: Icons.savings_outlined),
    (titleKey: 'onboardingTitle2', bodyKey: 'onboardingBody2', icon: Icons.insights_outlined),
    (titleKey: 'onboardingTitle3', bodyKey: 'onboardingBody3', icon: Icons.lock_outline),
    (titleKey: 'onboardingTitle4', bodyKey: 'onboardingBody4', icon: Icons.auto_awesome_outlined),
  ];

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < _pages.length - 1) {
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    } else {
      ref.read(appSettingsProvider.notifier).setOnboardingComplete();
    }
  }

  void _skip() {
    ref.read(appSettingsProvider.notifier).setOnboardingComplete();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Skip button — aligned to the END edge so it mirrors
            // correctly in RTL (left in LTR, right in RTL).
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Padding(
                padding: const EdgeInsetsDirectional.only(end: 8),
                child: TextButton(
                  onPressed: _skip,
                  child: Text(l.commonSkip),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageCtrl,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) {
                  final p = _pages[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 132,
                          height: 132,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            p.icon,
                            size: 64,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 32),
                        Text(
                          _localized(l, p.titleKey),
                          style: theme.textTheme.displaySmall,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _localized(l, p.bodyKey),
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: List.generate(
                      _pages.length,
                      (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsetsDirectional.only(end: 6),
                        width: i == _page ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: i == _page
                              ? theme.colorScheme.primary
                              : theme.colorScheme.outline,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  FilledButton(
                    onPressed: _next,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(120, 48),
                    ),
                    child: Text(
                      _page == _pages.length - 1 ? l.commonGetStarted : l.commonNext,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _localized(AppLocalizations l, String key) {
    // Lookup helper — AppLocalizations doesn't expose a string indexer, so
    // we resolve via a switch.
    switch (key) {
      case 'onboardingTitle1':
        return l.onboardingTitle1;
      case 'onboardingBody1':
        return l.onboardingBody1;
      case 'onboardingTitle2':
        return l.onboardingTitle2;
      case 'onboardingBody2':
        return l.onboardingBody2;
      case 'onboardingTitle3':
        return l.onboardingTitle3;
      case 'onboardingBody3':
        return l.onboardingBody3;
      case 'onboardingTitle4':
        return l.onboardingTitle4;
      case 'onboardingBody4':
        return l.onboardingBody4;
      default:
        return key;
    }
  }
}
