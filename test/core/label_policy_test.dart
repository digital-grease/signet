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
            reason: '${LabelPolicy.check(label)}');
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

    test('each refusal says why', () {
      expect(LabelPolicy.check(''), LabelRejection.empty);
      expect(LabelPolicy.check('signet:tp1:x'), LabelRejection.looksLikeData);
      expect(LabelPolicy.check('0123456789abcdef'), LabelRejection.looksLikeKey);
      expect(LabelPolicy.check('z' * 65), LabelRejection.tooLong);
    });
  });

  group('LabelPolicy byte limit and cleaning (plan Task 3.6)', () {
    test('the limit is 64 UTF-8 bytes, not 64 characters', () {
      expect(LabelPolicy.isValid('z' * 64), isTrue);
      // 21 CJK characters = 63 bytes; 22 = 66 bytes.
      expect(LabelPolicy.isValid('\u5988' * 21), isTrue);
      expect(LabelPolicy.check('\u5988' * 22), LabelRejection.tooLong);
    });

    test('clean strips control, zero-width and direction characters', () {
      // RLO would display "moM" reversed; LRI/PDI, ZWSP, BOM, newline.
      expect(LabelPolicy.clean('\u202EMom'), 'Mom');
      expect(LabelPolicy.clean('\u2066Bob\u2069'), 'Bob');
      expect(LabelPolicy.clean('A\u200Bnn\uFEFFa'), 'Anna');
      expect(LabelPolicy.clean('Mom\nDad'), 'Mom Dad');
      expect(LabelPolicy.clean('  Big   Sis \t'), 'Big Sis');
    });

    test('a name of only invisible characters is empty', () {
      expect(LabelPolicy.check('\u202E\u200B'), LabelRejection.empty);
    });

    test('forRestore keeps a good name and replaces an unusable one', () {
      expect(LabelPolicy.forRestore('\u202EMom', 'X'), 'Mom');
      expect(LabelPolicy.forRestore('', 'X'), 'X');
      expect(LabelPolicy.forRestore('0123456789abcdef0123', 'X'), 'X');
    });

    test('withSuffix shortens the name, never splits a character', () {
      final long = '\u5988' * 21; // 63 bytes
      final out = LabelPolicy.withSuffix(long, ' (restored)');
      expect(out, endsWith(' (restored)'));
      expect(LabelPolicy.isValid(out), isTrue);
      expect(out.runes.where((r) => r == 0xFFFD), isEmpty);
      expect(LabelPolicy.withSuffix('Mom', ' (restored)'), 'Mom (restored)');
    });
  });

  group('review fixes (plan Task 3.6)', () {
    test('ZWJ and ZWNJ stay: they join emoji and shape Persian', () {
      const family = '\u{1F468}\u200D\u{1F469}\u200D\u{1F467}';
      expect(LabelPolicy.clean(family), family);
      const persian = '\u0645\u06CC\u200C\u062E\u0648\u0627\u0647\u0645';
      expect(LabelPolicy.clean(persian), persian);
    });

    test('characters that render as nothing are removed', () {
      expect(LabelPolicy.check('\u3164'), LabelRejection.empty);
      expect(LabelPolicy.check('\u115F\u1160\uFFA0'), LabelRejection.empty);
      expect(LabelPolicy.clean('Mo\u00ADm'), 'Mom');
      expect(LabelPolicy.clean('Mom\u{E0041}\u{E007F}'), 'Mom');
    });

    test('truncateToBytes never splits a flag or an accented letter', () {
      const flag = '\u{1F1E8}\u{1F1F3}'; // 8 bytes, one character
      expect(LabelPolicy.truncateToBytes('${'a' * 60}$flag', 64), 'a' * 60);
      const eAcute = 'e\u0301'; // 3 bytes, one character
      expect(LabelPolicy.truncateToBytes('${'z' * 62}$eAcute', 64), 'z' * 62);
      expect(LabelPolicy.truncateToBytes('Mom', 64), 'Mom');
    });
  });

  test('a joiner next to plain letters or at an end is removed', () {
    expect(LabelPolicy.clean('Mom\u200D'), 'Mom');
    expect(LabelPolicy.clean('\u200CMom'), 'Mom');
    expect(LabelPolicy.clean('M\u200Dom'), 'Mom');
  });
}
