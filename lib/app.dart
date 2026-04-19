import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/signet_theme.dart';
import 'features/home/home_screen.dart';
import 'features/inspect/binding_phrase_screen.dart';
import 'features/pairing/pair_confirm_screen.dart';
import 'features/pairing/pair_exchange_screen.dart';
import 'features/pairing/pair_start_screen.dart';
import 'features/verify/verify_screen.dart';

/// Root widget. Keeps `main.dart` tiny — all routing lives here; the theme
/// lives in `core/theme/signet_theme.dart`.
///
/// Theme mode follows the system setting. Text scaling is deliberately not
/// capped, so the OS-level "Large text" accessibility setting takes effect.
class SignetApp extends StatelessWidget {
  SignetApp({super.key});

  final GoRouter _router = GoRouter(
    initialLocation: '/',
    routes: <RouteBase>[
      GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
      GoRoute(path: '/verify', builder: (_, _) => const VerifyScreen()),
      GoRoute(
        path: '/inspect/binding',
        builder: (_, _) => const BindingPhraseScreen(),
      ),
      GoRoute(path: '/pair/start', builder: (_, _) => const PairStartScreen()),
      GoRoute(
        path: '/pair/exchange',
        builder: (_, _) => const PairExchangeScreen(),
      ),
      GoRoute(
        path: '/pair/confirm',
        builder: (_, _) => const PairConfirmScreen(),
      ),
    ],
  );

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
