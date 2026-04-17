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
  });

  final String? label;
  final PairingKeyPair? ourKeyPair;
  final bool didShowQr;
  final Uint8List? theirPublicKey;
  final Uint8List? totpSecret;
  final List<String>? phrase;
  final String? error;

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
    bool clearError = false,
    bool clearTheirPublicKey = false,
    bool clearTotpSecret = false,
    bool clearPhrase = false,
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
  /// it to avoid auto-advancing before the user has finished showing.
  void markQrShown() {
    state = state.copyWith(didShowQr: true, clearError: true);
  }

  /// Record the scanned public key, then (if we already have our own key pair)
  /// derive the shared secret, TOTP secret, and 4-word verification phrase.
  Future<void> recordTheirPublicKey(Uint8List theirKey) async {
    state = state.copyWith(theirPublicKey: theirKey, clearError: true);
    await _maybeDerive();
  }

  Future<void> _maybeDerive() async {
    final ours = state.ourKeyPair;
    final theirs = state.theirPublicKey;
    if (ours == null || theirs == null) return;
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

  /// Wipe everything. Called when the user aborts or after a successful commit.
  void reset() {
    state = const PairingState();
  }
}

final NotifierProvider<PairingController, PairingState> pairingControllerProvider =
    NotifierProvider<PairingController, PairingState>(PairingController.new);
