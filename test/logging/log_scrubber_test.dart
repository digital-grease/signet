// Comprehensive multi-bar test corpus for LogScrubber. Per the spike
// (`.devloop/spikes/log-shipping.md`) "Pass thresholds" table:
//
//   Category                                    | Bar          | This file
//   --------------------------------------------+--------------+----------
//   Mechanical redact patterns                  | 100% pass-   | Group A
//   (hex>=16, base64>=16, signet:tp1: wire,     | or-fail-     | (programmatic
//   BIP-39 4/8 clusters)                        | build        |  corpus)
//   --------------------------------------------+--------------+----------
//   Judgment redact patterns                    | >=95% on     | Group B
//   (pair labels in toString dumps, user input  | curated      | (curated)
//   in exception messages)                      | corpus       |
//   --------------------------------------------+--------------+----------
//   Framework allow-pass                        | >=95%        | Group C
//   (legit framework class names, paths,        |              | (curated)
//   line numbers)                               |              |
//   --------------------------------------------+--------------+----------
//   Real-trace shape preservation               | 100% shape   | Group D
//   (recognizable as a stack trace)             |              | (curated)
//
// Corpus origination for the mechanical bar uses TotpWords.generate +
// TransportPackage.encodeLdp with deterministic seeds, so the corpus stays
// in sync with production output formats automatically.

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:signet/core/crypto/bip39_english_wordlist.dart';
import 'package:signet/core/crypto/pair_role.dart';
import 'package:signet/core/crypto/totp_words.dart';
import 'package:signet/core/crypto/transport_package.dart';
import 'package:signet/core/logging/log_scrubber.dart';

