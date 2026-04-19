import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/crypto/totp_words.dart';
import '../../core/models/relationship.dart';
import '../../core/providers.dart';
import '../../core/theme/signet_theme.dart';
import '../../shared/widgets/secure_screen.dart';
import '../../shared/widgets/words_display.dart';
import 'word_input.dart';

/// Verify — "operator" layout.
///
/// Primary action is type-and-verify: the caller reads their 4 words aloud,
/// the receiver types them into a 4-slot autocomplete input, and `TotpWords`
/// returns a binary ✅/❌ with ±1 window tolerance absorbing clock drift
/// silently. Result surfaces as a STATUS-prefixed banner with a tactical
/// left-bar accent.
///
/// Secondary (collapsed by default) is show-my-own-words for when the other
/// party wants to verify *this* device. The rotating 4 words tick once a
/// second, same cadence as the pair-time ticker pattern. An amber
/// `FLAG_SECURE` badge on the section signals that screenshots are blocked
/// while this panel is open (platform call lands in Task 9.4).
class VerifyScreen extends ConsumerStatefulWidget {
  const VerifyScreen({super.key, required this.relationshipId});

  /// Which relationship to verify. Routed from `/verify/:id` at app.dart.
  final String relationshipId;

  @override
  ConsumerState<VerifyScreen> createState() => _VerifyScreenState();
}

enum _VerifyStatus { verified, notVerified }

class _VerifyResult {
  const _VerifyResult(this.status, this.at);
  final _VerifyStatus status;
  final DateTime at;
}

