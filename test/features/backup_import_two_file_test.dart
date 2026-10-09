// Restoring from the two-file backup (plan Task 2.3, bugs S1 + S5): the
// package and the words come in separately, by file, paste or typing; a
// words file from another backup is named as such; pasted share-sheet text
// and soft-wrapped packages work; old combined backups still restore.

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:signet/core/crypto/backup_bundle.dart';
import 'package:signet/core/crypto/pair_role.dart';
import 'package:signet/core/crypto/transport_package.dart';
import 'package:signet/core/providers.dart';
import 'package:signet/features/inspect/backup_import_screen.dart';
import 'package:signet/l10n/app_localizations.dart';

import '../support/fake_file_picker.dart';
import '../support/fake_secure_store.dart';

const _pake = <String>[
  'abandon', 'ability', 'able', 'about',
  'above', 'absent', 'absorb', 'abstract',
];
final _at = DateTime.utc(2026, 10, 8, 12);

Widget _wrap() {
  final router = GoRouter(
    initialLocation: '/inspect/import',
    routes: <RouteBase>[
      GoRoute(
        path: '/inspect/import',
        builder: (_, _) => const BackupImportScreen(),
      ),
      GoRoute(
        path: '/inspect/import-bulk',
        builder: (_, state) => Scaffold(
          body: Text(
              'BULK ${(state.extra! as BlkPackage).records.map((r) => r.label).join(',')}'),
        ),
      ),
    ],
  );
  return ProviderScope(
    overrides: [secureStoreProvider.overrideWithValue(FakeSecureStore())],
    child: MaterialApp.router(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      routerConfig: router,
    ),
  );
}

Future<String> _wire({String label = 'Mom', int seed = 0}) =>
    TransportPackage.encodeLpr(
      label: label,
      role: PairRole.a,
      pairedAt: DateTime.utc(2026, 1, 1),
      silentHaptics: false,
      sharedSecret: List<int>.generate(32, (i) => i + seed),
      pakeWords: _pake,
    );

Future<({String package, String words})> _files(String wire) async {
  final fp = (await BackupFiles.fingerprint(wire))!;
  return (
    package: BackupFiles.formatPackage(
        wire: wire, fingerprint: fp, generatedAt: _at),
    words: BackupFiles.formatWords(
        pakeWords: _pake, fingerprint: fp, generatedAt: _at),
  );
}

void _clipboard(String text) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method == 'Clipboard.getData') {
      return <String, dynamic>{'text': text};
    }
    return null;
  });
  addTearDown(() => TestDefaultBinaryMessengerBinding
      .instance.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, null));
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _loadPackageFile(WidgetTester tester, String text) async {
  FilePickerPlatform.instance = FakeFilePicker([FakePickedFile.text(text)]);
  await _tap(tester, find.text('Load PACKAGE file'));
}

Future<void> _loadWordsFile(WidgetTester tester, String text) async {
  FilePickerPlatform.instance = FakeFilePicker([FakePickedFile.text(text)]);
  await _tap(tester, find.text('Load WORDS file'));
}

Future<void> _pastePackage(WidgetTester tester, String text) async {
  _clipboard(text);
  await _tap(tester, find.text('Paste from clipboard').first);
}

Future<void> _pasteWords(WidgetTester tester, String text) async {
  _clipboard(text);
  await _tap(tester, find.text('Paste from clipboard').last);
}

Future<void> _typeWords(WidgetTester tester) async {
  // Slot 0 of the WordInput (TextField index 1; index 0 is the package).
  await tester.enterText(find.byType(TextField).at(1), _pake.join(' '));
  await tester.pumpAndSettle();
}

Future<void> _unlock(WidgetTester tester) =>
    _tap(tester, find.text('UNLOCK BACKUP'));

void _expectRestored(String label) {
  expect(find.text('COMMIT IMPORT'), findsOneWidget,
      reason: 'the backup unlocked');
  expect(find.text(label), findsOneWidget);
}

String _packageField(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField).first).controller!.text;

