import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signet/core/prefs/app_prefs.dart';
import 'package:signet/core/theme/signet_theme.dart';
import 'package:signet/features/onboarding/onboarding_screen.dart';

Future<Widget> _wrap({required AppPrefs prefs, VoidCallback? onDone}) async {
  final router = GoRouter(
    initialLocation: '/onboarding',
    routes: <RouteBase>[
      GoRoute(
        path: '/onboarding',
        builder: (_, _) => OnboardingScreen(prefs: prefs),
      ),
      GoRoute(
        path: '/',
        builder: (_, _) => Scaffold(
          body: Builder(builder: (context) {
            onDone?.call();
            return const Text('HOME_LANDED');
          }),
        ),
      ),
    ],
  );
  return MaterialApp.router(
    theme: signetTheme(dark: false),
    darkTheme: signetTheme(dark: true),
    routerConfig: router,
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('renders the first slide with SKIP affordance', (tester) async {
    final prefs = await AppPrefs.load();
    await tester.pumpWidget(await _wrap(prefs: prefs));
    await tester.pumpAndSettle();

    expect(find.text('BRIEFING // 01'), findsOneWidget);
    expect(find.text('Verify who is on the line.'), findsOneWidget);
    expect(find.text('CONTINUE'), findsOneWidget);
    expect(find.text('SKIP'), findsOneWidget);
  });

  testWidgets(
    'CONTINUE advances through slides, last slide shows GOT IT',
    (tester) async {
      final prefs = await AppPrefs.load();
      await tester.pumpWidget(await _wrap(prefs: prefs));
      await tester.pumpAndSettle();

      await tester.tap(find.text('CONTINUE'));
      await tester.pumpAndSettle();
      expect(find.text('BRIEFING // 02'), findsOneWidget);

      await tester.tap(find.text('CONTINUE'));
      await tester.pumpAndSettle();
      expect(find.text('BRIEFING // 03'), findsOneWidget);
      expect(find.text('GOT IT'), findsOneWidget);
      // SKIP label flips to DONE on the final slide.
      expect(find.text('DONE'), findsOneWidget);
      expect(find.text('SKIP'), findsNothing);
    },
  );

  testWidgets(
    'GOT IT on last slide persists completion and navigates to home',
    (tester) async {
      final prefs = await AppPrefs.load();
      await tester.pumpWidget(await _wrap(prefs: prefs));
      await tester.pumpAndSettle();

      await tester.tap(find.text('CONTINUE'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CONTINUE'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('GOT IT'));
      await tester.pumpAndSettle();

      expect(find.text('HOME_LANDED'), findsOneWidget);
      expect(prefs.onboardingCompleted, isTrue);
    },
  );

  testWidgets(
    'SKIP on the first slide also persists completion and navigates home',
    (tester) async {
      final prefs = await AppPrefs.load();
      await tester.pumpWidget(await _wrap(prefs: prefs));
      await tester.pumpAndSettle();

      await tester.tap(find.text('SKIP'));
      await tester.pumpAndSettle();

      expect(find.text('HOME_LANDED'), findsOneWidget);
      expect(prefs.onboardingCompleted, isTrue);
    },
  );
}
