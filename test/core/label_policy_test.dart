import 'package:flutter_test/flutter_test.dart';
import 'package:signet/core/models/label_policy.dart';

void main() {
  group('LabelPolicy — allowed', () {
    for (final label in <String>[
      'Mom',
      'Bob from work',
      'Finance Team',
      'José',
      'Dr. Jane (MD)',
      'A+B Team',
      'deadbeef', // 8 hex chars — under the 16 threshold
      'cafe', // short, looks-hex but fine
    ]) {
      test('"$label" is valid', () {
        expect(LabelPolicy.isValid(label), isTrue,
            reason: LabelPolicy.rejectionReason(label));
      });
    }
  });

  group('LabelPolicy — rejected (decision #17)', () {
    test('empty / whitespace-only', () {
      expect(LabelPolicy.isValid(''), isFalse);
      expect(LabelPolicy.isValid('   '), isFalse);
    });

    test('contains a transport-package wire prefix', () {
      expect(LabelPolicy.isValid('signet:tp1:AAAA'), isFalse);
      expect(LabelPolicy.isValid('my signet:tp1: thing'), isFalse);
      // case-insensitive
      expect(LabelPolicy.isValid('SIGNET:TP1:xyz'), isFalse);
    });

    test('pure >=16-char hex string', () {
      expect(LabelPolicy.isValid('0123456789abcdef'), isFalse); // 16
      expect(
        LabelPolicy.isValid('0a1b2c3d4e5f60718293a4b5c6d7e8f9'),
        isFalse,
      ); // 32 (id-shaped)
    });

    test('15-char hex is allowed (below threshold, matches LogScrubber)', () {
      expect(LabelPolicy.isValid('0123456789abcde'), isTrue);
    });

    test('rejection reasons are non-empty and user-facing', () {
      expect(LabelPolicy.rejectionReason('signet:tp1:x'), isNotEmpty);
      expect(LabelPolicy.rejectionReason('0123456789abcdef'), isNotEmpty);
    });
  });
}
