import 'package:flutter_test/flutter_test.dart';
import 'package:signet/core/crypto/pair_role.dart';
import 'package:signet/core/logging/debug_log_export_scrubber.dart';
import 'package:signet/core/models/relationship.dart';

/// Phase-8 export scrubber. Every case here is on the **100% bar** — a single
/// missed contact name or secret in a public GitHub issue is the failure this
/// module exists to prevent. The corpus encodes the Phase-8 red-team's attack
/// inputs verbatim (regex-metacharacter labels, word-boundary/possessive,
/// whitespace-split, Unicode, the pipeline-ordering proof, BIP-39-word labels,
/// `tp1`-containing labels).
void main() {
  Relationship rel(String id, String label) => Relationship(
        id: id,
        label: label,
        pairedAt: DateTime.utc(2026, 1, 1),
        role: PairRole.a,
      );

  // Realistic 32-hex ids (what Relationship.fresh mints).
  const idA = '0a1b2c3d4e5f60718293a4b5c6d7e8f9';
  const idB = 'ffeeddccbbaa99887766554433221100';

  String scrub(String log, List<Relationship> rels) =>
      DebugLogExportScrubber.scrub(log, rels);

  group('label redaction — base', () {
    test('bare label mid-sentence collapses to a peer token', () {
      final out = scrub('verify start for Mom today', [rel(idA, 'Mom')]);
      expect(out, isNot(contains('Mom')));
      expect(out, contains('<peer-1>'));
    });

    test('substring labels: longest-first, neither leaks', () {
      final out = scrub(
        'pinged Mom2 then Mom',
        [rel(idA, 'Mom'), rel(idB, 'Mom2')],
      );
      expect(out, isNot(contains('Mom2')));
      expect(out, isNot(matches(RegExp(r'(?<![A-Za-z0-9])Mom(?![A-Za-z0-9])'))));
      expect(out, contains('<peer-'));
    });
  });

  group('label redaction — regex-metacharacter labels (critical)', () {
    final cases = <String, String>{
      'Mom (primary)': 'called Mom (primary) at noon',
      'A+B Team': 'A+B Team escalated',
      'C.O.O': 'the C.O.O signed off',
      'group|members': 'group|members notified',
      '[restricted]': 'flagged [restricted] contact',
      r'test\path': r'opened test\path entry',
    };
    cases.forEach((label, line) {
      test('label "$label" is fully replaced, not interpreted', () {
        final out = scrub(line, [rel(idA, label)]);
        expect(out, isNot(contains(label)),
            reason: 'label "$label" leaked in: $out');
        expect(out, contains('<peer-1>'));
      });
    });
  });

  group('label redaction — word boundaries', () {
    test('possessive and punctuation-adjacent forms redact', () {
      for (final line in <String>[
        "called Mom's phone",
        'verified Mom, then left',
        'pinged Mom.',
        'asked Mom!',
        'tag (Mom)',
      ]) {
        final out = scrub(line, [rel(idA, 'Mom')]);
        expect(out, isNot(matches(RegExp(r'(?<![A-Za-z0-9])Mom'))),
            reason: 'leaked in: $line -> $out');
      }
    });

    test('compound word does NOT over-redact', () {
      final out = scrub('opened MomCare app', [rel(idA, 'Mom')]);
      expect(out, contains('MomCare'));
    });
  });

  group('label redaction — whitespace-split multi-word labels', () {
    for (final between in <String>[' ', '  ', '\n', '\t', ' \n ']) {
      test('"Finance${between}Team" still matches "Finance Team"', () {
        final out = scrub('the Finance${between}Team met', [
          rel(idA, 'Finance Team'),
        ]);
        expect(out, isNot(contains('Finance')));
        expect(out, isNot(contains('Team')));
        expect(out, contains('<peer-1>'));
      });
    }
  });

  group('label redaction — Unicode (NFC + case-insensitive)', () {
    test('precomposed accent collapses across case', () {
      final out = scrub('JOSÉ called', [rel(idA, 'José')]);
      expect(out, isNot(contains('JOSÉ')));
      expect(out, contains('<peer-1>'));
    });

    test(
      'KNOWN LIMITATION (decision #18): accent-stripped variant is NOT caught',
      () {
        // "Jose" (no accent) for a "José" contact is a documented residual,
        // mitigated by write-time discipline + the pre-export warning.
        final out = scrub('Jose called', [rel(idA, 'José')]);
        expect(out, contains('Jose'));
      },
    );
  });

  group('pipeline ordering — secrets cannot be fragmented by labels', () {
    test('label that is a base64 substring of a secret: secret redacted, no leak',
        () {
      // "sub" sits inside a 24-char base64 secret. id-map → secret-scrub →
      // label-sweep means the secret is gone before "sub" is swept.
      const secret = 'abc1234567890sub_def1234';
      final out = scrub('wire $secret end', [rel(idA, 'sub')]);
      expect(out, isNot(contains(secret)));
      expect(out, isNot(contains('sub')));
      expect(out, contains('redacted'));
    });

    test('BIP-39-word label + unrelated 4-word verify cluster', () {
      // "anchor bridge canyon doctor" is a verify-code cluster; "Anchor" is
      // also a label. Cluster must be redacted; label must be mapped.
      final out = scrub(
        'code anchor bridge canyon doctor and Anchor again',
        [rel(idA, 'Anchor')],
      );
      expect(out, isNot(contains('bridge')));
      expect(out, isNot(contains('canyon')));
      expect(out, isNot(contains('Anchor')));
      expect(out, contains('<peer-1>'));
    });

    test('tp1-containing label + a real transport wire', () {
      final out = scrub(
        'received signet:tp1:QWERTy123456abcdefGHIJ and tp1 marker',
        [rel(idA, 'tp1')],
      );
      expect(out, isNot(contains('signet:tp1:')));
      expect(out, isNot(contains('QWERTy123456abcdefGHIJ')));
    });
  });

  group('correlation', () {
    test('a relationship id and label collapse to the SAME token', () {
      final out = scrub('ref=$idA verified Mom', [rel(idA, 'Mom')]);
      expect(out, isNot(contains(idA)));
      expect(out, isNot(contains('Mom')));
      // Both references became the same token.
      expect(RegExp(r'<peer-1>').allMatches(out).length, 2);
    });

    test('distinct relationships get distinct stable tokens', () {
      final out = scrub('ref=$idA and ref=$idB', [
        rel(idA, 'Mom'),
        rel(idB, 'Dad'),
      ]);
      expect(out, isNot(contains(idA)));
      expect(out, isNot(contains(idB)));
      expect(out, contains('<peer-1>'));
      expect(out, contains('<peer-2>'));
    });
  });

  group('secret scrub still fires (LogScrubber reuse)', () {
    test('hex >=16 and a 4-word BIP-39 cluster are redacted', () {
      final out = scrub(
        'key 0123456789abcdef0123 words apple bridge canyon doctor',
        const <Relationship>[],
      );
      expect(out, isNot(contains('0123456789abcdef0123')));
      expect(out, isNot(contains('apple bridge canyon doctor')));
    });
  });

  group('PII sweep', () {
    test('email redacted', () {
      final out = scrub('contact bob@example.com please', const []);
      expect(out, isNot(contains('bob@example.com')));
      expect(out, contains('[redacted-email]'));
    });

    test('phone redacted', () {
      final out = scrub('call 555-123-4567 now', const []);
      expect(out, isNot(contains('555-123-4567')));
      expect(out, contains('[redacted-phone]'));
    });

    test('short digit run is not treated as a phone', () {
      final out = scrub('step 1 2 3 done', const []);
      expect(out, contains('1 2 3'));
    });
  });

  group('edges', () {
    test('empty log returns empty', () {
      expect(scrub('', [rel(idA, 'Mom')]), '');
    });

    test('no relationships still scrubs secrets + PII', () {
      final out = scrub(
        'key abcdef0123456789abcdef mail x@y.com',
        const <Relationship>[],
      );
      expect(out, isNot(contains('abcdef0123456789abcdef')));
      expect(out, isNot(contains('x@y.com')));
    });
  });
}
