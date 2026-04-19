import 'dart:math';

import 'bip39_english_wordlist.dart';

/// A randomized two-dimensional physical challenge for liveness detection.
///
/// The action-dimension is a short, accessible instruction the counterparty
/// performs on camera. The voiced-dimension is a BIP-39 word they speak
/// aloud. Together they are a one-shot challenge that a *pre-recorded*
/// video loop can't satisfy — the attacker would need live puppet-style
/// deepfake generation that can respond to unknown-in-advance challenges
/// in under ~10 seconds. That bar is above commodity deepfake tooling at
/// time of writing.
///
/// Scope: this is **prompt-only** liveness. The app generates the prompt;
/// the *human* watches and decides ✅/❌. There is no camera pipeline, no
/// ML, and no auto-grading — those are the separate "camera-integrated"
/// feature deferred to a later plan per `.devloop/spikes/value-adds.md`.
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

  @override
  String toString() => 'LivenessPrompt(${action.name}, "$word")';
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
