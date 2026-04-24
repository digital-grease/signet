import 'dart:typed_data';

import '../core/crypto/pair_role.dart';
import '../core/models/relationship.dart';
import '../core/storage/secure_store.dart';

/// Compile-time flag: seed 3 deterministic mock contacts on boot so home /
/// verify / code-display screens render populated for screenshots, demos,
/// and UI spot-checks.
///
/// Enable with:
///   flutter run --dart-define=SIGNET_MOCK_CONTACTS=true
///
/// **Never ship a release build with this flag on.** The rotating verify
/// codes derived from the deterministic seeds below are predictable —
/// anyone with the source can reproduce them. That's fine for marketing
/// screenshots but a catastrophe for any real relationship.
const bool _mockContactsEnabled =
    bool.fromEnvironment('SIGNET_MOCK_CONTACTS');

bool get mockContactsEnabled => _mockContactsEnabled;

/// Idempotent. If the store already has any relationships, this does
/// nothing — we only seed on a truly empty first launch. That way a
/// dev who pairs for real doesn't get their data clobbered on the next
/// restart with the flag still set.
Future<void> seedMockContactsIfEnabled(SecureStore store) async {
  if (!_mockContactsEnabled) return;
  final existing = await store.listRelationships();
  if (existing.isNotEmpty) return;

  final now = DateTime.utc(2026, 4, 18, 14, 32);
  final seeds = <_MockSeed>[
    _MockSeed(
      id: '0a1b2c3d4e5f60718293a4b5c6d7e8f9',
      label: 'Mom',
      role: PairRole.a,
      pairedAt: now.subtract(const Duration(days: 127)),
      secretByte: 0xA0,
    ),
    _MockSeed(
      id: 'f0e1d2c3b4a59687786960514a3b2c1d',
      label: 'Jake',
      role: PairRole.b,
      pairedAt: now.subtract(const Duration(days: 42)),
      secretByte: 0xB0,
    ),
    _MockSeed(
      id: '11223344556677889900aabbccddeeff',
      label: 'Finance Team',
      role: PairRole.a,
      pairedAt: now.subtract(const Duration(days: 5)),
      secretByte: 0xC0,
    ),
  ];

  for (final seed in seeds) {
    final relationship = Relationship(
      id: seed.id,
      label: seed.label,
      pairedAt: seed.pairedAt,
      role: seed.role,
    );
    // 32-byte deterministic shared secret: first byte varies per peer so
    // the rotating codes differ between contacts (makes screenshots
    // realistic). Remaining bytes are zeros — predictable by design.
    final secret = Uint8List(32)..[0] = seed.secretByte;
    await store.saveRelationshipV2(relationship, sharedSecret: secret);
  }
}

class _MockSeed {
  const _MockSeed({
    required this.id,
    required this.label,
    required this.role,
    required this.pairedAt,
    required this.secretByte,
  });

  final String id;
  final String label;
  final PairRole role;
  final DateTime pairedAt;
  final int secretByte;
}
