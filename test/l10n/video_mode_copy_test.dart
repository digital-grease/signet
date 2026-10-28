// Video-mode toggle copy (v0.5.0 plan Task 1.1b).

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signet/l10n/app_localizations.dart';

void main() {
  // The other person's phone shows their gesture next to their words. A
  // verifier who asks for it aloud lets a realtime deepfake hear it and
  // perform it, so the on-text must say not to, in every catalog.
  const notAloud = {
    'en': 'aloud',
    'fr': 'voix haute',
    'zh': '不要说',
  };

  test('every catalog is covered', () {
    expect(
      AppLocalizations.supportedLocales.map((l) => l.languageCode).toSet(),
      notAloud.keys.toSet(),
    );
  });

  for (final MapEntry(key: code, value: phrase) in notAloud.entries) {
    test('$code video-mode text says not to say the gesture aloud', () {
      final l10n = lookupAppLocalizations(Locale(code));
      expect(l10n.verifyVideoModeOnText, contains(phrase));
    });
  }
}
