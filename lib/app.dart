import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/prefs/app_prefs.dart';
import 'core/theme/signet_theme.dart';
import 'features/home/home_screen.dart';
import 'features/inspect/backup_export_screen.dart';
import 'features/inspect/backup_import_screen.dart';
import 'features/inspect/binding_phrase_screen.dart';
import 'features/inspect/cr_grid_screen.dart';
import 'features/liveness/liveness_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/pairing/pair_complete_screen.dart';
import 'features/pairing/pair_confirm_screen.dart';
import 'features/pairing/pair_exchange_screen.dart';
import 'features/pairing/pair_start_screen.dart';
import 'features/pairing/pair_transport_in_screen.dart';
import 'features/pairing/pair_transport_out_screen.dart';
import 'features/verify/verify_screen.dart';

/// Root widget. Keeps `main.dart` tiny — all routing lives here; the theme
/// lives in `core/theme/signet_theme.dart`.
///
/// Theme mode follows the system setting. Text scaling is deliberately not
/// capped, so the OS-level "Large text" accessibility setting takes effect.
///
/// First-run: if `prefs.onboardingCompleted` is false, the router starts
/// at `/onboarding` instead of `/`. Users can re-trigger onboarding via
/// the Home AppBar overflow.
class SignetApp extends StatelessWidget {
  SignetApp({super.key, required this.prefs})
      : _router = GoRouter(
          initialLocation: prefs.onboardingCompleted ? '/' : '/onboarding',
          routes: <RouteBase>[
            GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
            GoRoute(
              path: '/onboarding',
              builder: (_, _) => OnboardingScreen(prefs: prefs),
            ),
            GoRoute(
              path: '/verify/:id',
              builder: (_, state) => VerifyScreen(
                relationshipId: state.pathParameters['id']!,
              ),
            ),
            GoRoute(
              path: '/inspect/binding',
              builder: (_, _) => const BindingPhraseScreen(),
            ),
            GoRoute(
              path: '/inspect/export/:id',
              builder: (_, state) => BackupExportScreen(
                relationshipId: state.pathParameters['id']!,
              ),
            ),
            GoRoute(
              path: '/inspect/import',
              builder: (_, _) => const BackupImportScreen(),
            ),
            GoRoute(
              path: '/liveness/:id',
              builder: (_, state) => LivenessScreen(
                relationshipId: state.pathParameters['id']!,
              ),
            ),
            GoRoute(
              path: '/inspect/cr-grid/:id',
              builder: (_, state) => CrGridScreen(
                relationshipId: state.pathParameters['id']!,
              ),
            ),
            GoRoute(
              path: '/pair/start',
              builder: (_, _) => const PairStartScreen(),
            ),
            GoRoute(
              path: '/pair/exchange',
              builder: (_, _) => const PairExchangeScreen(),
            ),
            GoRoute(
              path: '/pair/confirm',
              builder: (_, _) => const PairConfirmScreen(),
            ),
            GoRoute(
              path: '/pair/complete/:id',
              builder: (_, state) => PairCompleteScreen(
                relationshipId: state.pathParameters['id']!,
              ),
            ),
            GoRoute(
              path: '/pair/transport-in',
              builder: (_, _) => const PairTransportInScreen(),
            ),
            GoRoute(
              path: '/pair/transport-out',
              builder: (_, _) => const PairTransportOutScreen(),
            ),
          ],
        );

  final AppPrefs prefs;
  final GoRouter _router;

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Signet',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: signetTheme(dark: false),
      darkTheme: signetTheme(dark: true),
      routerConfig: _router,
    );
  }
}
