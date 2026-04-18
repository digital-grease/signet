/// Fixed per-pair role used to bind each rotating TOTP code to a
/// direction (A→B vs B→A), which defeats reflection attacks where
/// an attacker parrots the verifier's own words back at them.
///
/// Both devices in a pair independently compute the same role assignment
/// at pair-commit time by lexicographically comparing their two X25519
/// public keys: whichever side's key sorts first is `a`, the other `b`.
/// No negotiation or extra round-trip needed.
enum PairRole {
  a,
  b;

  /// Returns the opposite role (A's counterpart is B, and vice versa).
  PairRole get other => this == PairRole.a ? PairRole.b : PairRole.a;

  /// Serialize to the short wire form stored in JSON / on disk.
  String get wireName => this == PairRole.a ? 'a' : 'b';

  /// Parse from the short wire form. Throws [FormatException] on anything
  /// other than `'a'` or `'b'` so callers fail loud on legacy or corrupt
  /// data — important for the Phase 8 breaking change in `Relationship`.
  static PairRole fromWireName(String name) {
    switch (name) {
      case 'a':
        return PairRole.a;
      case 'b':
        return PairRole.b;
      default:
        throw FormatException('Unknown PairRole wire name: "$name".');
    }
  }

  /// Assign a role to this device based on lexicographic byte comparison
  /// of the two X25519 public keys. The side whose key sorts less is
  /// `a`. X25519 public keys are always exactly 32 bytes and — given
  /// they're derived from Dart `Random.secure()` — functionally never
  /// collide, but we throw on equality as a defensive invariant.
  static PairRole assign({
    required List<int> ourPublicKey,
    required List<int> theirPublicKey,
  }) {
    if (ourPublicKey.length != theirPublicKey.length) {
      throw ArgumentError(
        'Pair-role keys must be the same length '
        '(got ours=${ourPublicKey.length}, '
        'theirs=${theirPublicKey.length}).',
      );
    }
    for (var i = 0; i < ourPublicKey.length; i++) {
      final ours = ourPublicKey[i] & 0xFF;
      final theirs = theirPublicKey[i] & 0xFF;
      if (ours < theirs) return PairRole.a;
      if (ours > theirs) return PairRole.b;
    }
    throw ArgumentError(
      'Pair-role keys are byte-identical; refusing to assign a role '
      '(this should never happen with X25519 ephemeral keys).',
    );
  }
}
