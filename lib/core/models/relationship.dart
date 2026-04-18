import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../crypto/pair_role.dart';

/// A paired contact. Holds only non-secret metadata — the shared secret
/// never lives on this model and is stored separately in the secure enclave.
///
/// The [role] field binds the rotating verify code to a direction so a
/// reflection attack (caller parrots the verifier's own words back at
/// her) fails — see `TotpWords` docs for the full derivation story.
@immutable
class Relationship {
  const Relationship({
    required this.id,
    required this.label,
    required this.pairedAt,
    required this.role,
    this.silentHaptics = false,
  });

  factory Relationship.fromJson(String source) {
    final map = jsonDecode(source) as Map<String, dynamic>;
    final roleWire = map['role'];
    if (roleWire is! String) {
      throw const FormatException(
        'Relationship JSON is missing "role" — likely from a pre-Phase-8 '
        'build. The app will wipe this pairing and ask the user to repair.',
      );
    }
    // silentHaptics was added in Phase 9.6; legacy blobs without it default
    // to false (= haptics on, which is the grandma-test default). This is
    // an additive migration — no blob is invalidated.
    final silent = map['silentHaptics'] as bool?;
    return Relationship(
      id: map['id']! as String,
      label: map['label']! as String,
      pairedAt: DateTime.fromMillisecondsSinceEpoch(
        map['pairedAtMs']! as int,
        isUtc: true,
      ),
      role: PairRole.fromWireName(roleWire),
      silentHaptics: silent ?? false,
    );
  }

  /// Mint a new Relationship at the current instant.
  factory Relationship.fresh({
    required String label,
    required PairRole role,
    bool silentHaptics = false,
    DateTime? now,
    Random? random,
  }) {
    final rng = random ?? Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    final id = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    final when = now ?? DateTime.now().toUtc();
    return Relationship(
      id: id,
      label: label,
      pairedAt: when.toUtc(),
      role: role,
      silentHaptics: silentHaptics,
    );
  }

  final String id;
  final String label;
  final DateTime pairedAt;
  final PairRole role;

  /// When `true`, the Verify screen suppresses HapticFeedback on both ✅
  /// and ❌ outcomes. A buzzing phone is an observable tell in coercive /
  /// surveillance scenarios; silent mode is meant for the journalist +
  /// activist audience. Default `false` (haptics on) — grandma test wins.
  final bool silentHaptics;

  Relationship copyWith({
    String? id,
    String? label,
    DateTime? pairedAt,
    PairRole? role,
    bool? silentHaptics,
  }) {
    return Relationship(
      id: id ?? this.id,
      label: label ?? this.label,
      pairedAt: pairedAt ?? this.pairedAt,
      role: role ?? this.role,
      silentHaptics: silentHaptics ?? this.silentHaptics,
    );
  }

  String toJson() => jsonEncode(<String, dynamic>{
        'id': id,
        'label': label,
        'pairedAtMs': pairedAt.toUtc().millisecondsSinceEpoch,
        'role': role.wireName,
        'silentHaptics': silentHaptics,
      });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Relationship &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          label == other.label &&
          pairedAt.isAtSameMomentAs(other.pairedAt) &&
          role == other.role &&
          silentHaptics == other.silentHaptics;

  @override
  int get hashCode =>
      Object.hash(id, label, pairedAt.toUtc(), role, silentHaptics);

  @override
  String toString() =>
      'Relationship(id: $id, label: $label, role: ${role.wireName}, '
      'pairedAt: ${pairedAt.toIso8601String()}, '
      'silentHaptics: $silentHaptics)';
}
