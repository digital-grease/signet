// file_picker 13 fakes for the restore-screen tests.

import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// A picked file whose size may or may not be known up front, served as a
/// stream of chunks. Records how many chunks were read.
final class FakePickedFile extends PlatformFile {
  FakePickedFile(this.chunks, {this.knownLength});

  /// A small text file, size known.
  factory FakePickedFile.text(String text) {
    final bytes = utf8.encode(text);
    return FakePickedFile([bytes], knownLength: bytes.length);
  }

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

/// Single-file picker that hands out [results] in order (null, or running
/// out, means the user cancelled) or throws [error], and counts cache
/// cleanups.
class FakeFilePicker extends FilePickerPlatform {
  FakeFilePicker(List<PlatformFile?> results, {this.error})
      : _results = List.of(results);

  final List<PlatformFile?> _results;
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
    return _results.isEmpty ? null : _results.removeAt(0);
  }

  @override
  Future<void> clearTemporaryFiles() async => cleared++;
}
