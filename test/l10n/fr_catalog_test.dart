// French catalog checks that the generated code alone does not catch
// (v0.5.0 plan Task 1.1).

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signet/l10n/app_localizations.dart';

void main() {
  final fr = lookupAppLocalizations(const Locale('fr'));

  // French puts 0 in the singular case, so a branch that spells out "1"
  // would show "1" for a count of 0.
  test('plurals show the real count at 0, 1 and 2', () {
    for (final n in [0, 1, 2]) {
      for (final text in [
        fr.wordsDisplaySemantics('a b c d', n),
        fr.bulkBackupExportReadyHeading(n),
        fr.bulkBackupExportDoneHeading(n),
        fr.bulkBackupExportShareSubject(n),
        fr.bulkBackupImportPreviewHeading(n),
        fr.bulkBackupImportRepairedNotice(n),
        fr.bulkBackupImportSkippedNewerNotice(n),
        fr.settingsUnreadableBody(n),
        fr.bulkBackupExportSkipsUnreadable(n),
      ]) {
        expect(RegExp(r'\d+').allMatches(text).map((m) => m.group(0)),
            everyElement('$n'),
            reason: text);
      }
    }
    expect(fr.wordsDisplaySemantics('a b c d', 0), endsWith('0 seconde'));
    expect(fr.wordsDisplaySemantics('a b c d', 2), endsWith('2 secondes'));
  });
}
