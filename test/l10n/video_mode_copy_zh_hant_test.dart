// Video-mode toggle copy in Traditional Chinese (v0.5.0 plan Task 1.1b).
// The other person's phone shows their gesture next to their words; a
// verifier who asks for it aloud lets a realtime deepfake hear it and
// perform it, so the on-text says not to. The Traditional catalog was made
// from the Simplified one before that fix, so it is checked here too.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signet/l10n/app_localizations.dart';

void main() {
  test('zh-Hant video-mode text says not to say the gesture aloud', () {
    final l10n = lookupAppLocalizations(
        const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'));
    expect(l10n.verifyVideoModeOnText, contains('不要說'));
  });
}
