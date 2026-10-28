import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/crypto/pairing.dart';
import '../../core/crypto/pairing_commitment.dart';
import '../../core/crypto/verification.dart';
import '../../core/crypto/wordlists.dart';
import 'pairing_code_v2.dart';

/// In-person pairing with commit-then-reveal (plan Task 1.7e; design in
/// `.devloop/spikes/pairing-commitment.md`, option C):
///
///   Start                          Join
///   shows C = commit(pub1, n1)  -> scans C, only now mints (pub2, priv2)
///   scans K = pub2              <- shows K
///   shows R = pub1 || n1        -> scans R, checks it opens C
///   both derive the 4-word phrase from ECDH and the transcript
///
/// A man-in-the-middle must fix the key it gives Start before Start's key
/// is revealed, so it gets one blind guess per attempt (2^-44). That only
/// holds if keys and nonces are single-use: every way out of an attempt
/// (abort, failure, timeout, reset, a new [InPersonPairingController.begin])
/// drops them, and every attempt mints new ones. "Drops" means the
/// controller forgets its references; Dart cannot zero memory, so the
/// garbage collector reclaims the bytes later. Private keys and nonces
/// never enter [InPersonPairingState].

enum InPersonRole { start, join }

enum InPersonStep {
  /// No attempt running: pick Start or Join.
  chooseRole,

  /// Start: QR-1 (the commitment) on screen until the user says the other
  /// phone has scanned it. No QR yet while the key is being minted.
  startShowCommit,

  /// Start: scanning Join's key.
  startScanKey,

  /// Start: QR-3 (the reveal) on screen until the user says the other
  /// phone has scanned it.
  startShowReveal,

  /// Join: scanning Start's commitment.
  joinScanCommit,

  /// Join: QR-2 (its key) on screen until the user says the other phone
  /// has scanned it (a Join "Next" tap; the spike's sketch had none, but
  /// a phone cannot tell when its QR was scanned). A reveal scanned or
  /// pasted in this step is accepted too.
  joinShowKey,

  /// Join: scanning Start's reveal.
  joinScanReveal,

  /// Computing the phrase (Argon2id, about 0.1-0.9 s).
  deriving,

  /// Phrase ready to compare.
  confirm,

  /// The attempt ended; see [InPersonPairingState.failure]. Its keys are
  /// dropped. The other phone does not know: the UI says to start over on
  /// both phones.
  failed,
}

/// Why an attempt ended. Each has its own message in the UI.
enum InPersonFailure {
  /// Start scanned a commitment: the other phone also chose Start.
  startStart,

  /// Join scanned a key before any commitment: the other phone also chose
  /// Join.
  joinJoin,

  /// A second, different code of a kind already accepted.
  secondCode,

  /// A valid code of a kind this step never accepts.
  wrongCodeForStep,

  /// The reveal did not open the commitment from step 1: the code from
  /// step 1 didn't match (tampering, or two different Start phones).
  revealMismatch,

  /// A low-order or reflected key (see [WeakPublicKeyException]).
  weakKey,

  /// The UI's idle timer ran out ([InPersonPairingController.timeOut]).
  timedOut,

  /// Anything unexpected (key generation or derivation threw).
  internal,
}

typedef KeyPairFactory = Future<PairingKeyPair> Function();
typedef NonceFactory = Uint8List Function();
typedef InPersonPhraseDeriver = Future<List<String>> Function({
  required List<int> sharedSecret,
  required List<int> ownPublicKey,
  required List<int> peerPublicKey,
  required List<int> nonce,
});

/// Where keys come from. Tests override it to record what is handed out.
final Provider<KeyPairFactory> inPersonKeyPairFactoryProvider =
    Provider<KeyPairFactory>(
        (ref) => PairingHandshake.generateEphemeralKeyPair);

/// Where Start's commitment nonces come from.
final Provider<NonceFactory> inPersonNonceFactoryProvider =
    Provider<NonceFactory>((ref) => PairingCommitment.newNonce);

/// The phrase derivation. Production always uses the pinned Argon2id cost;
/// tests swap in cheap parameters.
final Provider<InPersonPhraseDeriver> inPersonPhraseDeriverProvider =
    Provider<InPersonPhraseDeriver>(
        (ref) => PairingVerification.deriveInPersonPhrase);

@immutable
class InPersonPairingState {
  const InPersonPairingState({
    this.label,
    this.rekeyTargetId,
    this.wordList,
    this.role,
    this.step = InPersonStep.chooseRole,
    this.qrPayload,
    this.notice,
    this.failure,
    this.phrase,
    this.totpSecret,
    this.ourPublicKey,
    this.theirPublicKey,
  });

