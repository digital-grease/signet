import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/crypto/totp_words.dart';
import '../../core/logging/breadcrumb.dart';
import '../../core/models/relationship.dart';
import '../../core/providers.dart';
import '../../core/theme/signet_theme.dart';
import '../../l10n/app_localizations.dart';
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
  const VerifyScreen({
    super.key,
    required this.relationshipId,
    this.initialVideoMode = false,
    this.unixTimeSecondsProvider = _realUnixTimeSeconds,
  });

  /// Which relationship to verify. Routed from `/verify/:id` at app.dart.
  final String relationshipId;

  /// Whether to open with the "video call" toggle pre-enabled. The query
  /// parameter `?video=1` (legacy `/liveness/:id` redirect) flips this on.
  final bool initialVideoMode;

  /// Injection seam for the unix-time-seconds reading used by every
  /// TotpWords derivation on this screen. Production uses the real wall
  /// clock via [_realUnixTimeSeconds]; widget tests pass a fixed-clock
  /// function so the test's own derivation matches what the screen
  /// derives internally — without this, a test running at the boundary
  /// of a 30-second window can derive at T, the screen pumps at T+ε in
  /// the next window, and the candidate mismatches.
  final int Function() unixTimeSecondsProvider;

  @override
  ConsumerState<VerifyScreen> createState() => _VerifyScreenState();
}

int _realUnixTimeSeconds() =>
    DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;

enum _VerifyStatus { verified, notVerified }

/// One attempt's outcome. In plain (non-video) mode, only [wordsStatus]
/// is load-bearing; [actionRequired] is false and [actionStatus] is null.
/// In video mode, [actionRequired] is true and [actionStatus] is null
/// until the verifier taps SAW IT / DID NOT SEE, at which point the
/// overall banner resolves.
class _VerifyResult {
  const _VerifyResult({
    required this.wordsStatus,
    required this.actionRequired,
    required this.at,
    this.actionStatus,
  });

  final _VerifyStatus wordsStatus;
  final bool actionRequired;
  final _VerifyStatus? actionStatus;
  final DateTime at;

  /// True when the verifier has confirmed both sub-checks (or the only
  /// required check, in plain mode) came back verified.
  bool get isOverallVerified =>
      wordsStatus == _VerifyStatus.verified &&
      (!actionRequired || actionStatus == _VerifyStatus.verified);

  /// True when any required sub-check came back as notVerified.
  bool get isOverallFailed =>
      wordsStatus == _VerifyStatus.notVerified ||
      (actionRequired && actionStatus == _VerifyStatus.notVerified);

  /// True when video-mode words have verified but the action has not yet
  /// been judged by the verifier. The banner defers until this resolves.
  bool get awaitingActionJudgment =>
      actionRequired &&
      wordsStatus == _VerifyStatus.verified &&
      actionStatus == null;
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

  // Video-mode state. When true, the verify flow requires a second
  // sub-check: the verifier visually confirms the counterparty performed
  // the secret-derived physical action during the current window. See
  // .devloop/plan.md Phase 14 for the threat-model rationale.
  late bool _videoMode;
  // What the counterparty should be doing right now (derived from
  // counterparty's role). Alice watches for this on video.
  LivenessAction? _expectedAction;
  // What THIS device should be doing right now (derived from our own
  // role). Shown inside the Show-my-4-words panel when video mode is on
  // so the other side can verify us symmetrically.
  LivenessAction? _ownAction;

  @override
  void initState() {
    super.initState();
    _videoMode = widget.initialVideoMode;
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
      ref
          .read(debugLogProvider)
          .log(BreadcrumbEvent.verifyOpen, relationship: relationship);
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
    final nowUnix = widget.unixTimeSecondsProvider();
    // Our role emits "Show my 4 words" — this is what the other side will
    // read to verify us, and what we would read to them.
    final words = await TotpWords.generate(
      secret: secret,
      unixTimeSeconds: nowUnix,
      senderRole: relationship.role,
    );
    // Always derive both sides of the liveness action so toggling video
    // mode is instant (~2 HKDF-SHA-256 calls is cheap). Counterparty's
    // action is what Alice watches for on video; own action is what Alice
    // would perform if Bob is verifying her.
    final expected = await TotpWords.deriveLivenessAction(
      secret: secret,
      unixTimeSeconds: nowUnix,
      senderRole: relationship.role.other,
    );
    final own = await TotpWords.deriveLivenessAction(
      secret: secret,
      unixTimeSeconds: nowUnix,
      senderRole: relationship.role,
    );
    if (!mounted) return;
    setState(() {
      _ownWords = words;
      _expectedAction = expected;
      _ownAction = own;
      _secondsRemaining = _windowSeconds - (nowUnix % _windowSeconds);
    });
  }

