import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Folder under the app's temporary directory that holds files we hand to
/// the share sheet. Backup files are plaintext (a package file, or the 8
/// words), so nothing may linger there: see [sweepSharedExports].
const String _exportDirName = 'signet_export';

/// share_plus copies shared files into this cache subfolder for its
/// FileProvider (Android) before handing them to the receiving app.
const String _sharePlusCacheDirName = 'share_plus';

/// Write [text] to a file named [fileName] and open the share sheet with it,
/// so the user can save it with the app of their choice (Files, a USB
/// stick, Bluetooth). Signet never picks a destination.
///
/// Returns false when the user backed out of the share sheet, so the
/// caller does not treat the file as saved. Platforms that cannot report
/// the outcome count as saved.
///
/// The file is written to a known folder rather than handed to share_plus
/// as in-memory data, which would make share_plus write its own extra copy
/// in a random temporary folder. The folder is emptied first, so the
/// PACKAGE and WORDS files of one backup never sit in it together.
Future<bool> shareTextFile({
  required String fileName,
  required String text,
  String? subject,
}) async {
  final dir = Directory('${(await getTemporaryDirectory()).path}/$_exportDirName');
  if (await dir.exists()) await dir.delete(recursive: true);
  await dir.create(recursive: true);
  final file = File('${dir.path}/$fileName');
  await file.writeAsString(text, flush: true);
  final result = await SharePlus.instance.share(
    ShareParams(
      files: <XFile>[XFile(file.path, mimeType: 'text/plain')],
      subject: subject,
    ),
  );
  return result.status != ShareResultStatus.dismissed;
}

/// Delete every file Signet has handed to the share sheet, and share_plus's
/// own cache copies. Called when an export screen closes and at app start.
///
/// Not called the instant the share sheet returns: the receiving app (a
/// cloud upload, say) may still be reading the file at that point.
Future<void> sweepSharedExports() async {
  try {
    final tmp = (await getTemporaryDirectory()).path;
    for (final name in <String>[_exportDirName, _sharePlusCacheDirName]) {
      final dir = Directory('$tmp/$name');
      if (await dir.exists()) await dir.delete(recursive: true);
    }
  } catch (_) {
    // Best effort; the OS clears the temporary directory eventually.
  }
}