void main() {
  testWidgets('PACKAGE file + WORDS file restore', (tester) async {
    final f = await _files(await _wire());
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();
    await _loadPackageFile(tester, f.package);
    await _loadWordsFile(tester, f.words);
    await _unlock(tester);
    _expectRestored('Mom');
  });

  testWidgets('PACKAGE file + typed words restore', (tester) async {
    final f = await _files(await _wire());
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();
    await _loadPackageFile(tester, f.package);
    await _typeWords(tester);
    await _unlock(tester);
    _expectRestored('Mom');
  });

  testWidgets(
      'pasting the whole PACKAGE file text works (S5: was rejected as '
      '"not a backup")', (tester) async {
    final f = await _files(await _wire());
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();
    await _pastePackage(tester, f.package);
    expect(_packageField(tester), startsWith('signet:tp1:'));
    await _pasteWords(tester, f.words);
    await _unlock(tester);
    _expectRestored('Mom');
  });

  testWidgets('a package soft-wrapped by a mail client is rejoined',
      (tester) async {
    final wire = await _wire();
    final f = await _files(wire);
    // Wrap the package line at 40 characters, keeping the marker.
    final wrapped = f.package.replaceFirst(
      wire,
      [
        for (var i = 0; i < wire.length; i += 40)
          wire.substring(i, i + 40 > wire.length ? wire.length : i + 40),
      ].join('\r\n'),
    );
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();
    await _pastePackage(tester, wrapped);
    expect(_packageField(tester), wire);
    await _typeWords(tester);
    await _unlock(tester);
    _expectRestored('Mom');
  });

  testWidgets('a pasted, wrapped bare wire (no marker) still restores',
      (tester) async {
    final wire = await _wire();
    final wrapped = '${wire.substring(0, 50)}\n${wire.substring(50)}';
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();
    await _pastePackage(tester, wrapped);
    await _typeWords(tester);
    await _unlock(tester);
    _expectRestored('Mom');
  });

  testWidgets('words from a different backup are named as such',
      (tester) async {
    final mine = await _files(await _wire());
    final other = await _files(await _wire(label: 'Dad', seed: 100));
    final mineFp = (await BackupFiles.fingerprint(
        BackupText.read(mine.package).wire!))!;
    final otherFp = BackupText.read(other.words).declaredFingerprint!;
    expect(mineFp, isNot(otherFp), reason: 'fixture needs distinct backups');

    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();
    await _loadPackageFile(tester, mine.package);
    await _loadWordsFile(tester, other.words);
    await _unlock(tester);

    expect(find.textContaining('belong to a different backup'),
        findsOneWidget);
    expect(find.textContaining('package $mineFp, words $otherFp'),
        findsOneWidget);
    expect(find.text('COMMIT IMPORT'), findsNothing);
  });

  testWidgets(
      'a forged fingerprint in the PACKAGE header is ignored: the package '
      'is fingerprinted from its bytes', (tester) async {
    final f = await _files(await _wire());
    final wordsFp = BackupText.read(f.words).declaredFingerprint!;
    final other = await _files(await _wire(label: 'Dad', seed: 100));
    // Dad's package with Mom's fingerprint written in its header.
    final forged = other.package.replaceFirst(
        RegExp(r'# Fingerprint: \d{3} \d{3}'), '# Fingerprint: $wordsFp');
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();
    await _loadPackageFile(tester, forged);
    await _loadWordsFile(tester, f.words);
    await _unlock(tester);
    expect(find.textContaining('belong to a different backup'),
        findsOneWidget);
  });

  testWidgets('a WORDS file given as the package says so', (tester) async {
    final f = await _files(await _wire());
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();
    await _loadPackageFile(tester, f.words);
    expect(find.text('Those are the 8 words, not the package. Put them under step 2.'),
        findsOneWidget);
    expect(_packageField(tester), isEmpty);
  });

  testWidgets('a PACKAGE file given as the words says so', (tester) async {
    final f = await _files(await _wire());
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();
    await _loadWordsFile(tester, f.package);
    expect(find.text('That is the package, not the words. Put it under step 1.'),
        findsOneWidget);
  });

  testWidgets('text with no words, given as the words, says so',
      (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();
    await _pasteWords(tester, 'hello there');
    expect(find.textContaining('No backup words found'), findsOneWidget);
  });

  testWidgets(
      'an old combined backup restores from one file, with a notice to '
      'replace it', (tester) async {
    final legacy = LegacyBackupBundle.format(
      peerLabel: 'Mom',
      wire: await _wire(),
      pakeWords: _pake,
      generatedAt: _at,
    );
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();
    await _loadPackageFile(tester, legacy);
    expect(find.textContaining('This old backup keeps the words'),
        findsOneWidget);
    await _unlock(tester);
    _expectRestored('Mom');
    expect(find.textContaining('This old backup keeps the words'),
        findsOneWidget,
        reason: 'repeated on the confirm screen');
  });

  // Without the end marker, a lone wordlist line after the package could
  // be its last wrapped piece (every BIP-39 word is valid base64url). A
  // join that takes it in either fails to parse ("abandon") or parses and
  // fails to decrypt ("zoo"); both fall back to the shorter join.
  for (final lone in <String>['abandon', 'zoo']) {
    testWidgets(
        'old backup: a wrapped package followed by a lone "$lone" line '
        'still restores', (tester) async {
      final wire = await _wire();
      final legacy = '# Signet backup · Mom · 2026-10-08T12:00:00Z\n'
          '${wire.substring(0, 50)}\n'
          '${wire.substring(50)}\n'
          '$lone\n'
          'ability able about above absent absorb abstract\n';
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      await _loadPackageFile(tester, legacy);
      await _typeWords(tester);
      await _unlock(tester);
      _expectRestored('Mom');
    });
  }

  testWidgets('wrong words on a wrapped old backup still say "wrong words"',
      (tester) async {
    final wire = await _wire();
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();
    await _pastePackage(
        tester, '${wire.substring(0, 50)}\n${wire.substring(50)}');
    await tester.enterText(find.byType(TextField).at(1),
        'zoo zoo zoo zoo zoo zoo zoo zoo');
    await tester.pumpAndSettle();
    await _unlock(tester);
    expect(find.textContaining('Could not unlock'), findsOneWidget);
  });

  testWidgets('a bulk PACKAGE file + WORDS file hand off to the bulk restore',
      (tester) async {
    final wire = await TransportPackage.encodeBlk(
      records: <BlkRelationshipRecord>[
        for (final (i, label) in <String>['Mom', 'Dad'].indexed)
          BlkRelationshipRecord(
            sharedSecret: Uint8List.fromList(List<int>.generate(32, (j) => j + i)),
            role: PairRole.a,
            label: label,
            pairedAt: DateTime.utc(2026, 1, 1),
            silentHaptics: false,
          ),
      ],
      pakeWords: _pake,
    );
    final f = await _files(wire);
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();
    await _loadPackageFile(tester, f.package);
    await _loadWordsFile(tester, f.words);
    await _unlock(tester);
    expect(find.text('BULK Mom,Dad'), findsOneWidget);
  });

  testWidgets('a bulk package with words from another backup is caught',
      (tester) async {
    final wire = await TransportPackage.encodeBlk(
      records: <BlkRelationshipRecord>[
        BlkRelationshipRecord(
          sharedSecret: Uint8List.fromList(List<int>.generate(32, (j) => j)),
          role: PairRole.a,
          label: 'Mom',
          pairedAt: DateTime.utc(2026, 1, 1),
          silentHaptics: false,
        ),
      ],
      pakeWords: _pake,
    );
    final mine = await _files(wire);
    final other = await _files(await _wire(label: 'Dad', seed: 100));
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();
    await _loadPackageFile(tester, mine.package);
    await _loadWordsFile(tester, other.words);
    await _unlock(tester);
    expect(find.textContaining('belong to a different backup'),
        findsOneWidget);
    expect(find.textContaining('BULK'), findsNothing);
  });

  for (final (name, text) in <(String, String)>[
    ('one per line', _pake.join('\n')),
    ('numbered', [for (final (i, w) in _pake.indexed) '${i + 1}. $w'].join('\n')),
    ('comma-separated', _pake.join(', ')),
    ('two lines of four', '${_pake.take(4).join(' ')}\n${_pake.skip(4).join(' ')}'),
  ]) {
    testWidgets('pasted words $name are accepted', (tester) async {
      final f = await _files(await _wire());
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      await _loadPackageFile(tester, f.package);
      await _pasteWords(tester, text);
      await _unlock(tester);
      _expectRestored('Mom');
    });
  }

  testWidgets(
      'after a fingerprint mismatch the right words can be typed in',
      (tester) async {
    final mine = await _files(await _wire());
    final other = await _files(await _wire(label: 'Dad', seed: 100));
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();
    await _loadPackageFile(tester, mine.package);
    await _loadWordsFile(tester, other.words);
    await _unlock(tester);
    expect(find.textContaining('belong to a different backup'),
        findsOneWidget);
    await _typeWords(tester);
    await _unlock(tester);
    _expectRestored('Mom');
  });

  testWidgets(
      'an old combined backup loaded after a words file uses its own words',
      (tester) async {
    final other = await _files(await _wire(label: 'Dad', seed: 100));
    final legacy = LegacyBackupBundle.format(
      peerLabel: 'Mom',
      wire: await _wire(),
      pakeWords: _pake,
      generatedAt: _at,
    );
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();
    await _loadWordsFile(tester, other.words);
    await _loadPackageFile(tester, legacy);
    await _unlock(tester);
    _expectRestored('Mom');
  });
}
