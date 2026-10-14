import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signet/core/prefs/app_prefs.dart';
import 'package:signet/core/prefs/settings_controller.dart';
import 'package:signet/core/providers.dart';
import 'package:signet/features/settings/settings_screen.dart';
import 'package:signet/l10n/app_localizations.dart';

import '../support/fake_secure_store.dart';

void main() {
  // The theme options are drawn as radio icons; TalkBack has to hear which
  // one is selected, not just three plain buttons.
  testWidgets('theme options announce a radio group and the selected option',
      (tester) async {
    final semantics = tester.ensureSemantics();
    SharedPreferences.setMockInitialValues(<String, Object>{
      'signet.onboarding_completed': true,
      'signet.theme_mode': 'light',
    });
    final prefs = await AppPrefs.load();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appPrefsProvider.overrideWithValue(prefs),
          secureStoreProvider.overrideWithValue(FakeSecureStore()),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getSemantics(find.text('LIGHT')),
      isSemantics(
        hasCheckedState: true,
        isChecked: true,
        isInMutuallyExclusiveGroup: true,
        hasTapAction: true,
      ),
    );
    for (final other in ['SYSTEM', 'DARK']) {
      expect(
        tester.getSemantics(find.text(other)),
        isSemantics(
          hasCheckedState: true,
          isChecked: false,
          isInMutuallyExclusiveGroup: true,
          hasTapAction: true,
        ),
      );
    }

    await tester.tap(find.text('DARK'));
    await tester.pumpAndSettle();
    expect(
      tester.getSemantics(find.text('DARK')),
      isSemantics(hasCheckedState: true, isChecked: true),
    );
    expect(
      tester.getSemantics(find.text('LIGHT')),
      isSemantics(hasCheckedState: true, isChecked: false),
    );
    semantics.dispose();
  });
}
