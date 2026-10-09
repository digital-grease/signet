// shareTextFile / sweepSharedExports against a real temporary directory
// (plan Phase 2, bug S1): the shared file holds exactly the given text, and
// the sweep removes both our export folder and share_plus's cache copies.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:share_plus_platform_interface/share_plus_platform_interface.dart';
import 'package:signet/shared/share_text_file.dart';

class _FakeShare extends SharePlatform with MockPlatformInterfaceMixin {
  final List<({String path, String? mimeType, String content})> shared = [];
  ShareResultStatus status = ShareResultStatus.success;

  @override
  Future<ShareResult> share(ShareParams params) async {
    for (final f in params.files ?? const <XFile>[]) {
      shared.add((
        path: f.path,
        mimeType: f.mimeType,
        content: await File(f.path).readAsString(),
      ));
    }
    return ShareResult('ok', status);
  }
}

class _FakePaths extends PathProviderPlatform with MockPlatformInterfaceMixin {
  _FakePaths(this.tmp);
  final String tmp;

  @override
  Future<String?> getTemporaryPath() async => tmp;
}

void main() {
  late Directory tmp;
  // One fake for the whole file: SharePlus.instance binds to the platform
  // instance the first time it is used, so a per-test fake would be
  // ignored after the first test.
  final share = _FakeShare();

  setUpAll(() => SharePlatform.instance = share);

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('signet_share_');
    share.shared.clear();
    share.status = ShareResultStatus.success;
    PathProviderPlatform.instance = _FakePaths(tmp.path);
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  test('shares one text file with exactly the given content', () async {
    await shareTextFile(fileName: 'a-PACKAGE.txt', text: 'line 1\nline 2\n');

    final f = share.shared.single;
    expect(f.path, '${tmp.path}/signet_export/a-PACKAGE.txt');
    expect(f.mimeType, 'text/plain');
    expect(f.content, 'line 1\nline 2\n');
  });

  test('reports a dismissed share sheet as not saved', () async {
    share.status = ShareResultStatus.dismissed;
    expect(await shareTextFile(fileName: 'a.txt', text: 'x'), isFalse);
    share.status = ShareResultStatus.unavailable;
    expect(await shareTextFile(fileName: 'a.txt', text: 'x'), isTrue,
        reason: 'platforms that cannot tell count as saved');
    share.status = ShareResultStatus.success;
    expect(await shareTextFile(fileName: 'a.txt', text: 'x'), isTrue);
  });

  test('the PACKAGE file is gone before the WORDS file is written',
      () async {
    await shareTextFile(fileName: 'b-PACKAGE.txt', text: 'package');
    await shareTextFile(fileName: 'b-WORDS.txt', text: 'words');
    final names = Directory('${tmp.path}/signet_export')
        .listSync()
        .map((e) => e.uri.pathSegments.last)
        .toList();
    expect(names, <String>['b-WORDS.txt']);
  });

  test('sweep deletes our export folder and share_plus cache copies',
      () async {
    await shareTextFile(fileName: 'a-WORDS.txt', text: 'words');
    Directory('${tmp.path}/share_plus').createSync();
    File('${tmp.path}/share_plus/copy.txt').writeAsStringSync('words');
    final unrelated = File('${tmp.path}/keep.txt')..writeAsStringSync('x');

    await sweepSharedExports();

    expect(Directory('${tmp.path}/signet_export').existsSync(), isFalse);
    expect(Directory('${tmp.path}/share_plus').existsSync(), isFalse);
    expect(unrelated.existsSync(), isTrue, reason: 'only our folders go');
  });

  test('sweep with nothing to delete is a no-op', () async {
    await sweepSharedExports();
    expect(tmp.existsSync(), isTrue);
  });
}
