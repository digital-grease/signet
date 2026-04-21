import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Thin wrapper around SharedPreferences for non-secret app flags.
///
/// Anything sensitive lives in [SecureStore]; this is only for
/// preferences that aren't a compromise target (e.g. "has the user
/// seen onboarding"). Kept separate from [SecureStore] so consumers
/// don't confuse the two storage surfaces.
class AppPrefs {
  AppPrefs(this._prefs);

  static Future<AppPrefs> load() async {
    final prefs = await SharedPreferences.getInstance();
    return AppPrefs(prefs);
  }

  final SharedPreferences _prefs;

  static const String _kOnboardingCompleted = 'signet.onboarding_completed';
  static const String _kThemeMode = 'signet.theme_mode';

  bool get onboardingCompleted =>
      _prefs.getBool(_kOnboardingCompleted) ?? false;

  Future<void> setOnboardingCompleted(bool value) =>
      _prefs.setBool(_kOnboardingCompleted, value);

  /// Theme mode override. Defaults to [ThemeMode.system] so nothing changes
  /// for users who never touch the setting. Persisted as a wire-stable
  /// string ("system" / "light" / "dark") — safer than storing the enum
  /// index, which would silently shift if Flutter reorders the enum.
  ThemeMode get themeMode {
    final raw = _prefs.getString(_kThemeMode);
    return switch (raw) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> setThemeMode(ThemeMode mode) => _prefs.setString(
        _kThemeMode,
        switch (mode) {
          ThemeMode.light => 'light',
          ThemeMode.dark => 'dark',
          ThemeMode.system => 'system',
        },
      );
}
