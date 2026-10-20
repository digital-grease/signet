// The per-app language lists offered by the OS (Android localeConfig, iOS
// CFBundleLocalizations) must match the translation catalogs in lib/l10n:
// a listed language without a catalog would silently show English, and a
// catalog missing from the lists could not be picked per app.

import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signet/l10n/app_localizations.dart';
import 'package:signet/l10n/locale_resolution.dart';

Locale _parseTag(String tag) {
  final parts = tag.split(RegExp('[-_]'));
  return Locale.fromSubtags(
    languageCode: parts.first,
    scriptCode: parts.length > 1 && parts[1].length == 4 ? parts[1] : null,
  );
}

void main() {
  const supported = AppLocalizations.supportedLocales;
  final catalogs = supported.map((l) => l.languageCode).toSet();

  final android = RegExp(r'<locale android:name="([^"]+)"')
      .allMatches(File('android/app/src/main/res/xml/locales_config.xml')
          .readAsStringSync())
      .map((m) => _parseTag(m.group(1)!))
      .toList();

  final plist = File('ios/Runner/Info.plist').readAsStringSync();
  final iosArray = RegExp(
    r'<key>CFBundleLocalizations</key>\s*<array>(.*?)</array>',
    dotAll: true,
  ).firstMatch(plist)!.group(1)!;
  final ios = RegExp('<string>([^<]+)</string>')
      .allMatches(iosArray)
      .map((m) => _parseTag(m.group(1)!))
      .toList();

  for (final (name, listed) in [('Android', android), ('iOS', ios)]) {
    test('$name lists exactly the translated languages', () {
      expect(listed.map((l) => l.languageCode).toSet(), catalogs);
      expect(listed.length, catalogs.length, reason: 'duplicate entry');
    });

    test('every $name entry resolves to its own catalog', () {
      for (final locale in listed) {
        expect(
          resolveSignetLocale([locale], supported).languageCode,
          locale.languageCode,
          reason: '$locale would fall back to English',
        );
      }
    });
  }
}
