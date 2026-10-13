// Records what Signet copies, split by channel: the sensitive-copy channel
// used for secrets, and the plain Flutter clipboard.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class ClipboardRecord {
  final List<String> sensitive = [];
  final List<String> plain = [];
}

/// Install the recorder for the current test. Callers that copy through
/// SecureClipboard cancel its pending clear with resetForTesting().
ClipboardRecord recordClipboard() {
  final record = ClipboardRecord();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const secure = MethodChannel('dev.digitalgrease.signet/clipboard');
  messenger.setMockMethodCallHandler(secure, (call) async {
    if (call.method == 'copySensitive') {
      record.sensitive.add((call.arguments as Map)['text'] as String);
      return 'tracked';
    }
    return null;
  });
  messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method == 'Clipboard.setData') {
      record.plain.add((call.arguments as Map)['text'] as String);
    }
    return null;
  });
  addTearDown(() {
    messenger.setMockMethodCallHandler(secure, null);
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
  });
  return record;
}
