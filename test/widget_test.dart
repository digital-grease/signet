import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signet/app.dart';
import 'package:signet/core/prefs/app_prefs.dart';
import 'package:signet/core/prefs/settings_controller.dart';
import 'package:signet/core/providers.dart';

import 'support/fake_secure_store.dart';

void main() {
  testWidgets('App boots and lands on the home screen', (tester) async {
    // Pretend the user has already finished onboarding — the smoke test
    // is about the home landing, not the onboarding route (which has
    // its own dedicated test file).
    SharedPreferences.setMockInitialValues(<String, Object>{
      'signet.onboarding_completed': true,
    });
    final prefs = await AppPrefs.load();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appPrefsProvider.overrideWithValue(prefs),
          secureStoreProvider.overrideWithValue(FakeSecureStore()),
        ],
        child: SignetApp(prefs: prefs),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('SIGNET'), findsOneWidget);
    expect(find.text('Nothing paired yet.'), findsOneWidget);
  });
}
