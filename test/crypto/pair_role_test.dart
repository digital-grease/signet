import 'package:flutter_test/flutter_test.dart';
import 'package:signet/core/crypto/pair_role.dart';

void main() {
  group('PairRole.other', () {
    test('a.other is b, b.other is a', () {
      expect(PairRole.a.other, PairRole.b);
      expect(PairRole.b.other, PairRole.a);
    });
  });

  group('PairRole wireName round-trip', () {
    test('a ↔ "a", b ↔ "b"', () {
      expect(PairRole.a.wireName, 'a');
      expect(PairRole.b.wireName, 'b');
      expect(PairRole.fromWireName('a'), PairRole.a);
      expect(PairRole.fromWireName('b'), PairRole.b);
    });

    test('unknown wire name throws FormatException', () {
      expect(() => PairRole.fromWireName(''), throwsFormatException);
      expect(() => PairRole.fromWireName('A'), throwsFormatException);
      expect(() => PairRole.fromWireName('c'), throwsFormatException);
    });
  });

  group('PairRole.assign', () {
    test('smaller-first-byte ours → role a', () {
      final ours = List<int>.generate(32, (i) => i == 0 ? 0x10 : 0);
      final theirs = List<int>.generate(32, (i) => i == 0 ? 0x20 : 0);
      expect(
        PairRole.assign(ourPublicKey: ours, theirPublicKey: theirs),
        PairRole.a,
      );
    });

    test('greater-first-byte ours → role b', () {
      final ours = List<int>.generate(32, (i) => i == 0 ? 0x20 : 0);
      final theirs = List<int>.generate(32, (i) => i == 0 ? 0x10 : 0);
      expect(
        PairRole.assign(ourPublicKey: ours, theirPublicKey: theirs),
        PairRole.b,
      );
    });

    test('tie-breaks on first-differing byte regardless of position', () {
      final ours = <int>[
        0x01, 0x02, 0x03, 0x04, 0x05,
        ...List<int>.filled(27, 0xFF),
      ];
      final theirs = <int>[
        0x01, 0x02, 0x03, 0x05, 0x00,
        ...List<int>.filled(27, 0x00),
      ];
      // Diverges at index 3: ours=0x04 < theirs=0x05 → a
      expect(
        PairRole.assign(ourPublicKey: ours, theirPublicKey: theirs),
        PairRole.a,
      );
    });

    test('mismatched-length keys throws ArgumentError', () {
      expect(
        () => PairRole.assign(
          ourPublicKey: List<int>.filled(32, 0),
          theirPublicKey: List<int>.filled(16, 0),
        ),
        throwsArgumentError,
      );
    });

    test('identical keys throws (defensive invariant)', () {
      final keys = List<int>.filled(32, 0x42);
      expect(
        () => PairRole.assign(ourPublicKey: keys, theirPublicKey: keys),
        throwsArgumentError,
      );
    });

    test('signed-byte corner cases are treated as unsigned (0xFF > 0x80)', () {
      final ours = <int>[0xFF, ...List<int>.filled(31, 0)];
      final theirs = <int>[0x80, ...List<int>.filled(31, 0)];
      expect(
        PairRole.assign(ourPublicKey: ours, theirPublicKey: theirs),
        PairRole.b,
      );
    });
  });
}
