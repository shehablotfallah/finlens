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

  /// Each page now has a dedicated illustration image instead of a
  /// generic icon. The logo is used for page 1 (welcome), and
  /// custom illustrations for pages 2-4.
  static const _pages = <({String titleKey, String bodyKey, String image})>[
    (titleKey: 'onboardingTitle1', bodyKey: 'onboardingBody1', image: 'assets/images/finlens_logo.png'),
    (titleKey: 'onboardingTitle2', bodyKey: 'onboardingBody2', image: 'assets/images/onboarding/track_analyze.png'),
    (titleKey: 'onboardingTitle3', bodyKey: 'onboardingBody3', image: 'assets/images/onboarding/privacy.png'),
    (titleKey: 'onboardingTitle4', bodyKey: 'onboardingBody4', image: 'assets/images/onboarding/ai_insight.png'),
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
            // Skip button
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
                        // Each page has its own illustration.
                        // The logo (page 0) gets a rounded rectangle shape,
                        // the illustration images get a circular container.
                        _buildIllustration(p.image, theme),
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
                      _page == _pages.length - 1
                          ? l.commonGetStarted
                          : l.commonNext,
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

  /// Builds the illustration for each onboarding page.
  /// - Page 0 (welcome): Finlens logo in a rounded rectangle.
  /// - Pages 1-3: Custom illustrations in a circular container with
  ///   a subtle background.
  Widget _buildIllustration(String assetPath, ThemeData theme) {
    if (assetPath == 'assets/images/finlens_logo.png') {
      return ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Image.asset(
          assetPath,
          width: 140,
          height: 140,
          fit: BoxFit.cover,
        ),
      );
    }
    // Illustration — circular container with ClipRRect to prevent
    // the image from extending outside the rounded boundary.
    return ClipRRect(
      borderRadius: BorderRadius.circular(80), // half of width = circle
      child: Container(
        width: 160,
        height: 160,
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Image.asset(
            assetPath,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }

  String _localized(AppLocalizations l, String key) {
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
