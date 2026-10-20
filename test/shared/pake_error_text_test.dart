// pakeErrorText (plan Task 8.4, review finding): the two refusals the
// words themselves explain get plain localized copy; the rest keep the
// unlock error as before.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signet/core/crypto/transport_package.dart';
import 'package:signet/core/crypto/wordlists.dart';
import 'package:signet/l10n/app_localizations.dart';
import 'package:signet/shared/package_error_text.dart';

void main() {
  const english = <String>[
    'abandon', 'ability', 'able', 'about', //
    'above', 'absent', 'absorb', 'abstract',
  ];

  InvalidPakeException refusal(List<String> words) {
    try {
      TransportPackage.pakeCandidates(words);
    } on InvalidPakeException catch (e) {
      return e;
    }
    fail('expected the words to be refused');
  }

  final unknown = refusal([...english]..[2] = 'zzqx');
  final mixed = refusal([
    ...english.take(4),
    for (final w in english.skip(4))
      WordList.french.wordAt(WordList.english.indexOf(w)!),
  ]);

  test('refusals carry their reason and position', () {
    expect(unknown.reason, InvalidPakeReason.unknownWord);
    expect(unknown.slot, 3);
    expect(mixed.reason, InvalidPakeReason.mixedLanguages);
    expect(refusal(english.take(7).toList()).reason, isNull);
  });

  for (final locale in AppLocalizations.supportedLocales) {
    test('${locale.languageCode}: localized, never the developer text', () {
      final l10n = lookupAppLocalizations(Locale(locale.languageCode));
      final unknownText = pakeErrorText(unknown, l10n);
      expect(unknownText, l10n.pakeUnknownWordError(3));
      expect(unknownText, contains('3'));
      expect(unknownText, isNot(contains('BIP-39')));
      expect(pakeErrorText(mixed, l10n), l10n.pakeMixedLanguagesError);
      expect(pakeErrorText(mixed, l10n), isNot(contains('mix languages')));
    });
  }

  test('other refusals keep the unlock error with the message', () {
    final l10n = lookupAppLocalizations(const Locale('en'));
    const wrong = InvalidPakeException('PAKE secret is wrong.');
    expect(
      pakeErrorText(wrong, l10n),
      l10n.commonUnlockFailedError('PAKE secret is wrong.'),
    );
  });
}
