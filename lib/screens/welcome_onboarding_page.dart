import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/locale/app_locale_controller.dart';
import 'language_selection_screen.dart';
import 'login_page.dart';

/// Onboarding when `seenOnboarding` is false ([StartupRouter] reads same key).
///
/// Full-screen slides; copy is baked into images:
/// 1. `welcome_hero.png` — 2. `find_the.png` — 3. `perfect.png` — 4. `artist.png` — 5. `at_the_right_price.png`
///
/// From [StartupRouter]: [onFinished] persists `seenOnboarding`; parent then shows
/// [LanguageSelectionScreen] then [LoginPage].
/// From `/welcome` only: same prefs, then language screen, then [LoginPage].
class WelcomeOnboardingPage extends StatefulWidget {
  const WelcomeOnboardingPage({super.key, this.onFinished});

  /// When set (e.g. from [StartupRouter]), prefs + parent [setState] — no [Navigator.pushReplacement].
  final Future<void> Function()? onFinished;

  static const List<String> slideAssets = [
    'assets/onboarding/welcome_hero.png',
    'assets/onboarding/find_the.png',
    'assets/onboarding/perfect.png',
    'assets/onboarding/artist.png',
    'assets/onboarding/at_the_right_price.png',
  ];

  @override
  State<WelcomeOnboardingPage> createState() => _WelcomeOnboardingPageState();
}

class _WelcomeOnboardingPageState extends State<WelcomeOnboardingPage> {
  late final PageController _pageController;
  int _currentPage = 0;
  Timer? _autoAdvanceTimer;

  static const Duration _autoAdvanceInterval = Duration(milliseconds: 2600);

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _precacheSlides(context);
      unawaited(_warmSupabaseInBackground());
    });
    _scheduleAutoAdvance();
  }

  void _precacheSlides(BuildContext context) {
    for (final path in WelcomeOnboardingPage.slideAssets) {
      unawaited(precacheImage(AssetImage(path), context));
    }
  }

  /// Non-blocking touch of the Supabase client before login (session already restored in [main]).
  Future<void> _warmSupabaseInBackground() async {
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;
    try {
      Supabase.instance.client.auth.currentSession;
      Supabase.instance.client.auth.currentUser;
    } catch (_) {}
  }

  void _scheduleAutoAdvance() {
    _autoAdvanceTimer?.cancel();
    _autoAdvanceTimer = Timer.periodic(_autoAdvanceInterval, (_) {
      if (!mounted) return;
      if (_currentPage >= WelcomeOnboardingPage.slideAssets.length - 1) {
        return;
      }
      _pageController.nextPage(
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _autoAdvanceTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finishOnboarding() async {
    _autoAdvanceTimer?.cancel();
    if (widget.onFinished != null) {
      await widget.onFinished!();
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('seenOnboarding', true);
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (ctx) => LanguageSelectionScreen(
          onLanguageSelected: (code) async {
            await ctx.read<AppLocaleController>().setLocale(Locale(code.trim()));
            if (!ctx.mounted) return;
            await Navigator.of(ctx).pushReplacement(
              MaterialPageRoute<void>(builder: (_) => const LoginPage()),
            );
          },
        ),
      ),
    );
  }

  double _fadeOpacityFor(int index) {
    if (!_pageController.hasClients) {
      return index == 0 ? 1.0 : 0.0;
    }
    final position = _pageController.position;
    if (!position.haveDimensions) {
      return index == 0 ? 1.0 : 0.0;
    }
    final page = _pageController.page ?? _pageController.initialPage.toDouble();
    final delta = (page - index).abs();
    return (1.0 - delta).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lastIndex = WelcomeOnboardingPage.slideAssets.length - 1;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: WelcomeOnboardingPage.slideAssets.length,
            physics: const BouncingScrollPhysics(),
            onPageChanged: (i) {
              setState(() => _currentPage = i);
              if (i >= lastIndex) {
                _autoAdvanceTimer?.cancel();
              } else {
                _scheduleAutoAdvance();
              }
            },
            itemBuilder: (context, index) {
              final path = WelcomeOnboardingPage.slideAssets[index];
              return AnimatedBuilder(
                animation: _pageController,
                builder: (context, child) {
                  return Opacity(opacity: _fadeOpacityFor(index), child: child);
                },
                child: SizedBox.expand(
                  child: Image.asset(
                    path,
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                    gaplessPlayback: true,
                    errorBuilder: (_, __, ___) => const ColoredBox(
                      color: Colors.black,
                      child: Center(
                        child: Icon(
                          Icons.image_not_supported,
                          color: Colors.white54,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 4),
                child: TextButton(
                  onPressed: _finishOnboarding,
                  child: Text(
                    'Skip',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.95),
                      fontWeight: FontWeight.w600,
                      shadows: [
                        Shadow(
                          blurRadius: 8,
                          color: Colors.black.withValues(alpha: 0.55),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SmoothPageIndicator(
                      controller: _pageController,
                      count: WelcomeOnboardingPage.slideAssets.length,
                      effect: ExpandingDotsEffect(
                        expansionFactor: 3.2,
                        spacing: 8,
                        radius: 8,
                        dotWidth: 8,
                        dotHeight: 8,
                        activeDotColor: theme.colorScheme.primary,
                        dotColor: Colors.white.withValues(alpha: 0.45),
                      ),
                    ),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 280),
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      child: _currentPage == lastIndex
                          ? Padding(
                              key: const ValueKey('started'),
                              padding: const EdgeInsets.only(top: 20),
                              child: SizedBox(
                                width: double.infinity,
                                child: FilledButton(
                                  onPressed: _finishOnboarding,
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                  ),
                                  child: const Text('Get Started'),
                                ),
                              ),
                            )
                          : const SizedBox(key: ValueKey('spacer'), height: 62),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
