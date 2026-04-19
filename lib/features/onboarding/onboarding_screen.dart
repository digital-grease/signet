import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/prefs/app_prefs.dart';

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

  static const List<_Slide> _slides = <_Slide>[
    _Slide(
      sectionTag: 'BRIEFING // 01',
      iconData: Icons.shield_outlined,
      title: 'Verify who is on the line.',
      body:
          'Deepfake voice and video can sound like anyone — a family member, '
          'a colleague, a source. When someone calls with urgency, asking '
          'for money, for help, for access, Signet lets you ask for a '
          'rotating 4-word phrase only their real phone can produce. '
          'If the words match, you know.',
    ),
    _Slide(
      sectionTag: 'BRIEFING // 02',
      iconData: Icons.qr_code_2,
      title: 'Pair once, in person.',
      body:
          'You pair two phones by scanning each other\'s QR codes while '
          "you're together. The shared secret stays on both devices — "
          'hardware-backed, offline, no cloud. Nothing to subpoena. '
          'Nothing to phish. Nothing to sync to a server that doesn\'t '
          'exist.',
    ),
    _Slide(
      sectionTag: 'BRIEFING // 03',
      iconData: Icons.record_voice_over_outlined,
      title: 'Ask for the phrase.',
      body:
          'During the call, open Signet, tap the peer, ask them to read '
          'their 4 words. Type what you hear. Green banner = verified, '
          'trust the call. Red banner = do not trust it. Hang up and '
          'call back on a number you already know.',
    ),
  ];

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
    final isLast = _page == _slides.length - 1;
    return Scaffold(
      appBar: AppBar(
        title: const Text('SIGNET'),
        actions: <Widget>[
          TextButton(
            onPressed: _finish,
            child: Text(
              isLast ? 'DONE' : 'SKIP',
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
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (_, i) => _SlideView(slide: _slides[i]),
              ),
            ),
            _ProgressDots(count: _slides.length, active: _page),
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
                child: Text(isLast ? 'GOT IT' : 'CONTINUE'),
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
