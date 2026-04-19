import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/crypto/liveness_challenge.dart';
import '../../core/providers.dart';
import '../../shared/widgets/secure_screen.dart';

/// Prompt-only liveness challenge screen.
///
/// Generates a random two-dimensional physical challenge (action + voiced
/// word) and displays it for the verifier to read aloud to the
/// counterparty. A 10-second countdown runs in the header; after that the
/// verifier judges ✅/❌ based on what they saw on the video call. No
/// camera access, no ML, no auto-grading — the human decides.
///
/// Entry points:
/// - From VerifyScreen: a "Liveness challenge" link below the main verify
///   flow. Used for video calls where a pre-recorded deepfake is the
///   concern. Complements (not replaces) the rotating-word verify.
/// - From HomeScreen long-press menu: a direct "Liveness challenge"
///   shortcut when the user knows they're on video and wants to start
///   there.
///
/// Wrapped in `SecureScreen`: screenshots or screen recording of the
/// prompt would let an attacker pre-record an answer for *that specific
/// challenge*. Minting a fresh prompt per invocation defeats that, but
/// blocking screen capture is cheap defense-in-depth.
class LivenessScreen extends ConsumerStatefulWidget {
  const LivenessScreen({super.key, required this.relationshipId});

  /// Which peer this challenge is for. Used for the "Ask $label to..."
  /// copy; does not gate access (any paired relationship can liveness-
  /// challenge any other person, since the challenge is general-purpose).
  final String relationshipId;

  /// Duration of the countdown. Default 10 seconds — short enough that
  /// real-time deepfake systems can't reasonably compute a response,
  /// long enough that a live human has plenty of time to perform.
  /// Overridable for tests.
  static const Duration defaultCountdown = Duration(seconds: 10);

  @override
  ConsumerState<LivenessScreen> createState() => _LivenessScreenState();
}

class _LivenessScreenState extends ConsumerState<LivenessScreen> {
  late LivenessPrompt _prompt;
  Timer? _ticker;
  int _secondsRemaining = LivenessScreen.defaultCountdown.inSeconds;
  _Outcome? _outcome;
  String? _label;

  @override
  void initState() {
    super.initState();
    _prompt = LivenessChallenge.mint();
    _loadLabel();
    _startTicker();
  }

  Future<void> _loadLabel() async {
    final store = ref.read(secureStoreProvider);
    final relationship =
        await store.getRelationshipById(widget.relationshipId);
    if (!mounted) return;
    setState(() => _label = relationship?.label ?? 'your peer');
  }

  void _startTicker() {
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_secondsRemaining > 0) _secondsRemaining--;
        if (_secondsRemaining == 0) _ticker?.cancel();
      });
    });
  }

  void _recordOutcome(_Outcome outcome) {
    setState(() => _outcome = outcome);
    // Outcome is local and in-memory for v0.2 — persistent log is a later
    // plan's work. The Verify-screen route returns the user to the
    // normal flow with a brief result indication.
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SecureScreen(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('LIVENESS'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => context.go('/'),
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: _outcome == null ? _buildPromptPane() : _buildOutcomePane(),
          ),
        ),
      ),
    );
  }

  Widget _buildPromptPane() {
    final scheme = Theme.of(context).colorScheme;
    final expired = _secondsRemaining == 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const _SectionHeader('CHALLENGE'),
        const SizedBox(height: 8),
        Text(
          'Ask ${_label ?? 'them'} to do this, live on camera. A pre-recorded '
          "video loop won't match — but a real human will.",
          style: TextStyle(
            fontSize: 13,
            color: scheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(20),
          color: scheme.surfaceContainerHighest,
          child: Text(
            _prompt.instruction,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
              height: 1.3,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              expired ? Icons.timer_off : Icons.timer,
              size: 18,
              color: expired ? scheme.secondary : scheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              expired
                  ? 'TIME EXPIRED // Generate a new one'
                  : 'TIME REMAINING // ${_secondsRemaining}s',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: expired ? scheme.secondary : scheme.primary,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const Spacer(),
        if (expired) ...<Widget>[
          FilledButton(
            onPressed: () {
              // Mint a new prompt and restart the countdown. The expired
              // challenge is discarded so an observer who saw it can't
              // replay as-is.
              _ticker?.cancel();
              setState(() {
                _prompt = LivenessChallenge.mint();
                _secondsRemaining =
                    LivenessScreen.defaultCountdown.inSeconds;
              });
              _startTicker();
            },
            child: const Text('NEW CHALLENGE'),
          ),
        ] else ...<Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _recordOutcome(_Outcome.failed),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: scheme.error,
                    side: BorderSide(color: scheme.error),
                  ),
                  child: const Text('THEY FAILED'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => _recordOutcome(_Outcome.passed),
                  child: const Text('THEY PASSED'),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildOutcomePane() {
    final scheme = Theme.of(context).colorScheme;
    final isOk = _outcome == _Outcome.passed;
    final accent = isOk ? scheme.primary : scheme.error;
    final headline = isOk ? 'LIVE HUMAN VERIFIED' : 'LIVENESS FAILED';
    final subline = isOk
        ? '${_label ?? 'They'} responded correctly on camera. '
            'This is not a substitute for the rotating-word verify — do '
            'that too if the call is asking for something serious.'
        : '${_label ?? 'They'} did not match the challenge. Combined with a '
            'red rotating-word verify, this is a strong signal to hang up '
            'and call back on a known number.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            border: Border(left: BorderSide(color: accent, width: 4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'OUTCOME //',
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
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subline,
                style: TextStyle(
                  fontSize: 13,
                  color: scheme.onSurface,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        FilledButton(
          onPressed: () => context.go('/verify/${widget.relationshipId}'),
          child: const Text('BACK TO VERIFY'),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: () => context.go('/'),
          child: const Text('BACK TO HOME'),
        ),
      ],
    );
  }
}

enum _Outcome { passed, failed }

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
