// First-run screens at large text (plan Task 5.1): no overflow, and the
// buttons can always be reached. Also the two-step backup export.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signet/core/prefs/app_prefs.dart';
import 'package:signet/core/prefs/settings_controller.dart';
import 'package:signet/core/providers.dart';
import 'package:signet/features/home/home_screen.dart';
import 'package:signet/features/inspect/two_step_backup.dart';
import 'package:signet/features/onboarding/onboarding_screen.dart';
import 'package:signet/features/pairing/pair_complete_screen.dart';
import 'package:signet/features/pairing/pair_confirm_screen.dart';
import 'package:signet/features/pairing/pair_start_screen.dart';
import 'package:signet/features/pairing/pairing_controller.dart';
import 'dart:typed_data';
import 'package:signet/l10n/app_localizations.dart';

import '../support/fake_secure_store.dart';

const _cases = <(Size, double)>[
  (Size(360, 640), 1.3),
  (Size(412, 915), 2.0),
  (Size(393, 852), 1.5),
];

void main() {
  Future<void> setScreen(WidgetTester tester, Size size, double scale) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }

  Future<void> reach(WidgetTester tester, String text) async {
    await tester.scrollUntilVisible(find.text(text), 100,
        scrollable: find.byType(Scrollable).first);
    expect(find.text(text).hitTestable(), findsOneWidget, reason: text);
  }

  for (final (size, scale) in _cases) {
    final tag = '${size.width.toInt()}x${size.height.toInt()} @${scale}x';

    testWidgets('empty Home, $tag', (tester) async {
      await setScreen(tester, size, scale);
      SharedPreferences.setMockInitialValues(<String, Object>{
        'signet.onboarding_completed': true,
      });
      final prefs = await AppPrefs.load();
      final router = GoRouter(routes: <RouteBase>[
        GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
      ]);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          appPrefsProvider.overrideWithValue(prefs),
          secureStoreProvider.overrideWithValue(FakeSecureStore()),
        ],
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          routerConfig: router,
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final l10n = lookupAppLocalizations(const Locale('en'));
      await reach(tester, l10n.homeEmptyPairContactButton);
      await reach(tester, l10n.homeEmptyRestoreBackupButton);
      expect(tester.takeException(), isNull);
    });

    testWidgets('onboarding slides, $tag', (tester) async {
      await setScreen(tester, size, scale);
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await AppPrefs.load();
      final router = GoRouter(
        initialLocation: '/onboarding',
        routes: <RouteBase>[
          GoRoute(
            path: '/onboarding',
            builder: (_, _) => OnboardingScreen(prefs: prefs),
          ),
          GoRoute(path: '/', builder: (_, _) => const Text('HOME')),
        ],
      );
      await tester.pumpWidget(MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        routerConfig: router,
      ));
      await tester.pumpAndSettle();
      for (var i = 0; i < 8 && find.text('CONTINUE').evaluate().isNotEmpty; i++) {
        expect(tester.takeException(), isNull, reason: 'slide $i');
        expect(find.text('CONTINUE').hitTestable(), findsOneWidget);
        await tester.tap(find.text('CONTINUE'));
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('two-step backup export, $tag', (tester) async {
      await setScreen(tester, size, scale);
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: SingleChildScrollView(
            child: TwoStepBackupSaver(
              wire: 'signet:tp1:AQIDBAUGBwgJCgsMDQ4PEA',
              pakeWords: const <String>[
                'abandon', 'ability', 'able', 'about',
                'above', 'absent', 'absorb', 'abstract',
              ],
              fingerprint: '123 456',
              generatedAt: DateTime.utc(2026, 10, 8),
              onDone: () {},
              shareFile: ({required String fileName, required String text}) async =>
                  true,
              sweep: () async {},
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      await reach(tester, 'I saved it another way');
      await tester.tap(find.text('I saved it another way'));
      await tester.pumpAndSettle();
      await reach(tester, 'I wrote them on paper');
      await reach(tester, "I'VE SAVED BOTH");
      expect(tester.takeException(), isNull);
    });
  }

  // Phase 5 review: the pairing screens had the same overflow.
  for (final (size, scale) in _cases) {
    final tag = '${size.width.toInt()}x${size.height.toInt()} @${scale}x';

    Widget routed(String location, Widget screen,
            {ProviderContainer? container}) =>
        UncontrolledProviderScope(
          container: container ??
              ProviderContainer(overrides: [
                secureStoreProvider.overrideWithValue(FakeSecureStore()),
              ]),
          child: MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            routerConfig: GoRouter(
              initialLocation: location,
              routes: <RouteBase>[
                GoRoute(path: location, builder: (_, _) => screen),
                GoRoute(path: '/', builder: (_, _) => const Text('HOME')),
              ],
            ),
          ),
        );

    testWidgets('pair start, $tag', (tester) async {
      await setScreen(tester, size, scale);
      await tester.pumpWidget(routed('/pair/start', const PairStartScreen()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await reach(tester, 'Continue');
    });

    testWidgets('pair complete, $tag', (tester) async {
      await setScreen(tester, size, scale);
      await tester.pumpWidget(routed(
          '/pair/complete/x', const PairCompleteScreen(relationshipId: 'x')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await reach(tester, 'SKIP — DO IT LATER');
    });

    testWidgets('pair confirm, $tag', (tester) async {
      await setScreen(tester, size, scale);
      final container = ProviderContainer(overrides: [
        secureStoreProvider.overrideWithValue(FakeSecureStore()),
      ]);
      addTearDown(container.dispose);
      final ctrl = container.read(pairingControllerProvider.notifier);
      ctrl.setLabel('Mom');
      await ctrl.ensureOurKeyPair();
      await ctrl.markQrShown();
      await ctrl.recordTheirPublicKey(Uint8List.fromList(List.filled(32, 2)));
      await tester.pumpWidget(routed('/pair/confirm', const PairConfirmScreen(),
          container: container));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await reach(tester, 'It matches');
    });
  }

  testWidgets('pair start with the keyboard up at normal text, 360x640',
      (tester) async {
    await setScreen(tester, const Size(360, 640), 1.0);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: ProviderContainer(overrides: [
        secureStoreProvider.overrideWithValue(FakeSecureStore()),
      ]),
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: PairStartScreen(),
      ),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await reach(tester, 'Continue');
  });
}
