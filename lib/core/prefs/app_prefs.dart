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

  bool get onboardingCompleted =>
      _prefs.getBool(_kOnboardingCompleted) ?? false;

  Future<void> setOnboardingCompleted(bool value) =>
      _prefs.setBool(_kOnboardingCompleted, value);
}
