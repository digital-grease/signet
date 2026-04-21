import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_prefs.dart';

/// Holds the singleton [AppPrefs]. Seeded at app boot from `main.dart` via
/// `ProviderScope(overrides: [appPrefsProvider.overrideWithValue(prefs)])`
/// so every screen reads the same instance.
final Provider<AppPrefs> appPrefsProvider = Provider<AppPrefs>(
  (Ref ref) => throw UnimplementedError(
    'appPrefsProvider must be overridden at ProviderScope root '
    '(see main.dart).',
  ),
);

/// Reactive wrapper around [AppPrefs.themeMode]. Watch to drive
/// `MaterialApp.themeMode`; mutate via `ref.read(themeModeProvider.notifier)
/// .set(mode)` from the settings screen. Writes through to
/// SharedPreferences — the value survives restarts.
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ref.read(appPrefsProvider).themeMode;

  Future<void> set(ThemeMode mode) async {
    if (state == mode) return;
    state = mode;
    await ref.read(appPrefsProvider).setThemeMode(mode);
  }
}

final NotifierProvider<ThemeModeNotifier, ThemeMode> themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);