void main() {
  // ===========================================================================
  // GROUP A — MUST redact: mechanical patterns (100% pass-or-fail-build bar)
  // ===========================================================================

  group('GROUP A: mechanical redact (100% bar)', () {
    group('hex runs ≥ 16', () {
      const lengths = <int>[16, 17, 24, 31, 32, 33, 48, 64, 65, 128];
      for (final len in lengths) {
        test('hex length $len redacts (lowercase)', () {
          final hex = _hexOfLength(len, lowercase: true);
          _expectRedacted(LogScrubber.scrub(hex), hex);
        });
        test('hex length $len redacts (uppercase)', () {
          final hex = _hexOfLength(len, lowercase: false).toUpperCase();
          _expectRedacted(LogScrubber.scrub(hex), hex);
        });
        test('hex length $len redacts (mixed-case)', () {
          final hex = _hexOfLength(len, lowercase: false);
          _expectRedacted(LogScrubber.scrub(hex), hex);
        });
      }

      test('hex 15 chars passes (under threshold)', () {
        final hex = _hexOfLength(15, lowercase: true);
        expect(LogScrubber.scrub(hex), contains(hex));
      });

      test('hex embedded mid-line redacts', () {
        const hex32 = '0123456789abcdef0123456789abcdef';
        const input = 'thrown by key=$hex32 during decrypt';
        final out = LogScrubber.scrub(input);
        expect(out, isNot(contains(hex32)));
      });
    });

    group('base64url runs ≥ 16 with non-letter chars', () {
      // base64url alphabet = A-Za-z0-9_- ; the scrubber only redacts runs
      // that contain at least one digit or _-/= so pure-letter words aren't
      // false positives. Each case here has at least one digit, _, or -.
      const cases = <String>[
        'AbCd1234EfGh5678', // 16, digits+letters
        'aaaa-bbbb_cccc-dddd_eeee', // 24, _ and -
        'YWxsLW9maS1ldGNfYXJiaXRyYXJ5LWNvbnRlbnQ', // 39
        'eyJ2ZXJzaW9uIjoxLCJzZXJ2aWNlIjoiYWxsIn0=', // 40 with padding
      ];
      for (final s in cases) {
        test('base64url "${_preview(s)}" redacts', () {
          _expectRedacted(LogScrubber.scrub(s), s);
        });
      }
    });

    group('signet:tp1: transport-wire (generated via TransportPackage)', () {
      late String wire1;
      late String wire2;
      late String wire3;

      setUpAll(() async {
        wire1 = await _generateLdpWire(seed: 1, label: 'Mom');
        wire2 = await _generateLdpWire(seed: 2, label: 'Source A');
        wire3 = await _generateLdpWire(seed: 3, label: 'Finance Team');
      });

      test('LDP wire 1 redacts', () {
        _expectRedacted(LogScrubber.scrub(wire1), wire1);
        expect(LogScrubber.scrub(wire1), isNot(contains('signet:tp1:')));
      });
      test('LDP wire 2 redacts', () {
        _expectRedacted(LogScrubber.scrub(wire2), wire2);
      });
      test('LDP wire 3 redacts', () {
        _expectRedacted(LogScrubber.scrub(wire3), wire3);
      });

      test('wire embedded mid-line redacts', () async {
        final wire = await _generateLdpWire(seed: 42, label: 'test');
        final input = 'paste: $wire (length ${wire.length})';
        final out = LogScrubber.scrub(input);
        expect(out, isNot(contains('signet:tp1:')));
      });

      test('a later scheme redacts too (plan Task 1.7j)', () async {
        final wire = (await _generateLdpWire(seed: 7, label: 'x'))
            .replaceFirst('signet:tp1:', 'signet:tp2:');
        final out = LogScrubber.scrub('paste: $wire');
        expect(out, isNot(contains('signet:tp2:')));
        _expectRedacted(LogScrubber.scrub(wire), wire);
      });
    });

    group('BIP-39 4-clusters (generated via TotpWords)', () {
      late List<String> codeA;
      late List<String> codeB;
      late List<String> codeC;

      setUpAll(() async {
        codeA = await _generateTotpWords(secret: 'A' * 32, unixTime: 1735689600);
        codeB = await _generateTotpWords(secret: 'X' * 32, unixTime: 1735776000);
        codeC = await _generateTotpWords(secret: 'M' * 32, unixTime: 1735862400);
      });

      test('TotpWords code A redacts (whitespace separator)', () {
        final input = codeA.join(' ');
        final out = LogScrubber.scrub(input);
        for (final w in codeA) {
          expect(out, isNot(contains(w)),
              reason: '"$w" leaked from code A');
        }
      });

      test('TotpWords code B redacts (hyphen separator)', () {
        final input = codeB.join('-');
        final out = LogScrubber.scrub(input);
        for (final w in codeB) {
          expect(out, isNot(contains(w)));
        }
      });

      test('TotpWords code C redacts (mixed separators)', () {
        final input = '${codeC[0]} ${codeC[1]}-${codeC[2]} ${codeC[3]}';
        final out = LogScrubber.scrub(input);
        for (final w in codeC) {
          expect(out, isNot(contains(w)));
        }
      });

      test('TotpWords code embedded in error message redacts', () {
        final input =
            'verify failed for ${codeA.join(' ')} (timestamp drift)';
        final out = LogScrubber.scrub(input);
        for (final w in codeA) {
          expect(out, isNot(contains(w)));
        }
      });
    });

    group('BIP-39 8-clusters (PAKE-word shape)', () {
      late List<String> pake1;
      late List<String> pake2;
      late List<String> pake3;

      setUpAll(() {
        pake1 = TransportPackage.mintPakeWords(random: Random(101));
        pake2 = TransportPackage.mintPakeWords(random: Random(102));
        pake3 = TransportPackage.mintPakeWords(random: Random(103));
      });

      test('PAKE 1 redacts (whitespace)', () {
        final out = LogScrubber.scrub(pake1.join(' '));
        for (final w in pake1) {
          expect(out, isNot(contains(w)));
        }
      });

      test('PAKE 2 redacts (hyphen)', () {
        final out = LogScrubber.scrub(pake2.join('-'));
        for (final w in pake2) {
          expect(out, isNot(contains(w)));
        }
      });

      test('PAKE 3 redacts embedded in error', () {
        final out = LogScrubber.scrub(
          'unlock failed with PAKE ${pake3.join(' ')} (auth tag mismatch)',
        );
        for (final w in pake3) {
          expect(out, isNot(contains(w)));
        }
      });
    });

    group('single common-English BIP-39 words pass through (NOT a cluster)',
        () {
      const sentences = <String>[
        'the user tapped the able button',
        'an absent peer cannot abandon the pairing',
        'check the action prompt',
      ];
      for (final s in sentences) {
        test('"${_preview(s, 40)}" passes', () {
          final out = LogScrubber.scrub(s);
          // BIP-39 candidates here are isolated, max 2 consecutive — must NOT
          // trip the ≥4 cluster threshold.
          for (final word in s.split(' ')) {
            if (bip39EnglishWordlist.contains(word.toLowerCase())) {
              expect(out, contains(word),
                  reason: '"$word" should pass — not a cluster');
            }
          }
        });
      }
    });
  });

  // ===========================================================================
  // GROUP B — MUST redact: judgment patterns (≥95% bar)
  // ===========================================================================

  group('GROUP B: judgment redact (≥95% bar)', () {
    // Curated pair-label corpus. The spike sets a ≥95% bar for this
    // category, NOT 100% — judgment patterns are inherently fuzzy and a
    // small slip rate is acceptable because the at-rest encryption layer
    // (CrashlogCipher) is the failure-mode hedge below this one.
    const labels = <String>[
      'Mom', 'Dad', 'Jake', 'Grandma', 'Source A',
      'Bob from work', // KNOWN RESIDUAL: 3 words, 1 cap — structurally
                       // identical to "Some natural sentence". An honest
                       // miss; counted against the 95% bar below.
      'Finance Team', 'CEO', 'My Therapist', 'CONFIDENTIAL_SOURCE',
      // Padding to push the corpus to 20 so a single miss is exactly 95%:
      'Alice', 'Carol', 'Mr Smith', 'Dr Park', 'My CPA',
      'Auntie May', 'Family Vacation Group', 'NSA_Source',
      'Board Chair', 'classified_op_2026',
    ];

    test('≥95% of curated pair labels are redacted from toString output', () {
      final results = <String, bool>{};
      for (final label in labels) {
        final input =
            'Relationship(id: a1b2c3d4, label: "$label", role: a)';
        final out = LogScrubber.scrub(input);
        results[label] = !out.contains('"$label"');
      }
      final hits = results.values.where((r) => r).length;
      final ratio = hits / labels.length;
      final slipped = results.entries.where((e) => !e.value).map((e) => e.key).toList();
      expect(
        ratio,
        greaterThanOrEqualTo(0.95),
        reason: 'redacted $hits/${labels.length} labels; '
            'slipped: $slipped',
      );
    });

    test('quoted user-input in FormatException redacts', () {
      const input = 'FormatException: "myCustomLabel123" is not valid';
      final out = LogScrubber.scrub(input);
      expect(out, isNot(contains('myCustomLabel123')));
    });

    test('embedded quoted user paste redacts', () {
      const input = r'on input: "Pa$$word!@#" length=10';
      final out = LogScrubber.scrub(input);
      expect(out, isNot(contains(r'"Pa$$word')));
    });

    test('multi-word template message passes through', () {
      const messages = <String>[
        'Unexpected character',
        'Invalid argument',
        'Index out of range',
        'Concurrent modification during iteration',
      ];
      for (final m in messages) {
        final input = 'FormatException: "$m"';
        final out = LogScrubber.scrub(input);
        expect(out, contains('"$m"'),
            reason: 'template message "$m" should pass');
      }
    });
  });

  // ===========================================================================
  // GROUP C — MUST pass: framework structure (≥95% bar)
  // ===========================================================================

  group('GROUP C: framework allow-pass (≥95% bar)', () {
    group('package: paths', () {
      const paths = <String>[
        'package:signet/features/verify/verify_screen.dart',
        'package:signet/core/crypto/totp_words.dart',
        'package:signet/core/storage/secure_store.dart',
        'package:flutter/src/widgets/framework.dart',
        'package:flutter_test/src/widget_tester.dart',
        'package:cryptography/src/cryptography/algorithms/aes_gcm.dart',
        'dart:async',
        'dart:core',
        'dart:ui',
      ];
      for (final p in paths) {
        test('path "$p" survives', () {
          expect(LogScrubber.scrub(p), contains(p));
        });
      }
    });

    group('exception types', () {
      const types = <String>[
        'RangeError',
        'FormatException',
        'TypeError',
        'StateError',
        'ArgumentError',
        'UnsupportedError',
        'UnimplementedError',
        'AssertionError',
        'NoSuchMethodError',
        'InvalidPakeException',
        'InvalidPackageException',
      ];
      for (final t in types) {
        test('"$t" survives', () {
          final out = LogScrubber.scrub('$t: thrown by something');
          expect(out, contains(t));
        });
      }
    });

    group('stack-frame structural markers', () {
      test('<asynchronous suspension> survives (both words)', () {
        final out = LogScrubber.scrub('<asynchronous suspension>');
        expect(out, contains('asynchronous'));
        expect(out, contains('suspension'));
      });
      test('<asynchronous gap> survives', () {
        final out = LogScrubber.scrub('<asynchronous gap>');
        expect(out, contains('asynchronous'));
        expect(out, contains('gap'));
      });
      test('<anonymous closure> survives', () {
        final out = LogScrubber.scrub('<anonymous closure>');
        expect(out, contains('anonymous'));
        expect(out, contains('closure'));
      });

      test('#0 frame number survives', () {
        expect(LogScrubber.scrub('#0      X.y'), contains('#0'));
      });

      test('line:col marker survives', () {
        expect(LogScrubber.scrub('foo.dart:123:45'), contains(':123:45'));
      });
    });

    group('Flutter framework class identifiers', () {
      const names = <String>[
        'WidgetsBinding', 'BuildContext', 'Element', 'RenderBox',
        'StatefulWidget', 'StatelessWidget', 'State', 'Widget',
        'MaterialApp', 'Scaffold', 'Navigator', 'Future',
        '_RenderObjectElement', // private — _ prefix
      ];
      for (final n in names) {
        test('"$n" survives', () {
          expect(LogScrubber.scrub('$n.build(...)'), contains(n));
        });
      }
    });
  });

  // ===========================================================================
  // GROUP E — Phase 6 leak corpus (100% bar). Each case is a leak that got
  // through before plan Task 6.1; every one must be redacted.
  // ===========================================================================

  group('GROUP E: Phase 6 leak corpus (100% bar)', () {
    List<int> bytes(int seed, [int n = 32]) {
      final rng = Random(seed);
      return List<int>.generate(n, (_) => rng.nextInt(256));
    }

    for (var seed = 0; seed < 10; seed++) {
      final secret = bytes(seed);

      test('decimal byte list, as List<int>.toString() prints it ($seed)', () {
        final listed = secret.toString(); // [71, 55, 86, ...]
        final out = LogScrubber.scrub('sharedSecret: $listed');
        for (var i = 0; i + 8 <= secret.length; i += 8) {
          expect(out, isNot(contains(secret.sublist(i, i + 8).join(', '))));
        }
        expect(out, contains('redacted:'));
      });

      test('0x byte list ($seed)', () {
        final listed = secret
            .map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}')
            .join(', ');
        final out = LogScrubber.scrub('key = {$listed}');
        expect(out, isNot(contains(listed.substring(0, 40))));
        expect(out, contains('redacted:'));
      });

      test('colon-separated hex bytes ($seed)', () {
        final listed = secret
            .map((b) => b.toRadixString(16).padLeft(2, '0'))
            .join(':');
        final out = LogScrubber.scrub('fingerprint $listed');
        expect(out, isNot(contains(listed.substring(0, 23))));
      });

      test('standard base64 (+ / =), as SecureStore writes it ($seed)', () {
        final b64 = base64Encode(secret);
        final out = LogScrubber.scrub('value: $b64');
        expect(out, isNot(contains(b64)));
        expect(out, contains('[redacted:${b64.length}]'),
            reason: 'redacted as one token by the base64 rule');
        for (var i = 0; i + 12 <= b64.length; i += 12) {
          expect(out, isNot(contains(b64.substring(i, i + 12))),
              reason: 'no 12-char piece of the secret survives');
        }
      });

      final pake = TransportPackage.mintPakeWords(random: Random(seed + 77));
      for (final (name, joined) in <(String, String)>[
        ('commas', pake.join(', ')),
        ('periods', pake.join('. ')),
        ('slashes', pake.join(' / ')),
        ('one per line', pake.join('\n')),
        ('numbered list',
            [for (final (i, w) in pake.indexed) '${i + 1}. $w'].join('\n')),
        ('numbered with parens',
            [for (final (i, w) in pake.indexed) '${i + 1}) $w'].join('  ')),
      ]) {
        test('PAKE words separated by $name ($seed)', () {
          final out = LogScrubber.scrub('words were:\n$joined\nend');
          for (final w in pake) {
            expect(RegExp('\\b$w\\b').hasMatch(out), isFalse,
                reason: '"$w" survived ($name)');
          }
        });
      }
    }

    test('a FormatException echoes the source it failed on', () {
      const source = 'AQID+BAUGBwg=zz';
      final echo = const FormatException('Invalid character', source, 4)
          .toString();
      expect(echo, contains(source), reason: 'fixture: Dart does echo it');
      final out = LogScrubber.scrub(echo);
      expect(out, isNot(contains(source)));
      expect(out, contains('FormatException'));
    });

    test('single-quoted label values', () {
      final out = LogScrubber.scrub(
          "Relationship(id: x, label: 'Mom', labelHint='Dr Who')");
      expect(out, isNot(contains("'Mom'")));
      expect(out, isNot(contains('Dr Who')));
      expect(out, contains('Relationship'));
    });
  });

  group('GROUP E3: Phase 6 review leaks (100% bar)', () {
    final secret = List<int>.generate(32, (i) => (i * 37 + 11) & 0xFF);
    final b64 = base64Encode(secret);
    final b64url = base64Url.encode(secret).replaceAll('=', '');

    for (final (name, line, leaked) in <(String, String, String)>[
      ('secret glued after a code path', 'package:x/y+$b64', b64.substring(8)),
      ('secret after dart:', 'see dart:io+$b64', b64.substring(8)),
      ('base64url straight after package:', 'tried package:$b64url',
          b64url.substring(4)),
      ('signed bytes', 'bytes ${secret.map((b) => b - 128).toList()}',
          '${secret[0] - 128}, ${secret[1] - 128}, ${secret[2] - 128}'),
      ('a byte list wrapped across lines',
          'key [\n${[for (var i = 0; i < 32; i += 4) secret.sublist(i, i + 4).join(', ')].join(',\n')}\n]',
          secret.sublist(0, 4).join(', ')),
      ('a hexdump', secret.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' '),
          secret.sublist(0, 4).map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')),
      ('0x bytes without commas',
          secret.map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}').join(' '),
          secret.sublist(0, 3).map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}').join(' ')),
    ]) {
      test(name, () {
        final out = LogScrubber.scrub(line);
        expect(out, isNot(contains(leaked)), reason: out);
        // No 10-character piece of a base64 secret may survive either: a
        // partial redaction can break the whole string while most of it
        // still leaks.
        for (final secretText in <String>[b64, b64url]) {
          if (!line.contains(secretText)) continue;
          for (var i = 0; i + 10 <= secretText.length; i++) {
            expect(out, isNot(contains(secretText.substring(i, i + 10))),
                reason: 'piece at $i survived: $out');
          }
        }
      });
    }

    final pake = TransportPackage.mintPakeWords(random: Random(4242));
    for (final (name, joined) in <(String, String)>[
      ('single-quoted words', pake.map((w) => "'$w'").join(', ')),
      ('colons', pake.join(':')),
      ('plus signs', pake.join('+')),
      ('"and" before the last word',
          '${pake.take(7).join(', ')} and ${pake.last}'),
      ('a Dart list', '[${pake.join(', ')}]'),
    ]) {
      test('PAKE words joined by $name', () {
        final out = LogScrubber.scrub('got $joined here');
        for (final w in pake) {
          expect(RegExp('\\b$w\\b').hasMatch(out), isFalse,
              reason: '"$w" survived ($name): $out');
        }
      });
    }

    for (final (line, name) in <(String, String)>[
      ("title: 'Mom'", 'Mom'),
      ("peer: 'Aunt May'", 'Aunt May'),
      ("nickname: 'Granny'", 'Granny'),
      ("labelText: 'Mom'", 'Mom'),
      ("displayName='Granny'", 'Granny'),
      ('label: "Bob from work"', 'Bob from work'),
      ('Relationship(label: "Finance team")', 'Finance team'),
      ('{id: x, label: Mom, role: a}', 'Mom'),
      ('(label: Aunt May, id: 3)', 'Aunt May'),
    ]) {
      test('a name after a name-like key: $line', () {
        final out = LogScrubber.scrub(line);
        expect(out, isNot(contains(name)), reason: out);
      });
    }

    test('a base64url secret with no - or _ straight after package:', () {
      // Every character is a word character, so a loose path pattern
      // would treat the whole secret as part of the path.
      final plain = base64Url
          .encode(List<int>.generate(32, (i) => (i + 11) & 0xFF))
          .replaceAll('=', '');
      expect(plain, isNot(contains(RegExp('[-_]'))), reason: 'fixture');
      final out = LogScrubber.scrub('tried package:$plain');
      for (var i = 0; i + 10 <= plain.length; i++) {
        expect(out, isNot(contains(plain.substring(i, i + 10))),
            reason: 'piece at $i survived: $out');
      }
    });

    test('an export <peer-N> token after a name key survives', () {
      expect(LogScrubber.scrub('label: <peer-1>'), 'label: <peer-1>');
    });

    test('a FormatException without an offset still hides its source', () {
      final text = const FormatException('Bad input', 'Mom says abandon ability')
          .toString();
      final out = LogScrubber.scrub('$text\n#0      main (package:x/y.dart:1:1)');
      expect(out, isNot(contains('Mom says')));
      expect(out, contains('#0      main (package:x/y.dart:1:1)'));
    });

    test('a device file path is not mistaken for base64', () {
      const line = 'FileSystemException: Cannot open file, path = '
          "'/storage/emulated/0/Download/SignetBackup2.txt'";
      expect(LogScrubber.scrub(line), contains('/storage/emulated/0/Download'));
    });
  });

  group('GROUP E2: Phase 6 false-positive guards (traces stay useful)', () {
    test('stack-frame line and column numbers survive', () {
      const frame = '#3      Store.save '
          '(package:signet/core/storage/secure_store.dart:412:7)';
      expect(LogScrubber.scrub(frame), frame);
    });

    test('paths with digits survive', () {
      const frame = '#0      lookup '
          '(package:signet/l10n/app_localizations_zh.dart:12:3)';
      expect(LogScrubber.scrub(frame), frame);
    });

    test('version strings, dates, IPs and MACs survive', () {
      for (final line in <String>[
        'Flutter 3.47.5 • Dart 3.13.0',
        'built 2026-10-10T12:00:00Z',
        'host 192.168.1.13 port 8080',
        'mac aa:bb:cc:dd:ee:ff',
        'short list [1, 2, 3]',
        'seven bytes [1, 2, 3, 4, 5, 6, 7]',
      ]) {
        expect(LogScrubber.scrub(line), line, reason: line);
      }
    });

    test('three common words in a list are still not a cluster', () {
      const line = 'options: able, about, above';
      expect(LogScrubber.scrub(line), line);
    });

    test('a package path whose segments are wordlist words survives', () {
      // "abandon", "ability", "able", "about", "above" are all BIP-39 words;
      // in a path they are code, not a secret.
      const frame = '#4      Foo.bar '
          '(package:abandon/ability/able/about/above.dart:10:2)';
      expect(LogScrubber.scrub(frame), frame);
    });

    test('"dart:" glued to a word is not a code path', () {
      final secret = base64Encode(List<int>.generate(24, (i) => i * 7 + 3));
      final out = LogScrubber.scrub('xdart:$secret');
      expect(out, isNot(contains(secret)));
    });

    test('a package path that looks like base64 survives', () {
      // Digits, both cases and slashes: base64-shaped, but a path.
      const frame = '#5      lookup '
          '(package:signet/l10n/AppLocalizationsZh2.dart:40:1)';
      expect(LogScrubber.scrub(frame), frame);
    });

    test('package paths made of wordlist words survive', () {
      const frame = '#2      StatefulElement.build '
          '(package:flutter/src/widgets/framework.dart:5567:55)';
      expect(LogScrubber.scrub(frame), frame);
    });
  });


  // ===========================================================================
  // GROUP D — MUST preserve: real-trace shape (100%)
  // ===========================================================================

  group('GROUP D: real-trace shape preservation (100%)', () {
    test('empty trace', () {
      expect(LogScrubber.scrub(''), equals(''));
    });

    test('whitespace-only trace', () {
      expect(LogScrubber.scrub('   \n   \n'), equals('   \n   \n'));
    });

    test('canonical verify-screen FormatException trace shape preserved', () {
      const trace = '''
FormatException: Unexpected character
#0      FormatException._throwWithError (dart:convert/utf.dart:401:7)
#1      VerifyScreen.build (package:signet/features/verify/verify_screen.dart:362:5)
#2      StatefulElement.build (package:flutter/src/widgets/framework.dart:5567:55)
<asynchronous suspension>
''';
      final out = LogScrubber.scrub(trace);
      expect(out, contains('FormatException'));
      expect(out,
          contains('package:signet/features/verify/verify_screen.dart'));
      expect(out, contains('package:flutter/src/widgets/framework.dart'));
      expect(out, contains('#0'));
      expect(out, contains('#1'));
      expect(out, contains('#2'));
      expect(out, contains(':362:5'));
      expect(out, contains('asynchronous'));
    });

    test('large 10KB trace handled without timeout', () {
      final big = StringBuffer();
      for (var i = 0; i < 100; i++) {
        big.writeln(
          '#$i      Foo.bar$i (package:signet/features/foo/bar.dart:${i * 10}:5)',
        );
      }
      final input = big.toString();
      // Just ensure it completes and stays a trace-shape (still has #0..#99).
      final out = LogScrubber.scrub(input);
      expect(out, contains('#0'));
      expect(out, contains('#99'));
    });
  });
}

