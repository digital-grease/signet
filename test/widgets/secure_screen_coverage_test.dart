import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every screen that renders secret-derived material (rotating words,
/// pair-time or binding phrase, PAKE words, transport packages, the
/// challenge-response grid) must be wrapped in `SecureScreen` so Android
/// sets FLAG_SECURE and iOS blurs the app switcher snapshot.
///
/// Two checks: each listed screen constructs a `SecureScreen` in code (not
/// just in a comment), and any feature file that touches secret material
/// must be listed here or explicitly allowlisted with a reason, so a new
/// secret-bearing screen cannot slip in unwrapped.
const _secretBearingScreens = <String>{
  'lib/features/verify/verify_screen.dart',
  'lib/features/inspect/binding_phrase_screen.dart',
  'lib/features/inspect/cr_grid_screen.dart',
  'lib/features/inspect/backup_export_screen.dart',
  'lib/features/inspect/backup_import_screen.dart',
  'lib/features/inspect/bulk_backup_export_screen.dart',
  'lib/features/inspect/bulk_backup_import_screen.dart',
  'lib/features/pairing/pair_exchange_screen.dart',
  'lib/features/pairing/pair_confirm_screen.dart',
  'lib/features/pairing/pair_transport_in_screen.dart',
  'lib/features/pairing/pair_transport_out_screen.dart',
};

/// Feature files that reference secret material but render none of it on
/// screen. Each needs a reason.
const _allowlist = <String, String>{
  'lib/features/pairing/pairing_controller.dart':
      'state holder; renders nothing',
  'lib/features/inspect/cr_grid_pdf.dart':
      'builds the printed card off-screen; the caller screen is wrapped',
  'lib/features/verify/word_input.dart':
      'input widget embedded in the wrapped verify screen',
  'lib/features/pairing/pair_complete_screen.dart':
      'reads the phrase only to bounce home when absent; shows none',
  'lib/features/home/home_screen.dart':
      'unpair UNDO restores the secret from memory; never displays it',
};

final _secretMarkers = RegExp(
  r'TotpWords|pakeWords|PakeWords|BackupBundle|TransportPackage|'
  r'ChallengeResponseGrid|derivePhrase|\.phrase\b|sharedSecret|totpSecret',
);

String _stripComments(String source) => source
    .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
    .replaceAll(RegExp(r'//[^\n]*'), '');

void main() {
  for (final path in _secretBearingScreens) {
    test('$path constructs a SecureScreen', () {
      final code = _stripComments(File(path).readAsStringSync());
      expect(code, contains('SecureScreen('), reason: path);
    });
  }

  test('every feature file touching secret material is covered', () {
    final unlisted = <String>[];
    for (final entity in Directory('lib/features').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll(r'\', '/');
      final code = _stripComments(entity.readAsStringSync());
      if (!_secretMarkers.hasMatch(code)) continue;
      if (_secretBearingScreens.contains(path)) continue;
      if (_allowlist.containsKey(path)) continue;
      unlisted.add(path);
    }
    expect(unlisted, isEmpty,
        reason: 'New file renders or handles secrets: wrap it in '
            'SecureScreen and add it to _secretBearingScreens, or allowlist '
            'it with a reason.');
  });
}
