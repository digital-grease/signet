import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/crypto/pairing.dart';
import '../../core/crypto/verification.dart';

/// Cross-screen state for a single pairing attempt. Lives only in memory —
/// never persisted in-flight, so if the app dies mid-pair the user simply
/// starts over. A completed pair is committed atomically via [commit].
@immutable
class PairingState {
  const PairingState({
    this.label,
    this.ourKeyPair,
    this.didShowQr = false,
    this.theirPublicKey,
    this.totpSecret,
    this.phrase,
    this.error,
    this.rekeyTargetId,
  });

  final String? label;
  final PairingKeyPair? ourKeyPair;
  final bool didShowQr;
  final Uint8List? theirPublicKey;
  final Uint8List? totpSecret;
  final List<String>? phrase;
  final String? error;

  /// When non-null, this flow is rekeying an existing relationship rather
  /// than creating a new one. The `pair_confirm_screen.onMatch` handler
  /// branches on this: rekey overwrites the existing metadata + secret
  /// with the new derivation, preserving id and label but bumping
  /// `pairedAt` and re-deriving `role` from the new public keys.
  final String? rekeyTargetId;

  bool get isRekey => rekeyTargetId != null;

  bool get hasScannedTheirKey => theirPublicKey != null;
  bool get exchangeComplete => didShowQr && hasScannedTheirKey;
  bool get confirmationReady => phrase != null && totpSecret != null;

  PairingState copyWith({
    String? label,
    PairingKeyPair? ourKeyPair,
    bool? didShowQr,
    Uint8List? theirPublicKey,
    Uint8List? totpSecret,
    List<String>? phrase,
    String? error,
    String? rekeyTargetId,
    bool clearError = false,
    bool clearTheirPublicKey = false,
    bool clearTotpSecret = false,
    bool clearPhrase = false,
    bool clearRekeyTargetId = false,
  }) {
    return PairingState(
      label: label ?? this.label,
      ourKeyPair: ourKeyPair ?? this.ourKeyPair,
      didShowQr: didShowQr ?? this.didShowQr,
      theirPublicKey:
          clearTheirPublicKey ? null : theirPublicKey ?? this.theirPublicKey,
      totpSecret: clearTotpSecret ? null : totpSecret ?? this.totpSecret,
      phrase: clearPhrase ? null : phrase ?? this.phrase,
      error: clearError ? null : error ?? this.error,
      rekeyTargetId: clearRekeyTargetId
          ? null
          : rekeyTargetId ?? this.rekeyTargetId,
    );
  }
}

class PairingController extends Notifier<PairingState> {
  @override
  PairingState build() => const PairingState();

  void setLabel(String label) {
    final trimmed = label.trim();
    state = state.copyWith(
      label: trimmed.isEmpty ? null : trimmed,
      clearError: true,
    );
  }

  /// Generate our ephemeral key pair (idempotent — keeps the existing one
  /// if already generated so the shown QR is stable across rebuilds).
  Future<void> ensureOurKeyPair() async {
    if (state.ourKeyPair != null) return;
    final kp = await PairingHandshake.generateEphemeralKeyPair();
    state = state.copyWith(ourKeyPair: kp);
  }

  /// Record that the user has confirmed the other device has scanned our QR.
  /// This is a soft signal — we cannot detect scan completion — but we need
  /// it to avoid auto-advancing before the user has finished showing. If
  /// the scan has already happened (other ordering), this also triggers
  /// derivation since both prerequisites are now met.
  Future<void> markQrShown() async {
    state = state.copyWith(didShowQr: true, clearError: true);
    await _maybeDerive();
  }

  /// Record the scanned public key, then (if we already have our own key pair
  /// AND have shown our QR) derive the shared secret, TOTP secret, and
  /// 4-word verification phrase. Holding derivation until didShowQr is the
  /// fix for Issue #1 — without it, the scanning device auto-advances to
  /// the confirm screen before the other device has finished scanning ours,
  /// leaving the flow deadlocked.
  Future<void> recordTheirPublicKey(Uint8List theirKey) async {
    // Validate up-front so a malformed scan is rejected immediately,
    // regardless of whether derivation would otherwise be deferred until
    // markQrShown. Previously this surfaced via the deriveSharedSecret
    // exception path inside _maybeDerive; with derivation now gated on
    // didShowQr the bad-length scan would otherwise be silently swallowed.
    if (theirKey.length != PairingHandshake.publicKeyLength) {
      state = state.copyWith(
        error: 'Scanned key is ${theirKey.length} bytes; '
            'expected ${PairingHandshake.publicKeyLength}.',
      );
      return;
    }
    state = state.copyWith(theirPublicKey: theirKey, clearError: true);
    await _maybeDerive();
  }

  Future<void> _maybeDerive() async {
    final ours = state.ourKeyPair;
    final theirs = state.theirPublicKey;
    if (ours == null || theirs == null) return;
    // The "show my QR" tap is a soft confirmation that the other side has
    // scanned us. Without this gate, scanning their QR alone is enough to
    // advance past the symmetric exchange — causing Issue #1's deadlock
    // when the other device hasn't yet scanned ours.
    if (!state.didShowQr) return;
    try {
      final sharedSecret = await PairingHandshake.deriveSharedSecret(
        ours: ours,
        theirPublicKey: theirs,
      );
      final totpSecret = await PairingHandshake.deriveTotpSecret(
        sharedSecret: sharedSecret,
      );
      final phrase = await PairingVerification.derivePhrase(
        sharedSecret: sharedSecret,
      );
      state = state.copyWith(totpSecret: totpSecret, phrase: phrase);
    } catch (error) {
      state = state.copyWith(error: 'Failed to derive shared secret: $error');
    }
  }

  /// Abort the scanned key (used when the verification phrase doesn't match —
  /// possible MITM or bad scan) without losing our key pair or label.
  void clearScan() {
    state = state.copyWith(
      clearTheirPublicKey: true,
      clearPhrase: true,
      clearTotpSecret: true,
      clearError: true,
    );
  }

  /// Seed a rekey attempt for an existing relationship. Wipes any in-flight
  /// pair state, primes [label] and [rekeyTargetId] so the confirm step
  /// overwrites rather than creates. Caller then navigates to
  /// `/pair/exchange`; the rest of the flow is identical to a fresh pair
  /// apart from the commit handler.
  void startRekey({required String id, required String label}) {
    state = PairingState(label: label, rekeyTargetId: id);
  }

  /// Wipe everything. Called when the user aborts or after a successful commit.
  void reset() {
    state = const PairingState();
  }
}

final NotifierProvider<PairingController, PairingState> pairingControllerProvider =
    NotifierProvider<PairingController, PairingState>(PairingController.new);
