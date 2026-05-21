// Smoke-level coverage of LogScrubber. Phase 7.4 will expand this into
// the full multi-bar corpus (100% mechanical / ≥95% judgment / ≥95%
// framework-allow-pass / real-trace shape preservation).
//
// What this file covers right now: one MUST-redact per mechanical pattern
// + a handful of MUST-PASS canonical shapes. Enough to confirm the
// scrubber is not catastrophically broken; not enough to claim the
// build-failing 100% bar.

import 'package:flutter_test/flutter_test.dart';
import 'package:signet/core/logging/log_scrubber.dart';

void main() {
  group('LogScrubber MUST redact (mechanical)', () {
    test('32-char hex run', () {
      final out = LogScrubber.scrub('0123456789abcdef0123456789abcdef');
      expect(out, isNot(contains('0123456789abcdef')));
      expect(out, contains('redacted:32'));
    });

    test('signet:tp1: wire prefix + body', () {
      const wire = 'signet:tp1:eyJ2ZXJzaW9uIjoxfQ==';
      final out = LogScrubber.scrub(wire);
      expect(out, isNot(contains('signet:tp1:')));
      expect(out, isNot(contains('eyJ2ZXJzaW9uIjoxfQ')));
    });

    test('BIP-39 4-cluster (hyphen)', () {
      const cluster = 'apple-bridge-canyon-doctor';
      final out = LogScrubber.scrub(cluster);
      for (final w in <String>['apple', 'bridge', 'canyon', 'doctor']) {
        expect(out, isNot(contains(w)), reason: '"$w" leaked from cluster');
      }
    });

    test('BIP-39 4-cluster (whitespace)', () {
      const cluster = 'apple bridge canyon doctor';
      final out = LogScrubber.scrub(cluster);
      for (final w in <String>['apple', 'bridge', 'canyon', 'doctor']) {
        expect(out, isNot(contains(w)));
      }
    });

    test('BIP-39 8-cluster', () {
      // All 8 words confirmed in lib/core/crypto/bip39_english_wordlist.dart.
      const cluster = 'abandon ability able about above absent absorb abstract';
      final out = LogScrubber.scrub(cluster);
      for (final w in <String>[
        'abandon', 'ability', 'able', 'about',
        'above', 'absent', 'absorb', 'abstract',
      ]) {
        expect(out, isNot(contains(w)), reason: '"$w" leaked from 8-cluster');
      }
    });

    test('Single BIP-39 word in English text passes through', () {
      const sentence = 'the user tapped the able button to continue';
      final out = LogScrubber.scrub(sentence);
      // "able" is a BIP-39 word; should NOT be redacted as a standalone.
      expect(out, contains('able'));
    });

    test('Quoted pair label is redacted', () {
      const trace = 'Relationship(id: a1b2c3d4, label: "Mom", role: a)';
      final out = LogScrubber.scrub(trace);
      expect(out, isNot(contains('"Mom"')),
          reason: 'pair labels in toString must not survive');
      expect(out, contains('a1b2c3d4')); // id is not sensitive
    });
  });

  group('LogScrubber MUST pass (framework structure)', () {
    test('package:signet stack frame survives', () {
      const frame =
          '#0      VerifyScreen.build (package:signet/features/verify/verify_screen.dart:362:5)';
      final out = LogScrubber.scrub(frame);
      expect(out, contains('package:signet/features/verify/verify_screen.dart'));
      expect(out, contains('#0'));
      expect(out, contains(':362:5'));
    });

    test('async suspension marker survives', () {
      const marker = '<asynchronous suspension>';
      final out = LogScrubber.scrub(marker);
      expect(out, contains('asynchronous'));
      expect(out, contains('suspension'));
    });

    test('FormatException with template message survives', () {
      const line = 'FormatException: Unexpected character';
      final out = LogScrubber.scrub(line);
      expect(out, contains('FormatException'));
    });

    test('RangeError with bounded message survives', () {
      const line =
          'RangeError (index): Invalid value: Only valid value is 0: 1';
      final out = LogScrubber.scrub(line);
      expect(out, contains('RangeError'));
    });
  });
}