  void _toggleVideoMode(bool next) {
    if (next == _videoMode) return;
    setState(() {
      _videoMode = next;
      // Only reset when a prior attempt has already resolved to a
      // banner — that state carries a mode-specific judgment (or a
      // pending action-judgment in video mode) that would become
      // inconsistent with the new mode. Typed-but-unsubmitted words in
      // the input field carry no such state; preserving them lets the
      // user toggle mid-typing without losing their place.
      if (_lastResult != null) {
        _lastResult = null;
        _resetKey++;
      }
    });
  }

  Future<void> _handleSubmit(List<String> candidate) async {
    final secret = _secret;
    final relationship = _relationship;
    if (secret == null || relationship == null) return;
    ref
        .read(debugLogProvider)
        .log(BreadcrumbEvent.verifyStart, relationship: relationship);
    final nowUnix = widget.unixTimeSecondsProvider();
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
    ref.read(debugLogProvider).log(
          ok
              ? BreadcrumbEvent.verifyResultPass
              : BreadcrumbEvent.verifyResultFail,
          relationship: relationship,
        );
    final wordsStatus =
        ok ? _VerifyStatus.verified : _VerifyStatus.notVerified;
    setState(() {
      _lastResult = _VerifyResult(
        wordsStatus: wordsStatus,
        actionRequired: _videoMode,
        at: DateTime.now(),
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
    // Haptic policy:
    // - Words ❌: immediate heavy — the attempt has already failed
    //   overall, even in video mode.
    // - Words ✅ + plain mode: light — overall pass is now confirmed.
    // - Words ✅ + video mode: no immediate haptic. Defer to action
    //   judgment where the overall outcome actually resolves.
    if (!relationship.silentHaptics) {
      if (!ok) {
        unawaited(HapticFeedback.heavyImpact());
      } else if (!_videoMode) {
        unawaited(HapticFeedback.lightImpact());
      }
    }
  }

  void _handleActionJudgment(_VerifyStatus status) {
    final prior = _lastResult;
    final relationship = _relationship;
    if (prior == null || !prior.awaitingActionJudgment) return;
    setState(() {
      _lastResult = _VerifyResult(
        wordsStatus: prior.wordsStatus,
        actionRequired: true,
        actionStatus: status,
        at: DateTime.now(),
      );
    });
    if (relationship != null && !relationship.silentHaptics) {
      final ok = status == _VerifyStatus.verified;
      unawaited(ok
          ? HapticFeedback.lightImpact()
          : HapticFeedback.heavyImpact());
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
          title: Text(AppLocalizations.of(context).verifyTitle),
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
        message: AppLocalizations.of(context).verifyLoadError,
        detail: _loadError.toString(),
        onBack: () => context.go('/'),
      );
    }
    final relationship = _relationship;
    if (relationship == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final scheme = Theme.of(context).colorScheme;
    final result = _lastResult;
    final showBanner =
        result != null && !result.awaitingActionJudgment;
    final showActionJudgment =
        result != null && result.awaitingActionJudgment;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Align(
            alignment: Alignment.centerRight,
            child: _StatusChip(
              label: AppLocalizations.of(context).commonOfflineFreeChip,
              tone: _Tone.ok,
            ),
          ),
          const SizedBox(height: 16),
          _VideoModeToggle(
            value: _videoMode,
            onChanged: _toggleVideoMode,
          ),
          const SizedBox(height: 16),
          _SectionHeader(
            AppLocalizations.of(context).verifySectionChallenge,
          ),
          const SizedBox(height: 6),
          Text(
            AppLocalizations.of(context)
                .verifyAskForWordsHeading(relationship.label),
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            AppLocalizations.of(context).verifyTypeInstruction,
            style: TextStyle(
              fontSize: 13,
              color: scheme.onSurfaceVariant,
            ),
          ),
          if (_videoMode && _expectedAction != null) ...<Widget>[
            const SizedBox(height: 14),
            _ExpectedActionRow(
              label: relationship.label,
              action: _expectedAction!,
            ),
          ],
          const SizedBox(height: 20),
          if (showBanner) ...<Widget>[
            _ResultBanner(
              result: result,
              relationshipLabel: relationship.label,
            ),
            const SizedBox(height: 20),
          ],
          _SectionHeader(
            AppLocalizations.of(context).verifySectionInput,
          ),
          const SizedBox(height: 8),
          WordInput(
            onSubmit: _handleSubmit,
            resetKey: _resetKey,
          ),
          if (showActionJudgment && _expectedAction != null) ...<Widget>[
            const SizedBox(height: 20),
            _ActionJudgmentPanel(
              label: relationship.label,
              action: _expectedAction!,
              onSaw: () => _handleActionJudgment(_VerifyStatus.verified),
              onNotSeen: () =>
                  _handleActionJudgment(_VerifyStatus.notVerified),
            ),
          ],
          const SizedBox(height: 24),
          _OwnWordsSection(
            label: relationship.label,
            expanded: _showOwnWords,
            onToggle: () => setState(() => _showOwnWords = !_showOwnWords),
            words: _ownWords,
            secondsRemaining: _secondsRemaining,
            videoModeAction: _videoMode ? _ownAction : null,
          ),
          const SizedBox(height: 24),
          Divider(color: scheme.outlineVariant),
          const SizedBox(height: 12),
          Text(
            AppLocalizations.of(context).commonAirplaneFooter,
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
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isOk = result.isOverallVerified;

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
    final statusCode = isOk ? l10n.verifyStatusOk : l10n.verifyStatusFail;
    final headline =
        isOk ? l10n.verifyBannerVerified : l10n.verifyBannerNotVerified;
    final subline = _sublineFor(result, isOk, l10n);

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
                    child: Text(l10n.verifyWhatShouldIDoButton),
                  );
                }),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _sublineFor(
    _VerifyResult result,
    bool isOk,
    AppLocalizations l10n,
  ) {
    if (isOk) {
      if (result.actionRequired) {
        return l10n.verifySublineVerifiedWithAction;
      }
      return l10n.verifySublineVerified;
    }
    if (result.wordsStatus == _VerifyStatus.notVerified) {
      return l10n.verifySublineWordsMismatch;
    }
    // Words verified but action missed — only reachable in video mode.
    return l10n.verifySublineActionMismatch;
  }

  static Future<void> _showEducation(
    BuildContext context,
    String label,
  ) async {
    final l10n = AppLocalizations.of(context);
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
                  l10n.verifyFailHeader,
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
                  l10n.verifyFailHeading,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 20),
                _EduStep(
                  number: '01',
                  text: l10n.verifyFailStep1,
                ),
                _EduStep(
                  number: '02',
                  text: l10n.verifyFailStep2(label),
                ),
                _EduStep(
                  number: '03',
                  text: l10n.verifyFailStep3(label),
                ),
                _EduStep(
                  number: '04',
                  text: l10n.verifyFailStep4(label),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.of(sheetCtx).pop(),
                  child: Text(l10n.commonGotIt),
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

/// Toggle for "video call mode" — folds the deepfake-resistant liveness
/// check into the normal verify flow. See .devloop/plan.md Phase 14.
class _VideoModeToggle extends StatelessWidget {
  const _VideoModeToggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    // MergeSemantics folds the native Switch node into the outer
    // toggled/label container so TalkBack / VoiceOver announces the row
    // as a single "Video call mode, on/off switch" — without it the
    // screen reader reads the two nodes separately and users bounce
    // between them to find the tap target.
    return MergeSemantics(
      child: Semantics(
        label: l10n.verifyVideoModeSemanticsLabel,
        hint: l10n.verifyVideoModeSemanticsHint,
        toggled: value,
        child: Material(
          color: scheme.surfaceContainerHighest,
          child: InkWell(
            onTap: () => onChanged(!value),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
              child: Row(
                children: <Widget>[
                  Icon(
                    value
                        ? Icons.videocam_outlined
                        : Icons.videocam_off_outlined,
                    color: value ? scheme.primary : scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          l10n.verifyVideoModeHeader,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 10,
                            color: value
                                ? scheme.primary
                                : scheme.onSurfaceVariant,
                            letterSpacing: 2,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          value
                              ? l10n.verifyVideoModeOnText
                              : l10n.verifyVideoModeOffText,
                          style: TextStyle(
                            fontSize: 13,
                            color: scheme.onSurface,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: value,
                    onChanged: onChanged,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The "Watch for: *Touch left ear*" line that appears under CHALLENGE
/// when video mode is on.
class _ExpectedActionRow extends StatelessWidget {
  const _ExpectedActionRow({required this.label, required this.action});

  final String label;
  final LivenessAction action;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    // liveRegion: true so TalkBack / VoiceOver re-announces the expected
    // action when it changes on window rollover. Without it, a blind user
    // watching the video can hear the first-derived action but misses the
    // cutover to the next one 30 seconds later.
    return Semantics(
      container: true,
      liveRegion: true,
      label: l10n.verifyExpectedActionSemantics(
        label,
        action.humanReadable,
      ),
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            border: Border(left: BorderSide(color: scheme.primary, width: 3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                l10n.verifyWatchForHeader,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 10,
                  color: scheme.primary,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.verifyExpectedActionText(label, action.humanReadable),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Appears after a words-✅ in video mode: the verifier judges whether
/// they *actually saw* the expected action on camera.
class _ActionJudgmentPanel extends StatelessWidget {
  const _ActionJudgmentPanel({
    required this.label,
    required this.action,
    required this.onSaw,
    required this.onNotSeen,
  });

  final String label;
  final LivenessAction action;
  final VoidCallback onSaw;
  final VoidCallback onNotSeen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    // liveRegion: true so the "Words ✅. Did you see …" prompt is
    // announced the moment it replaces the words-input once the
    // verifier's typed 4 words have verified. Without it, a blind user
    // doesn't know the UI has moved from "type words" to "judge action."
    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          border: Border(left: BorderSide(color: scheme.secondary, width: 3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              l10n.verifyActionHeader,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 10,
                color: scheme.secondary,
                letterSpacing: 2,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.verifyActionJudgmentPrompt(label, action.humanReadable),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: onNotSeen,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: scheme.error,
                      side: BorderSide(color: scheme.error),
                    ),
                    child: Text(l10n.verifyActionNotSeenButton),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: onSaw,
                    child: Text(l10n.verifyActionSeenButton),
                  ),
                ),
              ],
            ),
          ],
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
    this.videoModeAction,
  });

  final String label;
  final bool expanded;
  final VoidCallback onToggle;
  final List<String> words;
  final int secondsRemaining;

  /// When non-null (i.e. video mode is on), the own-role action the
  /// counterparty expects THIS device's user to perform. Displayed
  /// symmetric to the "WATCH FOR //" row on the other side's screen.
  final LivenessAction? videoModeAction;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
                          l10n.verifyShowMyWords,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l10n.verifyShowMyWordsSubtitle(label),
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    l10n.verifyFlagSecureBadge,
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
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        WordsDisplay(
                          words: words,
                          secondsRemaining: secondsRemaining,
                          windowSeconds: _VerifyScreenState._windowSeconds,
                        ),
                        if (videoModeAction != null) ...<Widget>[
                          const SizedBox(height: 10),
                          Text(
                            l10n.verifyOwnActionWhile(
                              _gerundFor(videoModeAction!, l10n),
                            ),
                            style: TextStyle(
                              fontSize: 14,
                              fontStyle: FontStyle.italic,
                              color: scheme.onSurface,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
        ],
      ),
    );
  }

  /// "Touch the tip of your nose" → "touching the tip of your nose" —
  /// stitches into "...while touching the tip of your nose." cleanly.
  /// Keep this list in lockstep with `LivenessAction.humanReadable`; if a
  /// new action lands, add its gerund here and the test in
  /// `liveness_challenge_test.dart` will catch the omission via its
  /// "exactly 8 curated actions" assertion.
  static String _gerundFor(LivenessAction action, AppLocalizations l10n) {
    switch (action) {
      case LivenessAction.lookUp:
        return l10n.verifyGerundLookUp;
      case LivenessAction.lookDown:
        return l10n.verifyGerundLookDown;
      case LivenessAction.lookLeft:
        return l10n.verifyGerundLookLeft;
      case LivenessAction.lookRight:
        return l10n.verifyGerundLookRight;
      case LivenessAction.touchNose:
        return l10n.verifyGerundTouchNose;
      case LivenessAction.touchForehead:
        return l10n.verifyGerundTouchForehead;
      case LivenessAction.touchLeftEar:
        return l10n.verifyGerundTouchLeftEar;
      case LivenessAction.touchRightEar:
        return l10n.verifyGerundTouchRightEar;
    }
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
          FilledButton(
            onPressed: onBack,
            child: Text(AppLocalizations.of(context).verifyBackHomeButton),
          ),
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
      label,
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
