import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signet/l10n/app_localizations.dart';
import 'package:signet/l10n/locale_resolution.dart';

void main() {
  const supported = AppLocalizations.supportedLocales;

  Locale resolve(List<Locale> preferred) =>
      resolveSignetLocale(preferred, supported);

  test('English device resolves to English', () {
    expect(resolve(const [Locale('en', 'US')]), const Locale('en'));
  });

  test('Simplified Chinese devices resolve to zh', () {
    expect(resolve(const [Locale('zh')]), const Locale('zh'));
    expect(resolve(const [Locale('zh', 'CN')]), const Locale('zh'));
    expect(resolve(const [Locale('zh', 'SG')]), const Locale('zh'));
    expect(
      resolve(const [
        Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
      ]),
      const Locale('zh'),
    );
  });

  test('Traditional Chinese devices never get the Simplified catalog', () {
    for (final locale in const [
      Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
      Locale.fromSubtags(
        languageCode: 'zh',
        scriptCode: 'Hant',
        countryCode: 'TW',
      ),
      Locale('zh', 'TW'),
      Locale('zh', 'HK'),
      Locale('zh', 'MO'),
    ]) {
      expect(resolve([locale]), const Locale('en'), reason: '$locale');
    }
  });

  test('explicit Hans script wins over a Traditional region', () {
    expect(
      resolve(const [
        Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hans',
          countryCode: 'HK',
        ),
      ]),
      const Locale('zh'),
    );
  });

  test('skipped Traditional locale falls through to the next preference', () {
    expect(
      resolve(const [Locale('zh', 'TW'), Locale('zh', 'CN')]),
      const Locale('zh'),
    );
  });

  test('unsupported or empty preferences fall back to English', () {
    expect(resolve(const [Locale('fr', 'FR')]), const Locale('en'));
    expect(resolve(const []), const Locale('en'));
    expect(resolveSignetLocale(null, supported), const Locale('en'));
  });
}
