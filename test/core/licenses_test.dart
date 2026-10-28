// The bundled font and data licences load and reach Flutter's licences
// page (lib/core/licenses.dart).

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:signet/core/licenses.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every bundled licence file exists and is not empty', () async {
    for (final (_, asset) in thirdPartyLicenses) {
      final text = await rootBundle.loadString(asset);
      expect(text.trim(), isNotEmpty, reason: asset);
    }
  });

  test('registered entries reach the LicenseRegistry', () async {
    registerThirdPartyLicenses();
    final packages = <String>{};
    await for (final entry in LicenseRegistry.licenses) {
      packages.addAll(entry.packages);
    }
    expect(packages, containsAll(<String>['Noto Sans', 'zh-1: pinyin-data',
        'zh-1: Unihan', 'zh-1: libchewing data']));
  });
}