  /// Session context: kept across attempts, cleared only by reset.
  final String? label;
  final String? rekeyTargetId;

  /// The word language the phrase is shown in and the contact is saved
  /// with (plan Task 1.5): from the name screen's row, or the contact's
  /// own for a rekey; the confirm screen can switch it. Null shows
  /// English.
  final WordList? wordList;

  final InPersonRole? role;
  final InPersonStep step;

  /// The code to show right now, or null while scanning or minting.
  final String? qrPayload;

  /// Why the last scan was ignored (damaged, foreign, version mismatch).
  /// The attempt continues; the next code that decodes clears it.
  final PairingCodeError? notice;

  /// Why the attempt ended, when [step] is [InPersonStep.failed].
  final InPersonFailure? failure;

  /// Set together on [InPersonStep.confirm], read-only: what the confirm
  /// screen compares and saves.
  final List<String>? phrase;
  final Uint8List? totpSecret;
  final Uint8List? ourPublicKey;
  final Uint8List? theirPublicKey;

  bool get isRekey => rekeyTargetId != null;

  /// Something is being computed: show progress, not a QR or a camera.
  bool get busy =>
      step == InPersonStep.deriving ||
      (step == InPersonStep.startShowCommit && qrPayload == null);

  /// The camera (or the paste field) should be open.
  bool get isScanning =>
      step == InPersonStep.startScanKey ||
      step == InPersonStep.joinScanCommit ||
      step == InPersonStep.joinScanReveal;

  /// A new state for the current attempt that keeps only the session
  /// context. Every other field is set from the arguments, so a field not
  /// passed is cleared on purpose (no stale QR, notice or phrase carries
  /// over between steps).
  InPersonPairingState _next({
    required InPersonRole? role,
    required InPersonStep step,
    String? qrPayload,
    PairingCodeError? notice,
    InPersonFailure? failure,
    List<String>? phrase,
    Uint8List? totpSecret,
    Uint8List? ourPublicKey,
    Uint8List? theirPublicKey,
  }) =>
      InPersonPairingState(
        label: label,
        rekeyTargetId: rekeyTargetId,
        wordList: wordList,
        role: role,
        step: step,
        qrPayload: qrPayload,
        notice: notice,
        failure: failure,
        phrase: phrase == null ? null : List<String>.unmodifiable(phrase),
        totpSecret: _readOnly(totpSecret),
        ourPublicKey: _readOnly(ourPublicKey),
        theirPublicKey: _readOnly(theirPublicKey),
      );

  /// This state with another [wordList] and every other field as it is.
  InPersonPairingState _withWordList(WordList list) => InPersonPairingState(
        label: label,
        rekeyTargetId: rekeyTargetId,
        wordList: list,
        role: role,
        step: step,
        qrPayload: qrPayload,
        notice: notice,
        failure: failure,
        phrase: phrase,
        totpSecret: totpSecret,
        ourPublicKey: ourPublicKey,
        theirPublicKey: theirPublicKey,
      );

  static Uint8List? _readOnly(Uint8List? bytes) =>
      bytes?.asUnmodifiableView();
}

class _Derived {
  const _Derived(this.phrase, this.totpSecret);
  final List<String> phrase;
  final Uint8List totpSecret;
}

class InPersonPairingController extends Notifier<InPersonPairingState> {
  // Attempt material, dropped by [_dropAttempt]. Only public keys reach
  // state, and only at the confirm step.
  PairingKeyPair? _keyPair;
  Uint8List? _nonce; // Start's commitment nonce
  Uint8List? _commitment; // Join: the commitment it accepted
  Uint8List? _acceptedKey; // Start: Join's key it accepted
  Uint8List? _acceptedReveal; // Join: the reveal it accepted (key || nonce)
  String? _commitPayload; // Start: QR-1, kept so it can be shown again
  // Start's derivation runs while QR-3 is up. If the attempt ends first,
  // the future still holds the shared secret until it completes.
  Future<_Derived?>? _startDerivation;

  /// Bumped on every drop so an async step from an ended attempt cannot
  /// write into the next one. Every write after an await checks it.
  int _attempt = 0;

  @override
  InPersonPairingState build() => const InPersonPairingState();

  /// The name for a new contact. Clears any rekey target: a rekey never
  /// goes through the name screen, so a name means a new relationship and
  /// can never save over an existing one.
  void setLabel(String label, {WordList? wordList}) {
    _dropAttempt();
    final trimmed = label.trim();
    state = InPersonPairingState(
      label: trimmed.isEmpty ? null : trimmed,
      wordList: wordList,
    );
  }

