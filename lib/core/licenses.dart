import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

/// Licences of the data and font Signet bundles that are not Dart
/// packages (those are listed by Flutter automatically). Shown on the
/// licences page opened from About.
///
/// - Noto Sans and Noto Sans CJK (subsets in the printed card's PDF): SIL
///   OFL 1.1.
/// - zh-1 word list (lib/core/crypto/zh_wordlist.dart): headwords from the
///   HSK 3.0 syllabus via complete-hsk-vocabulary (MIT); pinyin from
///   pypinyin (MIT); traditional forms from OpenCC (Apache-2.0); Zhuyin
///   from libchewing data (LGPL-2.1-or-later) and McBopomofo (MIT). See
///   tool/zh_wordlist/SOURCES.md.
/// - zh-1 reading table (lib/core/crypto/zh_reading_table.dart): pinyin-data
///   (MIT) through pypinyin, derived from Unihan (Unicode License v3).
const List<(List<String>, String)> thirdPartyLicenses = <(List<String>, String)>[
  (<String>['Noto Sans', 'Noto Sans CJK'], 'assets/fonts/OFL.txt'),
  (<String>['zh-1: complete-hsk-vocabulary'],
      'assets/licenses/complete-hsk-vocabulary-MIT.txt'),
  (<String>['zh-1: pypinyin'], 'assets/licenses/pypinyin-MIT.txt'),
  (<String>['zh-1: pinyin-data'], 'assets/licenses/pinyin-data-MIT.txt'),
  (<String>['zh-1: Unihan'], 'assets/licenses/Unicode-3.0.txt'),
  (<String>['zh-1: OpenCC'], 'assets/licenses/OpenCC-Apache-2.0.txt'),
  (<String>['zh-1: libchewing data'],
      'assets/licenses/libchewing-data-LGPL-2.1.txt'),
  (<String>['zh-1: McBopomofo'], 'assets/licenses/McBopomofo-MIT.txt'),
];

/// Adds [thirdPartyLicenses] to Flutter's [LicenseRegistry]. Call once
/// before runApp.
void registerThirdPartyLicenses() {
  LicenseRegistry.addLicense(() async* {
    for (final (packages, asset) in thirdPartyLicenses) {
      yield LicenseEntryWithLineBreaks(
          packages, await rootBundle.loadString(asset));
    }
  });
}