class _VerifyScreenState extends ConsumerState<VerifyScreen>
    with WidgetsBindingObserver {
  static const int _windowSeconds = TotpWords.defaultTimeStepSeconds;

  Relationship? _relationship;
  List<int>? _secret;
  Object? _loadError;
  Timer? _ticker;
  List<String> _ownWords = const <String>[];
  int _secondsRemaining = _windowSeconds;

  int _resetKey = 0;
  _VerifyResult? _lastResult;
  bool _showOwnWords = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_bootstrap());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Suspend the 1s ticker while the app is not in the foreground. Without
    // this the verify screen keeps re-deriving TOTP words every second even
    // when it's not visible, which burns CPU and (with FLAG_SECURE) leaves
    // the most recent words derived in Dart memory longer than necessary.
    // On resume, re-derive immediately (the next-window cutover may have
    // happened while backgrounded) and restart the periodic tick.
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        _ticker?.cancel();
        _ticker = null;
      case AppLifecycleState.resumed:
        if (_secret != null && _relationship != null && _ticker == null) {
          unawaited(_tick());
          _ticker = Timer.periodic(
            const Duration(seconds: 1),
            (_) => unawaited(_tick()),
          );
        }
    }
  }

  Future<void> _bootstrap() async {
    try {
      final store = ref.read(secureStoreProvider);
      final relationship =
          await store.getRelationshipById(widget.relationshipId);
      final secret = relationship == null
          ? null
          : await store.getSharedSecretById(relationship.id);
      if (!mounted) return;
      if (relationship == null || secret == null) {
        setState(() => _loadError = StateError('No paired contact.'));
        return;
      }
      setState(() {
        _relationship = relationship;
        _secret = secret;
      });
      await _tick();
      _ticker = Timer.periodic(
        const Duration(seconds: 1),
        (_) => unawaited(_tick()),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadError = error);
    }
  }

  Future<void> _tick() async {
    final secret = _secret;
    final relationship = _relationship;
    if (secret == null || relationship == null) return;
    final nowUnix = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    // Our role emits "Show my 4 words" — this is what the other side will
    // read to verify us, and what we would read to them.
    final words = await TotpWords.generate(
      secret: secret,
      unixTimeSeconds: nowUnix,
      senderRole: relationship.role,
    );
    if (!mounted) return;
    setState(() {
      _ownWords = words;
      _secondsRemaining = _windowSeconds - (nowUnix % _windowSeconds);
    });
  }

  Future<void> _handleSubmit(List<String> candidate) async {
    final secret = _secret;
    final relationship = _relationship;
    if (secret == null || relationship == null) return;
    final nowUnix = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    // Verify against the COUNTERPARTY's role — the words the other device
    // would emit. Using our own role here would accept our own displayed
    // words reflected back at us (the reflection attack).
    final ok = await TotpWords.verify(
      secret: secret,
      candidate: candidate,
      unixTimeSeconds: nowUnix,
      senderRole: relationship.role.other,
    );
    if (!mounted) return;
    setState(() {
      _lastResult = _VerifyResult(
        ok ? _VerifyStatus.verified : _VerifyStatus.notVerified,
        DateTime.now(),
      );
      // Bump on BOTH outcomes, not just ❌. If we only bump on ❌, a prior
      // ✅ leaves `WordInput._lastSubmittedOnResetKey` pinned to the current
      // resetKey, which silently blocks every subsequent submit attempt.
      // That was the bug that made reflection attacks appear to succeed
      // live: the stale ✅ banner persisted while new keystrokes fired no
      // new verify. Bumping on ✅ too clears the slots for the next
      // verification and guarantees every real attempt actually runs.
      _resetKey++;
    });
    // Silent-mode: per-relationship opt-in to suppress haptics. A buzzing
    // phone is an observable tell in coercion / surveillance scenarios —
    // journalist/activist audience wants this off. Default (false) matches
    // grandma-test expectations.
    if (!relationship.silentHaptics) {
      if (ok) {
        unawaited(HapticFeedback.lightImpact());
      } else {
        unawaited(HapticFeedback.heavyImpact());
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // FLAG_SECURE wraps the entire Verify screen: rotating words + the
    // collapsed Show-my-words pane + any banner text are all inside and
    // therefore covered. The flag clears when the user navigates away.
    return SecureScreen(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('VERIFY'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/'),
          ),
        ),
        body: SafeArea(
          child: _buildBody(context),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loadError != null) {
      return _VerifyError(
        message: 'Could not read your paired contact.',
        detail: _loadError.toString(),
        onBack: () => context.go('/'),
      );
    }
    final relationship = _relationship;
    if (relationship == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final scheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Align(
            alignment: Alignment.centerRight,
            child: _StatusChip(label: 'OFFLINE-FREE', tone: _Tone.ok),
          ),
          const SizedBox(height: 16),
          const _SectionHeader('CHALLENGE'),
          const SizedBox(height: 6),
          Text(
            'Ask ${relationship.label} for their 4 words.',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Type what you hear. Tap a suggestion to fill a slot.',
            style: TextStyle(
              fontSize: 13,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          if (_lastResult != null) ...<Widget>[
            _ResultBanner(
              result: _lastResult!,
              relationshipLabel: relationship.label,
            ),
            const SizedBox(height: 20),
          ],
          const _SectionHeader('INPUT'),
          const SizedBox(height: 8),
          WordInput(
            onSubmit: _handleSubmit,
            resetKey: _resetKey,
          ),
          const SizedBox(height: 24),
          _OwnWordsSection(
            label: relationship.label,
            expanded: _showOwnWords,
            onToggle: () => setState(() => _showOwnWords = !_showOwnWords),
            words: _ownWords,
            secondsRemaining: _secondsRemaining,
          ),
          const SizedBox(height: 16),
          // Liveness-challenge entry point. Sibling to Show-my-words —
          // the user reaches for this when the call has video and they
          // want to defeat a pre-recorded puppet in addition to the
          // rotating-word verify.
          _LivenessEntry(
            label: relationship.label,
            onTap: () =>
                context.go('/liveness/${widget.relationshipId}'),
          ),
          const SizedBox(height: 24),
          Divider(color: scheme.outlineVariant),
          const SizedBox(height: 12),
          Text(
            'AIRPLANE // NO NETWORK · NO TELEMETRY · STRONGBOX',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 10,
              color: scheme.onSurfaceVariant,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultBanner extends StatelessWidget {
  const _ResultBanner({required this.result, required this.relationshipLabel});

  final _VerifyResult result;
  final String relationshipLabel;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isOk = result.status == _VerifyStatus.verified;

    // Tokens live in core/theme/signet_theme.dart. The banner intentionally
    // uses hard-coded tokens rather than scheme-derived roles: the ✅/❌
    // affordance must read as *unambiguous* across light/dark, and Material
    // 3's `primaryContainer` / `errorContainer` derivations drift against
    // our palette in ways that blur that semantics.
    final bg = isOk
        ? (isDark ? SignetTokens.okBg : SignetTokens.okBgL)
        : (isDark ? SignetTokens.failBg : SignetTokens.failBgL);
    final fg = isOk
        ? (isDark ? SignetTokens.okFg : SignetTokens.okFgL)
        : (isDark ? SignetTokens.failFg : SignetTokens.failFgL);
    final accent = isOk ? SignetTokens.ok : SignetTokens.fail;
    final statusCode = isOk ? 'STATUS // 200 OK' : 'STATUS // 403 MISMATCH';
    final headline = isOk ? 'VERIFIED' : 'NOT VERIFIED — BE SUSPICIOUS';
    final subline = isOk
        ? 'The words match. You can trust this call.'
        : 'The words did not match. Someone may be impersonating them.';

    return Semantics(
      liveRegion: true,
      container: true,
      label: '$headline. $subline',
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          border: Border(left: BorderSide(color: accent, width: 4)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                statusCode,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 10,
                  color: accent,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                headline,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subline,
                style: TextStyle(
                  fontSize: 13,
                  color: fg,
                  height: 1.4,
                ),
              ),
              if (!isOk) ...<Widget>[
                const SizedBox(height: 12),
                Builder(builder: (ctx) {
                  return OutlinedButton(
                    onPressed: () => _showEducation(ctx, relationshipLabel),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: accent,
                      side: BorderSide(color: accent, width: 1),
                    ),
                    child: const Text('WHAT SHOULD I DO?'),
                  );
                }),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static Future<void> _showEducation(
    BuildContext context,
    String label,
  ) async {
    final scheme = Theme.of(context).colorScheme;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: scheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetCtx) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  'IF VERIFY FAILS //',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: scheme.error,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Something is wrong with this call.',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 20),
                const _EduStep(
                  number: '01',
                  text: 'Hang up. Do not explain why. Do not argue. Do '
                      "not agree to anything they're asking for.",
                ),
                _EduStep(
                  number: '02',
                  text: 'Call $label back on a number you have used '
                      'before — saved in your contacts, written down, '
                      'something you know. Do not use a number the '
                      'caller gave you.',
                ),
                _EduStep(
                  number: '03',
                  text: 'If $label does not answer, call a family '
                      'member or someone close who can physically '
                      'check on them. A real $label will never be '
                      'upset that you checked.',
                ),
                _EduStep(
                  number: '04',
                  text: 'If you are unsure whether Signet itself is '
                      'broken: go to the home screen, tap '
                      '"SHOW BINDING PHRASE", and compare with '
                      '$label on a channel you trust. If the '
                      'phrases match, Signet is working correctly '
                      'and the red banner means the call was fake.',
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.of(sheetCtx).pop(),
                  child: const Text('GOT IT'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _EduStep extends StatelessWidget {
  const _EduStep({required this.number, required this.text});
  final String number;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 36,
            child: Text(
              number,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: scheme.primary,
                letterSpacing: 1.5,
              ),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: scheme.onSurface,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LivenessEntry extends StatelessWidget {
  const _LivenessEntry({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: <Widget>[
              Icon(Icons.visibility_outlined, color: scheme.onSurfaceVariant),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'LIVENESS CHALLENGE //',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 10,
                        color: scheme.onSurfaceVariant,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'On video? Ask $label to do a physical challenge '
                      'only a live human can.',
                      style: TextStyle(
                        fontSize: 13,
                        color: scheme.onSurface,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _OwnWordsSection extends StatelessWidget {
  const _OwnWordsSection({
    required this.label,
    required this.expanded,
    required this.onToggle,
    required this.words,
    required this.secondsRemaining,
  });

  final String label;
  final bool expanded;
  final VoidCallback onToggle;
  final List<String> words;
  final int secondsRemaining;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      color: scheme.surfaceContainerHighest,
      child: Column(
        children: <Widget>[
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: <Widget>[
                  Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Show my 4 words',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'If $label wants to verify you, read these.',
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'FLAG_SECURE',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10,
                      color: scheme.secondary,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: words.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : WordsDisplay(
                      words: words,
                      secondsRemaining: secondsRemaining,
                      windowSeconds: _VerifyScreenState._windowSeconds,
                    ),
            ),
        ],
      ),
    );
  }
}

class _VerifyError extends StatelessWidget {
  const _VerifyError({
    required this.message,
    required this.detail,
    required this.onBack,
  });

  final String message;
  final String detail;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.error_outline,
            size: 48,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(message, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              detail,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: onBack, child: const Text('Back to home')),
        ],
      ),
    );
  }
}

// -------- Private operator primitives. Dup of home_screen.dart's privates;
// hoist to lib/shared/widgets/operator_primitives.dart when a third consumer
// needs them (probably the pair flow redesign follow-up). Keeping duplicated
// for now to avoid a no-op abstraction.

enum _Tone { ok, warn, fail }

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.tone});
  final String label;
  final _Tone tone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (tone) {
      _Tone.ok => scheme.primary,
      _Tone.warn => scheme.secondary,
      _Tone.fail => scheme.error,
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(Icons.circle, size: 8, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 11,
            color: color,
            letterSpacing: 1.8,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      '$label //',
      style: TextStyle(
        fontFamily: 'monospace',
        fontSize: 10,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        letterSpacing: 2,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
