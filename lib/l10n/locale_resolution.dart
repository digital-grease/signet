import 'package:flutter/widgets.dart';

/// Picks the app locale from the device's preferred-locale list.
///
/// Flutter's default resolution matches on language code alone, so a
/// Traditional Chinese device (zh-Hant, or zh-TW / zh-HK / zh-MO with no
/// script subtag) would be served the Simplified catalog in `app_zh.arb`.
/// Security copy in the wrong script is worse than English, so those
/// locales are skipped here and resolution falls through to the next
/// preferred locale, then to English.
Locale resolveSignetLocale(
  List<Locale>? preferred,
  Iterable<Locale> supported,
) {
  const fallback = Locale('en');
  final supportedLanguages = supported.map((l) => l.languageCode).toSet();
  for (final locale in preferred ?? const <Locale>[]) {
    if (_isTraditionalChinese(locale)) continue;
    if (supportedLanguages.contains(locale.languageCode)) {
      return Locale(locale.languageCode);
    }
  }
  return fallback;
}

const _traditionalChineseRegions = {'TW', 'HK', 'MO'};

bool _isTraditionalChinese(Locale locale) {
  if (locale.languageCode != 'zh') return false;
  final script = locale.scriptCode;
  if (script != null) return script == 'Hant';
  return _traditionalChineseRegions.contains(locale.countryCode);
}