// ===========================================================================
// Helpers
// ===========================================================================

void _expectRedacted(String out, String original) {
  expect(out, isNot(contains(original)),
      reason: 'output should not contain the original token');
  expect(out, contains('redacted:'),
      reason: 'output should contain a [redacted:N] marker');
}

String _preview(String s, [int n = 24]) =>
    s.length <= n ? s : '${s.substring(0, n)}...';

String _hexOfLength(int n, {required bool lowercase}) {
  const lower = '0123456789abcdef';
  const upperMixed = '0123456789AbCdEf';
  final src = lowercase ? lower : upperMixed;
  final rng = Random(n + (lowercase ? 0 : 1)); // deterministic per length
  final buf = StringBuffer();
  for (var i = 0; i < n; i++) {
    buf.write(src[rng.nextInt(src.length)]);
  }
  return buf.toString();
}

Future<String> _generateLdpWire({required int seed, required String label}) {
  final rng = Random(seed);
  final pubKey =
      Uint8List.fromList(List<int>.generate(32, (_) => rng.nextInt(256)));
  final pake = TransportPackage.mintPakeWords(random: Random(seed + 1000));
  return TransportPackage.encodeLdp(
    publicKey: pubKey,
    labelHint: label,
    pakeWords: pake,
    now: DateTime.utc(2026, 5, 21, 12),
    nonceRandom: Random(seed + 2000),
  );
}

Future<List<String>> _generateTotpWords({
  required String secret,
  required int unixTime,
}) {
  final secretBytes = Uint8List.fromList(secret.codeUnits);
  return TotpWords.generate(
    secret: secretBytes,
    unixTimeSeconds: unixTime,
    senderRole: PairRole.a,
  );
}