  /// Seed a rekey of an existing relationship: same flow, the confirm step
  /// overwrites instead of creating. [wordList] is the contact's own, the
  /// starting value of the confirm screen's language switch.
  void startRekey({
    required String id,
    required String label,
    WordList? wordList,
  }) {
    _dropAttempt();
    state = InPersonPairingState(
      label: label,
      rekeyTargetId: id,
      wordList: wordList,
    );
  }

  /// The confirm screen's language switch: re-shows the same phrase in
  /// [list] and saves the contact with it. Never touches the attempt.
  void setWordList(WordList list) => state = state._withWordList(list);

  /// Start a fresh attempt in [role]. Always mints new material: anything
  /// from an earlier attempt is dropped first.
  Future<void> begin(InPersonRole role) async {
    _dropAttempt();
    final attempt = _attempt;
    if (role == InPersonRole.join) {
      // Join mints nothing until it holds a valid commitment.
      state = state._next(role: role, step: InPersonStep.joinScanCommit);
      return;
    }
    state = state._next(role: role, step: InPersonStep.startShowCommit);
    final PairingKeyPair keyPair;
    final Uint8List nonce;
    final Uint8List commitment;
    try {
      keyPair = await ref.read(inPersonKeyPairFactoryProvider)();
      nonce = ref.read(inPersonNonceFactoryProvider)();
      commitment = await PairingCommitment.commit(
        publicKey: keyPair.publicKey,
        nonce: nonce,
      );
    } catch (_) {
      if (attempt == _attempt) _fail(InPersonFailure.internal);
      return;
    }
    if (attempt != _attempt) return;
    _keyPair = keyPair;
    _nonce = nonce;
    _commitPayload = PairingCodeV2.encodeCommit(commitment);
    state = state._next(
      role: role,
      step: InPersonStep.startShowCommit,
      qrPayload: _commitPayload,
    );
  }

  /// Start: the other phone has scanned QR-1; switch to scanning.
  void startNext() {
    if (state.step != InPersonStep.startShowCommit || _keyPair == null) {
      return;
    }
    state = state._next(
      role: InPersonRole.start,
      step: InPersonStep.startScanKey,
    );
  }

  /// Join: the other phone has scanned QR-2; switch to scanning.
  void joinNext() {
    if (state.step != InPersonStep.joinShowKey) return;
    state = state._next(
      role: InPersonRole.join,
      step: InPersonStep.joinScanReveal,
    );
  }

  /// Start: back from scanning to showing QR-1, for when "Next" was tapped
  /// before the other phone had scanned it. Shows the same commitment
  /// again (nothing new is revealed), and only before a key is accepted.
  void startBack() {
    final payload = _commitPayload;
    if (state.step != InPersonStep.startScanKey ||
        payload == null ||
        _acceptedKey != null) {
      return;
    }
    state = state._next(
      role: InPersonRole.start,
      step: InPersonStep.startShowCommit,
      qrPayload: payload,
    );
  }

  /// Join: back from scanning to showing QR-2, for when "Next" was tapped
  /// before the other phone had scanned it. Shows the same key again.
  void joinBack() {
    final keyPair = _keyPair;
    if (state.step != InPersonStep.joinScanReveal ||
        keyPair == null ||
        _acceptedReveal != null) {
      return;
    }
    state = state._next(
      role: InPersonRole.join,
      step: InPersonStep.joinShowKey,
      qrPayload: PairingCodeV2.encodeKey(keyPair.publicKey),
    );
  }

  /// Start: the other phone has scanned QR-3; show the phrase.
  Future<void> startFinish() async {
    final derivation = _startDerivation;
    final keyPair = _keyPair;
    final theirs = _acceptedKey;
    if (state.step != InPersonStep.startShowReveal ||
        derivation == null ||
        keyPair == null ||
        theirs == null) {
      return;
    }
    final attempt = _attempt;
    state = state._next(role: InPersonRole.start, step: InPersonStep.deriving);
    final derived = await derivation;
    if (attempt != _attempt) return;
    if (derived == null) {
      _fail(InPersonFailure.internal);
      return;
    }
    _confirm(derived, ours: keyPair.publicKey, theirs: theirs);
  }

