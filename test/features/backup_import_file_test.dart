// Loading a backup from a file (plan Task 7.5 D2 + bug S11): file_picker 13
// API, size cap before reading, UTF-8 decoding with BOM handling.

import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
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

Widget _wrap() {
  final router = GoRouter(
    initialLocation: '/inspect/import',
    routes: <RouteBase>[
      GoRoute(
        path: '/inspect/import',
        builder: (_, _) => const BackupImportScreen(),
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

Future<String> _bundleText() async {
  final wire = await TransportPackage.encodeLpr(
    label: 'Mom',
    role: PairRole.a,
    pairedAt: DateTime.utc(2026, 1, 1),
    silentHaptics: false,
    sharedSecret: List<int>.generate(32, (i) => i),
    pakeWords: _pake,
  );
  return LegacyBackupBundle.format(
    peerLabel: 'Mom',
    wire: wire,
    pakeWords: _pake,
    generatedAt: DateTime.utc(2026, 10, 7),
  );
}

Future<void> _loadFromFile(WidgetTester tester) async {
  await tester.pumpWidget(_wrap());
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('Load PACKAGE file'));
  await tester.tap(find.text('Load PACKAGE file'));
  await tester.pumpAndSettle();
}

String _fieldText(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField).first).controller!.text;

void main() {
  group('decodeBackupText', () {
    test('plain UTF-8 round-trips', () {
      expect(decodeBackupText(utf8.encode('# Signet · Jürgen\nx')),
          '# Signet · Jürgen\nx');
    });

    test('a leading UTF-8 byte order mark is dropped', () {
      expect(decodeBackupText([0xEF, 0xBB, 0xBF, ...utf8.encode('abc')]),
          'abc');
    });

    test('invalid bytes are replaced, not fatal', () {
      expect(decodeBackupText([0x61, 0xFF, 0x62]), 'a�b');
    });
  });

  testWidgets('a saved backup file loads, and the cached copy is cleared',
      (tester) async {
    final text = await _bundleText();
    final picker = FakeFilePicker([FakePickedFile([utf8.encode(text)])]);
    FilePickerPlatform.instance = picker;
    await _loadFromFile(tester);
    expect(_fieldText(tester), startsWith('signet:tp1:'));
    expect(picker.cleared, 1,
        reason: 'the picker leaves a plaintext copy in the cache');
  });

  testWidgets('a BOM right before the package line no longer breaks it',
      (tester) async {
    // The S11 failure: decoded as Latin-1, a UTF-8 byte order mark became
    // three junk characters glued to "signet:tp1:", so the package was
    // not found. (A BOM before a "#" comment line was harmless either way.)
    final text = await _bundleText();
    final body = text.split('\n').where((l) => !l.startsWith('#')).join('\n');
    FilePickerPlatform.instance = FakeFilePicker([
      FakePickedFile([
        [0xEF, 0xBB, 0xBF, ...utf8.encode(body)],
      ]),
    ]);
    await _loadFromFile(tester);
    expect(_fieldText(tester), startsWith('signet:tp1:'));
  });

  testWidgets('an oversized file with a known size is refused unread',
      (tester) async {
    final file = FakePickedFile([List<int>.filled(16, 0x41)],
        knownLength: 10 * 1024 * 1024);
    final picker = FakeFilePicker([file]);
    FilePickerPlatform.instance = picker;
    await _loadFromFile(tester);
    expect(find.textContaining('too large to be a Signet backup'),
        findsOneWidget);
    expect(file.chunksRead, 0, reason: 'never read when the size is known');
    expect(picker.cleared, 1);
  });

  testWidgets('an oversized file of unknown size stops reading at the cap',
      (tester) async {
    // 40 chunks of 64 KiB = 2.5 MiB, size not reported up front.
    final file = FakePickedFile(
      List<List<int>>.generate(40, (_) => List<int>.filled(64 * 1024, 0x41)),
    );
    FilePickerPlatform.instance = FakeFilePicker([file]);
    await _loadFromFile(tester);
    expect(find.textContaining('too large to be a Signet backup'),
        findsOneWidget);
    expect(file.chunksRead, lessThan(40),
        reason: 'stops as soon as the cap is passed');
  });

  testWidgets('a picker error shows a plain message and still cleans up',
      (tester) async {
    final picker = FakeFilePicker([null],
        error: StateError('already_active /data/user/0/cache/file_picker'));
    FilePickerPlatform.instance = picker;
    await _loadFromFile(tester);
    expect(find.textContaining('Could not read the selected file'),
        findsOneWidget);
    expect(find.textContaining('/data/user'), findsNothing,
        reason: 'exception text (cache paths) is never shown');
    expect(picker.cleared, 1);
  });

  testWidgets('cancelling the picker changes nothing', (tester) async {
    FilePickerPlatform.instance = FakeFilePicker([null]);
    await _loadFromFile(tester);
    expect(_fieldText(tester), isEmpty);
  });
}
