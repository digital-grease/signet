/// The gestures video-mode verify asks for.
///
/// `TotpWords.deriveLivenessAction` keys one of these to the pair's shared
/// secret and the 30-second window (HKDF-SHA-256), so passing a video-mode
/// verify requires both the secret and a live human. `TotpWords`
/// re-exports [LivenessAction].
///
/// History: the v0.3 prompt-only flow minted a gesture plus an English
/// word from local `Random.secure()`. It carried no binding to the secret,
/// so a realtime deepfake could hear the prompt and perform it; it was
/// replaced in Phase 14 and its generator removed in v0.5.0 (plan Task
/// 1.2), the last word surface fixed to English.
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
library;

/// The curated set of physical actions. Do not extend without considering
/// accessibility (see the library docs above).
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