  /// The UI's idle timer for a running attempt ran out.
  void timeOut() {
    switch (state.step) {
      case InPersonStep.chooseRole:
      case InPersonStep.confirm:
      case InPersonStep.failed:
        return;
      case InPersonStep.startShowCommit:
      case InPersonStep.startScanKey:
      case InPersonStep.startShowReveal:
      case InPersonStep.joinScanCommit:
      case InPersonStep.joinShowKey:
      case InPersonStep.joinScanReveal:
      case InPersonStep.deriving:
        _fail(InPersonFailure.timedOut);
    }
  }

  /// A scanned or pasted code. Damaged, foreign and version-mismatched
  /// input only sets [InPersonPairingState.notice]; valid codes advance
  /// the attempt or end it, per the spike's normative rules.
  Future<void> onScan(String raw) async {
    switch (state.step) {
      case InPersonStep.chooseRole:
      case InPersonStep.deriving:
      case InPersonStep.confirm:
      case InPersonStep.failed:
        return; // nothing is listening
      case InPersonStep.startShowCommit:
      case InPersonStep.startScanKey:
      case InPersonStep.startShowReveal:
      case InPersonStep.joinScanCommit:
      case InPersonStep.joinShowKey:
      case InPersonStep.joinScanReveal:
        break;
    }
    final PairingCode code;
    try {
      code = PairingCodeV2.decode(raw);
    } on PairingCodeException catch (e) {
      _setNotice(e.reason);
      return;
    }
    _setNotice(null); // a code that decodes clears an earlier notice
    if (state.role == InPersonRole.start) {
      await _startReceives(code);
    } else {
      await _joinReceives(code);
    }
  }

  void _setNotice(PairingCodeError? notice) {
    if (state.notice == notice) return;
    state = state._next(
      role: state.role,
      step: state.step,
      qrPayload: state.qrPayload,
      notice: notice,
    );
  }

  Future<void> _startReceives(PairingCode code) async {
    switch (code) {
      case CommitCode():
        // Before a key is accepted, a commitment means two Start phones.
        _fail(_acceptedKey == null
            ? InPersonFailure.startStart
            : InPersonFailure.wrongCodeForStep);
      case RevealCode():
        _fail(InPersonFailure.wrongCodeForStep);
      case KeyCode(:final publicKey):
        final accepted = _acceptedKey;
        if (accepted != null) {
          if (!_same(accepted, publicKey)) _fail(InPersonFailure.secondCode);
          return; // the same QR scanned again
        }
        await _startAcceptKey(publicKey);
    }
  }

  Future<void> _startAcceptKey(Uint8List theirKey) async {
    // A key may arrive while QR-1 is still up if the user never tapped
    // Next; either way Start has shown its commitment by now.
    final keyPair = _keyPair;
    final nonce = _nonce;
    if (keyPair == null || nonce == null) return; // still minting
    final attempt = _attempt;
    // Claimed before any await, so a second scan in flight sees it: the
    // same key is ignored, a different one ends the attempt.
    _acceptedKey = theirKey;
    final Uint8List sharedSecret;
    try {
      sharedSecret = await PairingHandshake.deriveSharedSecret(
        ours: keyPair,
        theirPublicKey: theirKey,
      );
    } on WeakPublicKeyException {
      if (attempt == _attempt) _fail(InPersonFailure.weakKey);
      return;
    }
    if (attempt != _attempt) return;
    // Derive while QR-3 is on screen; [startFinish] picks it up.
    _startDerivation = _derive(
      sharedSecret: sharedSecret,
      ours: keyPair.publicKey,
      theirs: theirKey,
      nonce: nonce,
    );
    state = state._next(
      role: InPersonRole.start,
      step: InPersonStep.startShowReveal,
      qrPayload: PairingCodeV2.encodeReveal(
        publicKey: keyPair.publicKey,
        nonce: nonce,
      ),
    );
  }

  Future<void> _joinReceives(PairingCode code) async {
    switch (code) {
      case CommitCode(:final commitment):
        final accepted = _commitment;
        if (accepted != null) {
          if (!_same(accepted, commitment)) _fail(InPersonFailure.secondCode);
          return; // the same QR scanned again
        }
        await _joinAcceptCommit(commitment);
      case KeyCode():
        // A key before any commitment: the other phone is a Join too.
        _fail(_commitment == null
            ? InPersonFailure.joinJoin
            : InPersonFailure.wrongCodeForStep);
      case RevealCode(:final publicKey, :final nonce):
        final commitment = _commitment;
        if (commitment == null) {
          _fail(InPersonFailure.wrongCodeForStep);
          return;
        }
        final accepted = _acceptedReveal;
        if (accepted != null) {
          if (!_same(accepted, [...publicKey, ...nonce])) {
            _fail(InPersonFailure.secondCode);
          }
          return;
        }
        if (_keyPair == null) return; // still minting
        await _joinAcceptReveal(commitment, publicKey, nonce);
    }
  }

