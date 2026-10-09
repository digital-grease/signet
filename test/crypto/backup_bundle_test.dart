import 'package:flutter_test/flutter_test.dart';
import 'package:signet/core/crypto/backup_bundle.dart';

void main() {
  const goodPake = <String>[
    'abandon',
    'ability',
    'able',
    'about',
    'above',
    'absent',
    'absorb',
    'abstract',
  ];
  const goodWire = 'signet:tp1:AAAAAABBBBBB';

  // ------------------------------------------------------------------------
  // Old single-file bundles (v0.3.6 and earlier) still read
  // ------------------------------------------------------------------------

  test('legacy format writes a header + both artifacts', () {
    final out = LegacyBackupBundle.format(
      peerLabel: 'Mom',
      wire: goodWire,
      pakeWords: goodPake,
      generatedAt: DateTime.utc(2026, 4, 19, 12, 0),
    );
    expect(out, contains('# Signet backup · Mom · 2026-04-19T12:00:00Z'));
    expect(out, contains(goodWire));
    expect(out, contains(goodPake.join(' ')));
  });

  test('a legacy bundle reads back as package + words', () {
    final read = BackupText.read(LegacyBackupBundle.format(
      peerLabel: 'Alice',
      wire: goodWire,
      pakeWords: goodPake,
      generatedAt: DateTime.utc(2026, 4, 19),
    ));
    expect(read.wire, goodWire);
    expect(read.pakeWords, goodPake);
    expect(read.isLegacyCombined, isTrue);
  });

  test('extra comment + blank lines are ignored', () {
    const text = '''
# a comment
# another

signet:tp1:ZZZ

abandon ability able about above absent absorb abstract
# trailing comment
''';
    final read = BackupText.read(text);
    expect(read.wire, 'signet:tp1:ZZZ');
    expect(read.pakeWords, goodPake);
  });

  test('words are lowercased and trimmed', () {
    const text = '''
signet:tp1:YYY
  Abandon   ABILITY able about ABOVE absent   absorb abstract
''';
    expect(BackupText.read(text).pakeWords, goodPake);
  });

  test('no package line: no wire, words still found', () {
    const text = 'abandon ability able about above absent absorb abstract\n';
    final read = BackupText.read(text);
    expect(read.wire, isNull);
    expect(read.pakeWords, goodPake);
    expect(read.isLegacyCombined, isFalse);
  });

  test('seven words are not the 8 words', () {
    const text = '''
signet:tp1:XXX
abandon ability able about above absent absorb
''';
    expect(BackupText.read(text).pakeWords, isNull);
  });

  test('a token outside the BIP-39 wordlist is not the 8 words', () {
    const text = '''
signet:tp1:XXX
abandon ability able about above absent absorb notaword
''';
    expect(BackupText.read(text).pakeWords, isNull);
  });

  test('the words line may come before the package line', () {
    const text = '''
abandon ability able about above absent absorb abstract
signet:tp1:QQQ
''';
    final read = BackupText.read(text);
    expect(read.wire, 'signet:tp1:QQQ');
    expect(read.pakeWords, goodPake);
  });

  // ------------------------------------------------------------------------
  // Two-file format (plan Task 2.1, bug S1)
  // ------------------------------------------------------------------------

  group('two-file backup', () {
    final when = DateTime.utc(2026, 10, 8, 12);
    const fp = '123 456';

    test('the PACKAGE file never contains the words or a contact name', () {
      final text = BackupFiles.formatPackage(
          wire: goodWire, fingerprint: fp, generatedAt: when);
      expect(text, contains(goodWire));
      expect(text, contains('# Fingerprint: 123 456'));
      expect(text, contains(BackupFiles.endOfPackageMarker));
      for (final w in goodPake) {
        expect(text.split(RegExp(r'\W+')), isNot(contains(w)));
      }
      expect(BackupText.read(text).pakeWords, isNull);
    });

    test('the WORDS file never contains the package', () {
      final text = BackupFiles.formatWords(
          pakeWords: goodPake, fingerprint: fp, generatedAt: when);
      expect(text, isNot(contains('signet:tp1:')));
      final read = BackupText.read(text);
      expect(read.pakeWords, goodPake);
      expect(read.wire, isNull);
      expect(read.declaredFingerprint, fp);
    });

    test('file names carry date and fingerprint, never a name', () {
      expect(BackupFiles.packageFileName(when, fp),
          'signet-backup-2026-10-08-123456-PACKAGE.txt');
      expect(BackupFiles.wordsFileName(when, fp),
          'signet-backup-2026-10-08-123456-WORDS.txt');
    });

    test('the PACKAGE file round-trips with its fingerprint', () {
      final read = BackupText.read(BackupFiles.formatPackage(
          wire: goodWire, fingerprint: fp, generatedAt: when));
      expect(read.wire, goodWire);
      expect(read.wireCandidates, [goodWire]);
      expect(read.hasEndMarker, isTrue);
      expect(read.declaredFingerprint, fp);
      expect(read.isLegacyCombined, isFalse);
    });

    test('a wrapped package line is rejoined up to the end marker', () {
      final text = BackupFiles.formatPackage(
          wire: 'signet:tp1:AAAABBBBCCCCDDDD', fingerprint: fp,
          generatedAt: when)
          .replaceFirst('AAAABBBB', 'AAAA\nBBBB\n');
      final read = BackupText.read(text);
      expect(read.wireCandidates, ['signet:tp1:AAAABBBBCCCCDDDD']);
    });

    test('CRLF line endings are handled', () {
      final text = BackupFiles.formatPackage(
              wire: goodWire, fingerprint: fp, generatedAt: when)
          .replaceAll('\n', '\r\n');
      expect(BackupText.read(text).wire, goodWire);
    });

    test('an old combined bundle is recognised as legacy', () {
      final text = LegacyBackupBundle.format(
          peerLabel: 'Mom', wire: goodWire, pakeWords: goodPake,
          generatedAt: when);
      final read = BackupText.read(text);
      expect(read.isLegacyCombined, isTrue);
      expect(read.wire, goodWire);
      expect(read.pakeWords, goodPake);
    });

    test('old format without a marker offers every join, longest first, and '
        'never swallows the words line', () {
      const text = 'signet:tp1:AAAA\nBBBB\nzoo\n'
          'abandon ability able about above absent absorb abstract\n';
      final read = BackupText.read(text);
      // "zoo" is valid base64url and a wordlist word: it may be the end of
      // the package, so it is offered, but shorter joins follow.
      expect(read.wireCandidates, [
        'signet:tp1:AAAABBBBzoo',
        'signet:tp1:AAAABBBB',
        'signet:tp1:AAAA',
      ]);
      expect(read.pakeWords, goodPake);
    });

    test('fingerprint is over the decoded bytes: padding and wrapping do '
        'not change it', () async {
      const wire = 'signet:tp1:AQIDBAUGBwgJCgsMDQ4PEA';
      final a = await BackupFiles.fingerprint(wire);
      final b = await BackupFiles.fingerprint('$wire==');
      expect(a, matches(RegExp(r'^\d{3} \d{3}$')));
      expect(b, a);
      expect(await BackupFiles.fingerprint('signet:tp1:AQIDBAUGBwgJCgsMDQ4PEQ'),
          isNot(a));
    });

    test('fingerprint of something that is not a wire is null', () async {
      expect(await BackupFiles.fingerprint('hello'), isNull);
      expect(await BackupFiles.fingerprint('signet:tp1:!!!'), isNull);
    });
  });
}
