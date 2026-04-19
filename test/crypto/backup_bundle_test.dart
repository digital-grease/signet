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

  test('format writes a human-readable bundle with header + both artifacts',
      () {
    final out = BackupBundle.format(
      peerLabel: 'Mom',
      wire: goodWire,
      pakeWords: goodPake,
      generatedAt: DateTime.utc(2026, 4, 19, 12, 0),
    );
    expect(out, contains('# Signet backup · Mom · 2026-04-19T12:00:00Z'));
    expect(out, contains(goodWire));
    expect(out, contains(goodPake.join(' ')));
  });

  test('parse round-trips format output', () {
    final serialized = BackupBundle.format(
      peerLabel: 'Alice',
      wire: goodWire,
      pakeWords: goodPake,
      generatedAt: DateTime.utc(2026, 4, 19),
    );
    final parsed = BackupBundle.parse(serialized);
    expect(parsed.wire, goodWire);
    expect(parsed.pakeWords, goodPake);
  });

  test('parse ignores extra comment + blank lines', () {
    const text = '''
# a comment
# another

signet:tp1:ZZZ

abandon ability able about above absent absorb abstract
# trailing comment
''';
    final parsed = BackupBundle.parse(text);
    expect(parsed.wire, 'signet:tp1:ZZZ');
    expect(parsed.pakeWords.length, 8);
  });

  test('parse lowercases and trims PAKE tokens', () {
    const text = '''
signet:tp1:YYY
  Abandon   ABILITY able about ABOVE absent   absorb abstract
''';
    final parsed = BackupBundle.parse(text);
    expect(parsed.pakeWords, goodPake);
  });

  test('parse throws when the wire line is missing', () {
    const text = 'abandon ability able about above absent absorb abstract\n';
    expect(
      () => BackupBundle.parse(text),
      throwsA(isA<FormatException>()),
    );
  });

  test('parse throws when the PAKE line has too few words', () {
    const text = '''
signet:tp1:XXX
abandon ability able about above absent absorb
''';
    expect(
      () => BackupBundle.parse(text),
      throwsA(isA<FormatException>()),
    );
  });

  test('parse throws when a PAKE token is not in the BIP-39 wordlist', () {
    const text = '''
signet:tp1:XXX
abandon ability able about above absent absorb notaword
''';
    expect(
      () => BackupBundle.parse(text),
      throwsA(isA<FormatException>()),
    );
  });

  test('parse is tolerant of an 8-token line that happens to arrive BEFORE '
      'the wire line', () {
    const text = '''
abandon ability able about above absent absorb abstract
signet:tp1:QQQ
''';
    final parsed = BackupBundle.parse(text);
    expect(parsed.wire, 'signet:tp1:QQQ');
    expect(parsed.pakeWords, goodPake);
  });
}
