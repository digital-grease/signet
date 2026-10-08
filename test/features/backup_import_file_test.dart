// Loading a backup from a file (plan Task 7.5 D2 + bug S11): file_picker 13
// API, size cap before reading, UTF-8 decoding with BOM handling.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

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

import '../support/fake_secure_store.dart';

const _pake = <String>[
  'abandon', 'ability', 'able', 'about',
  'above', 'absent', 'absorb', 'abstract',
];

/// A picked file whose size may or may not be known up front, served as a
/// stream of chunks. Records how many chunks were read.
final class _FakeFile extends PlatformFile {
  _FakeFile(this.chunks, {this.knownLength});

  final List<List<int>> chunks;
  final int? knownLength;
  int chunksRead = 0;

  @override
  String get name => 'backup.txt';

  @override
  Uri get uri => Uri.parse('content://test/backup.txt');

  @override
  Never get xFile => throw UnimplementedError();

  @override
  int? lengthSync() => knownLength;

  @override
  Future<int?> length() async =>
      chunks.fold<int>(0, (n, c) => n + c.length);

  @override
  Future<Uint8List> readAsBytes() async =>
      Uint8List.fromList([for (final c in chunks) ...c]);

  @override
  Stream<Uint8List> readAsByteStream() async* {
    for (final c in chunks) {
      chunksRead++;
      yield Uint8List.fromList(c);
    }
  }
}

/// Single-file picker that returns [result] (null = cancelled) or throws
/// [error], and counts cache cleanups.
class _FakePicker extends FilePickerPlatform {
  _FakePicker(this.result, {this.error});

  final PlatformFile? result;
  final Object? error;
  int cleared = 0;

  @override
  Future<PlatformFile?> pickFile({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    dynamic Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    final e = error;
    if (e != null) throw e;
    return result;
  }

  @override
  Future<void> clearTemporaryFiles() async => cleared++;
}

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
  return BackupBundle.format(
    peerLabel: 'Mom',
    wire: wire,
    pakeWords: _pake,
    generatedAt: DateTime.utc(2026, 10, 7),
  );
}

Future<void> _loadFromFile(WidgetTester tester) async {
  await tester.pumpWidget(_wrap());
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('Load from file'));
  await tester.tap(find.text('Load from file'));
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
    final picker = _FakePicker(_FakeFile([utf8.encode(text)]));
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
    FilePickerPlatform.instance = _FakePicker(_FakeFile([
      [0xEF, 0xBB, 0xBF, ...utf8.encode(body)],
    ]));
    await _loadFromFile(tester);
    expect(_fieldText(tester), startsWith('signet:tp1:'));
  });

  testWidgets('an oversized file with a known size is refused unread',
      (tester) async {
    final file = _FakeFile([List<int>.filled(16, 0x41)],
        knownLength: 10 * 1024 * 1024);
    final picker = _FakePicker(file);
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
    final file = _FakeFile(
      List<List<int>>.generate(40, (_) => List<int>.filled(64 * 1024, 0x41)),
    );
    FilePickerPlatform.instance = _FakePicker(file);
    await _loadFromFile(tester);
    expect(find.textContaining('too large to be a Signet backup'),
        findsOneWidget);
    expect(file.chunksRead, lessThan(40),
        reason: 'stops as soon as the cap is passed');
  });

  testWidgets('a picker error shows a plain message and still cleans up',
      (tester) async {
    final picker = _FakePicker(null,
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
    FilePickerPlatform.instance = _FakePicker(null);
    await _loadFromFile(tester);
    expect(_fieldText(tester), isEmpty);
  });
}
