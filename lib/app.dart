import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/prefs/app_prefs.dart';
import 'core/prefs/settings_controller.dart';
import 'core/theme/signet_theme.dart';
import 'features/about/about_screen.dart';
import 'features/help/faq_screen.dart';
import 'features/home/home_screen.dart';
import 'core/crypto/transport_package.dart';
import 'features/inspect/backup_export_screen.dart';
import 'features/inspect/backup_import_screen.dart';
import 'features/inspect/binding_phrase_screen.dart';
import 'features/inspect/bulk_backup_export_screen.dart';
import 'features/inspect/bulk_backup_import_screen.dart';
import 'features/inspect/cr_grid_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/pairing/pair_complete_screen.dart';
import 'features/pairing/pair_confirm_screen.dart';
import 'features/pairing/pair_exchange_screen.dart';
import 'features/pairing/pair_start_screen.dart';
import 'features/pairing/pair_transport_in_screen.dart';
import 'features/pairing/pair_transport_out_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/verify/verify_screen.dart';

/// Root widget. Keeps `main.dart` tiny — all routing lives here; the theme
/// lives in `core/theme/signet_theme.dart`.
///
/// Theme mode follows `themeModeProvider`, which is seeded from
/// [AppPrefs.themeMode] and defaults to [ThemeMode.system]. Text scaling is
/// deliberately not capped, so the OS-level "Large text" accessibility
/// setting takes effect.
///
/// First-run: if `prefs.onboardingCompleted` is false, the router starts
/// at `/onboarding` instead of `/`. Users can re-trigger onboarding via
/// the Settings screen or the Home AppBar overflow.
class SignetApp extends ConsumerWidget {
  SignetApp({super.key, required this.prefs})
      : _router = GoRouter(
          initialLocation: prefs.onboardingCompleted ? '/' : '/onboarding',
          routes: <RouteBase>[
            GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
            GoRoute(path: '/about', builder: (_, _) => const AboutScreen()),
            GoRoute(path: '/faq', builder: (_, _) => const FaqScreen()),
            GoRoute(
              path: '/settings',
              builder: (_, _) => const SettingsScreen(),
            ),
            GoRoute(
              path: '/onboarding',
              builder: (_, _) => OnboardingScreen(prefs: prefs),
            ),
            GoRoute(
              path: '/verify/:id',
              builder: (_, state) => VerifyScreen(
                relationshipId: state.pathParameters['id']!,
                // `?video=1` auto-enables the verify-screen video-mode
                // toggle. Set by the retired `/liveness/:id` route's
                // redirect and by the home-screen "Verify (video call)"
                // menu item. See .devloop/plan.md Phase 14 Task 2.4.
                initialVideoMode:
                    state.uri.queryParameters['video'] == '1',
              ),
            ),
            GoRoute(
              path: '/inspect/binding/:id',
              builder: (_, state) => BindingPhraseScreen(
                relationshipId: state.pathParameters['id']!,
              ),
            ),
            GoRoute(
              path: '/inspect/export/:id',
              builder: (_, state) => BackupExportScreen(
                relationshipId: state.pathParameters['id']!,
              ),
            ),
            GoRoute(
              path: '/inspect/export-bulk',
              builder: (_, _) => const BulkBackupExportScreen(),
            ),
            GoRoute(
              path: '/inspect/import',
              builder: (_, _) => const BackupImportScreen(),
            ),
            GoRoute(
              path: '/inspect/import-bulk',
              builder: (_, state) {
                final decoded = state.extra;
                // If someone deep-links here without a decoded BLK payload,
                // punt them to the paste-and-dispatch screen.
                if (decoded is! BlkPackage) {
                  return const BackupImportScreen();
                }
                return BulkBackupImportScreen(decoded: decoded);
              },
            ),
            GoRoute(
              // Legacy route retired in Phase 14: the standalone liveness
              // screen was folded into the verify flow's "video mode"
              // toggle (secret-derived action check). Bookmarks /
              // home-screen shortcuts that still point at `/liveness/:id`
              // land on the verify screen with video mode pre-enabled.
              // Remove this redirect one release after Phase 14 ships.
              path: '/liveness/:id',
              redirect: (_, state) {
                final id = state.pathParameters['id'];
                return id == null ? '/' : '/verify/$id?video=1';
              },
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
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: 'Signet',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: signetTheme(dark: false),
      darkTheme: signetTheme(dark: true),
      routerConfig: _router,
    );
  }
}
