import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

/// A paired contact. Holds only non-secret metadata — the shared secret
/// never lives on this model and is stored separately in the secure enclave.
@immutable
class Relationship {
  const Relationship({
    required this.id,
    required this.label,
    required this.pairedAt,
  });

  factory Relationship.fromJson(String source) {
    final map = jsonDecode(source) as Map<String, dynamic>;
    return Relationship(
      id: map['id']! as String,
      label: map['label']! as String,
      pairedAt: DateTime.fromMillisecondsSinceEpoch(
        map['pairedAtMs']! as int,
        isUtc: true,
      ),
    );
  }

  /// Mint a new Relationship at the current instant.
  factory Relationship.fresh({
    required String label,
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
    );
  }

  final String id;
  final String label;
  final DateTime pairedAt;

  String toJson() => jsonEncode(<String, dynamic>{
        'id': id,
        'label': label,
        'pairedAtMs': pairedAt.toUtc().millisecondsSinceEpoch,
      });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Relationship &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          label == other.label &&
          pairedAt.isAtSameMomentAs(other.pairedAt);

  @override
  int get hashCode => Object.hash(id, label, pairedAt.toUtc());

  @override
  String toString() =>
      'Relationship(id: $id, label: $label, pairedAt: ${pairedAt.toIso8601String()})';
}