  Future<void> _joinAcceptCommit(Uint8List commitment) async {
    final attempt = _attempt;
    _commitment = commitment;
    // Only now does Join's key exist (normative rule 1).
    final PairingKeyPair keyPair;
    try {
      keyPair = await ref.read(inPersonKeyPairFactoryProvider)();
    } catch (_) {
      if (attempt == _attempt) _fail(InPersonFailure.internal);
      return;
    }
    if (attempt != _attempt) return;
    _keyPair = keyPair;
    state = state._next(
      role: InPersonRole.join,
      step: InPersonStep.joinShowKey,
      qrPayload: PairingCodeV2.encodeKey(keyPair.publicKey),
    );
  }

  Future<void> _joinAcceptReveal(
    Uint8List commitment,
    Uint8List startKey,
    Uint8List nonce,
  ) async {
    final attempt = _attempt;
    final keyPair = _keyPair!;
    _acceptedReveal = Uint8List.fromList([...startKey, ...nonce]);
    final opens = await PairingCommitment.matches(
      commitment: commitment,
      publicKey: startKey,
      nonce: nonce,
    );
    if (attempt != _attempt) return;
    if (!opens) {
      _fail(InPersonFailure.revealMismatch);
      return;
    }
    final Uint8List sharedSecret;
    try {
      sharedSecret = await PairingHandshake.deriveSharedSecret(
        ours: keyPair,
        theirPublicKey: startKey,
      );
    } on WeakPublicKeyException {
      if (attempt == _attempt) _fail(InPersonFailure.weakKey);
      return;
    }
    if (attempt != _attempt) return;
    state = state._next(role: InPersonRole.join, step: InPersonStep.deriving);
    final derived = await _derive(
      sharedSecret: sharedSecret,
      ours: keyPair.publicKey,
      theirs: startKey,
      nonce: nonce,
    );
    if (attempt != _attempt) return;
    if (derived == null) {
      _fail(InPersonFailure.internal);
      return;
    }
    _confirm(derived, ours: keyPair.publicKey, theirs: startKey);
  }

  /// Phrase and TOTP secret; null on any error (reported as internal).
  Future<_Derived?> _derive({
    required Uint8List sharedSecret,
    required Uint8List ours,
    required Uint8List theirs,
    required Uint8List nonce,
  }) async {
    try {
      final phrase = await ref.read(inPersonPhraseDeriverProvider)(
        sharedSecret: sharedSecret,
        ownPublicKey: ours,
        peerPublicKey: theirs,
        nonce: nonce,
      );
      final totp = await PairingHandshake.deriveTotpSecret(
        sharedSecret: sharedSecret,
      );
      return _Derived(phrase, totp);
    } catch (_) {
      return null;
    }
  }

  void _confirm(
    _Derived derived, {
    required Uint8List ours,
    required Uint8List theirs,
  }) {
    final role = state.role;
    // The private material is no longer needed: the confirm screen saves
    // only the TOTP secret and the two public keys.
    _dropAttempt();
    state = state._next(
      role: role,
      step: InPersonStep.confirm,
      phrase: derived.phrase,
      totpSecret: derived.totpSecret,
      ourPublicKey: ours,
      theirPublicKey: theirs,
    );
  }

  void _fail(InPersonFailure failure) {
    final role = state.role;
    _dropAttempt();
    state = state._next(role: role, step: InPersonStep.failed, failure: failure);
  }

  /// Leave this attempt (back, cancel, "start over"). Keeps the label and
  /// rekey target so the user can try again.
  void abort() {
    // The screen calls this from dispose, after the frame; by then the
    // whole container may be gone (app teardown).
    if (!ref.mounted) return;
    _dropAttempt();
    state = state._next(role: null, step: InPersonStep.chooseRole);
  }

  /// Forget everything, the session context included.
  void reset() {
    _dropAttempt();
    state = const InPersonPairingState();
  }

  void _dropAttempt() {
    _attempt++;
    _keyPair = null;
    _nonce = null;
    _commitment = null;
    _acceptedKey = null;
    _acceptedReveal = null;
    _commitPayload = null;
    _startDerivation = null;
  }

  static bool _same(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

final NotifierProvider<InPersonPairingController, InPersonPairingState>
    inPersonPairingControllerProvider =
    NotifierProvider<InPersonPairingController, InPersonPairingState>(
        InPersonPairingController.new);
