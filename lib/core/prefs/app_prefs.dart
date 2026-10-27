import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../crypto/wordlists.dart';

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
  static const String _kWordLanguage = 'signet.word_language';
  static const String _kWordLanguageNotice = 'signet.word_language_notice';

  bool get onboardingCompleted =>
      _prefs.getBool(_kOnboardingCompleted) ?? false;

  Future<void> setOnboardingCompleted(bool value) =>
      _prefs.setBool(_kOnboardingCompleted, value);

  /// The default word-list id for new contacts ([WordList.id]), or null
  /// before the first-run picker has run. Existing contacts never follow
  /// it; each keeps its own `Relationship.wordLanguage`.
  String? get wordLanguage => _prefs.getString(_kWordLanguage);

  Future<void> setWordLanguage(String id) =>
      _prefs.setString(_kWordLanguage, id);

  /// The list [wordLanguage] names; English when unset or unknown.
  WordList get defaultWordList =>
      WordList.byId(wordLanguage ?? '') ?? WordList.english;

  /// Upgrade from v0.4.0 or earlier: an install that finished onboarding
  /// before word languages existed is set to English with no prompt. When
  /// the device prefers a language that has a list ([deviceLanguageCodes],
  /// most preferred first), it is remembered for a one-time Home notice
  /// ([wordLanguageNotice]). Does nothing on a new install (the picker
  /// asks) or once a default is stored.
  Future<void> settleWordLanguageForUpgrade(
      Iterable<String> deviceLanguageCodes) async {
    if (wordLanguage != null || !onboardingCompleted) return;
    await setWordLanguage(WordList.english.id);
    final suggested = WordList.suggestFor(deviceLanguageCodes);
    if (suggested != null && suggested != WordList.english) {
      await _prefs.setString(_kWordLanguageNotice, suggested.id);
    }
  }

  /// The list a one-time Home notice offers after an upgrade, or null.
  WordList? get wordLanguageNotice {
    final id = _prefs.getString(_kWordLanguageNotice);
    return id == null ? null : WordList.byId(id);
  }

  Future<void> dismissWordLanguageNotice() =>
      _prefs.remove(_kWordLanguageNotice);

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
