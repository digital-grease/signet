import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'features/home/home_screen.dart';
import 'features/pairing/pair_confirm_screen.dart';
import 'features/pairing/pair_exchange_screen.dart';
import 'features/pairing/pair_start_screen.dart';
import 'features/verify/verify_screen.dart';

/// Root widget. Keeps `main.dart` tiny — all theming and routing live here.
///
/// Theming: Material 3 with a distinct seed. Light and dark variants
/// follow the system setting. Text scaling is explicitly _not_ capped,
/// so the OS-level "Large text" accessibility setting takes effect.
class SignetApp extends StatelessWidget {
  SignetApp({super.key});

  final GoRouter _router = GoRouter(
    initialLocation: '/',
    routes: <RouteBase>[
      GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
      GoRoute(path: '/verify', builder: (_, _) => const VerifyScreen()),
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
    const seed = Color(0xFF2B3F87);
    return MaterialApp.router(
      title: 'Signet',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        visualDensity: VisualDensity.comfortable,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        visualDensity: VisualDensity.comfortable,
      ),
      routerConfig: _router,
    );
  }
}
