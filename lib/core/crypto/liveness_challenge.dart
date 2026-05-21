import 'dart:math';

import 'bip39_english_wordlist.dart';

/// Historical — pre-secret-derivation prompt generator.
///
/// The v0.3 prompt-only liveness flow minted challenges with local
/// `Random.secure()`, betting that commodity deepfake tooling couldn't
/// respond to an unknown-in-advance prompt inside a 10-second window.
/// That assumption decayed as realtime voice+video deepfakes improved:
/// a secret-less attacker who can puppet Bob's likeness in under a
/// second hears the prompt Alice reads and performs it on the fly.
///
/// The current flow lives in `TotpWords.deriveLivenessAction`, which
/// keys the action to the pair's shared secret via HKDF-SHA-256 — so
/// passing the combined verify requires BOTH secret possession AND a
/// live human. See `.devloop/plan.md` Phase 14 for the migration.
///
/// [LivenessAction] stays here as the accessibility-curated corpus;
/// `TotpWords` re-exports it. [LivenessChallenge.mint] is deprecated and
/// retained for one release so in-flight alpha callers don't hard-fail;
/// it will be removed after the video-mode verify ships.
///
/// Accessibility constraints applied to the action corpus:
/// - No prompts requiring fine motor control (no finger counts — excludes
///   users with hand differences).
/// - No prompts requiring specific vision cues to perform (the action
///   itself is describable, not "follow the dot").
/// - No facial-expression prompts (excludes Bell's palsy etc.).
/// - No standing / walking prompts (excludes wheelchair users).
/// - Symmetric head-turns and face-touches work for almost everyone who
///   can move their head and hands at all.
class LivenessChallenge {
  const LivenessChallenge._();

  /// Mint a fresh prompt. Uses [Random.secure] by default; a seeded
  /// [Random] is accepted for test determinism.
  @Deprecated(
    'Use TotpWords.deriveLivenessAction — secret-derived, HKDF-keyed to '
    'the pair shared secret, defeats secret-less realtime deepfake '
    'attackers. Removed in the release after 0.3.x.',
  )
  static LivenessPrompt mint({Random? random}) {
    final rng = random ?? Random.secure();
    final action =
        LivenessAction.values[rng.nextInt(LivenessAction.values.length)];
    final word =
        bip39EnglishWordlist[rng.nextInt(bip39EnglishWordlist.length)];
    return LivenessPrompt(action: action, word: word);
  }

  /// How many distinct prompts the corpus can produce (actions × words).
  /// Currently 8 × 2048 = 16,384 — enough that attackers can't precompute
  /// every variant, and every challenge is fresh to the user.
  static int get corpusSize =>
      LivenessAction.values.length * bip39EnglishWordlist.length;
}

/// One minted challenge. Immutable; safe to pass across widget boundaries.
class LivenessPrompt {
  const LivenessPrompt({required this.action, required this.word});

  final LivenessAction action;
  final String word;

  /// Human-readable instruction combining action + voiced word. Shown
  /// to the verifier so they can read it aloud to the counterparty.
  String get instruction => '${action.humanReadable} and say "$word"';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LivenessPrompt && action == other.action && word == other.word;

  @override
  int get hashCode => Object.hash(action, word);

  // The word is low-medium sensitive per the threat model (fingerprints the
  // window + lets attacker pre-rehearse). Kept out of toString so the primary
  // code-side defense holds even if a LivenessPrompt slips into a crash report.
  // `leak_prevention_test.dart` enforces this invariant.
  @override
  String toString() => 'LivenessPrompt(${action.name}, "[redacted]")';
}

/// The curated set of physical actions used by the prompt-only liveness
/// flow. Do not extend without considering accessibility (see the
/// docstring on [LivenessChallenge]).
enum LivenessAction {
  lookUp('Look up at the ceiling'),
  lookDown('Look down at the floor'),
  lookLeft('Look over your left shoulder'),
  lookRight('Look over your right shoulder'),
  touchNose('Touch the tip of your nose'),
  touchForehead('Touch your forehead'),
  touchLeftEar('Touch your left ear'),
  touchRightEar('Touch your right ear');

  const LivenessAction(this.humanReadable);

  /// Instruction text shown on-screen. Short enough to read aloud in
  /// under 2 seconds.
  final String humanReadable;
}
