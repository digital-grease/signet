import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/prefs/app_prefs.dart';
import '../../l10n/app_localizations.dart';

/// First-run walkthrough. Three pages of operator-styled copy explaining
/// (1) what Signet is for, (2) how pairing works, (3) how to verify a
/// call. Renders on first launch before Home; reachable later via the
/// Home AppBar overflow → "Show intro" entry.
///
/// Persistence: completion flag stored via [AppPrefs]. Not sensitive —
/// lives in SharedPreferences, not SecureStore.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.prefs});

  final AppPrefs prefs;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _page = 0;

  static List<_Slide> _slides(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return <_Slide>[
      _Slide(
        sectionTag: l10n.onboardingBriefingTag1,
        iconData: Icons.shield_outlined,
        title: l10n.onboardingSlide1Title,
        body: l10n.onboardingSlide1Body,
      ),
      _Slide(
        sectionTag: l10n.onboardingBriefingTag2,
        iconData: Icons.qr_code_2,
        title: l10n.onboardingSlide2Title,
        body: l10n.onboardingSlide2Body,
      ),
      _Slide(
        sectionTag: l10n.onboardingBriefingTag3,
        iconData: Icons.record_voice_over_outlined,
        title: l10n.onboardingSlide3Title,
        body: l10n.onboardingSlide3Body,
      ),
    ];
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await widget.prefs.setOnboardingCompleted(true);
    if (!mounted) return;
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final slides = _slides(context);
    final isLast = _page == slides.length - 1;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.commonAppTitle),
        actions: <Widget>[
          TextButton(
            onPressed: _finish,
            child: Text(
              isLast ? l10n.commonDone : l10n.onboardingSkipButton,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: scheme.primary,
                letterSpacing: 2,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: slides.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (_, i) => _SlideView(slide: slides[i]),
              ),
            ),
            _ProgressDots(count: slides.length, active: _page),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: FilledButton(
                onPressed: () {
                  if (isLast) {
                    _finish();
                  } else {
                    _controller.nextPage(
                      duration: const Duration(milliseconds: 240),
                      curve: Curves.easeOut,
                    );
                  }
                },
                child: Text(isLast ? l10n.commonGotIt : l10n.onboardingContinueButton),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Slide {
  const _Slide({
    required this.sectionTag,
    required this.iconData,
    required this.title,
    required this.body,
  });

  final String sectionTag;
  final IconData iconData;
  final String title;
  final String body;
}

class _SlideView extends StatelessWidget {
  const _SlideView({required this.slide});
  final _Slide slide;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            slide.sectionTag,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              color: scheme.primary,
              letterSpacing: 2,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          Center(
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                border: Border.all(color: scheme.primary, width: 2),
              ),
              child: Center(
                child: Icon(slide.iconData, size: 52, color: scheme.primary),
              ),
            ),
          ),
          const SizedBox(height: 40),
          Text(
            slide.title,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            slide.body,
            style: TextStyle(
              fontSize: 14,
              color: scheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

class _ProgressDots extends StatelessWidget {
  const _ProgressDots({required this.count, required this.active});
  final int count;
  final int active;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        for (var i = 0; i < count; i++)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: 32,
            height: 3,
            color:
                i == active ? scheme.primary : scheme.outlineVariant,
          ),
      ],
    );
  }
}
