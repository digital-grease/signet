import 'package:shared_preferences/shared_preferences.dart';
import 'package:signet/core/prefs/app_prefs.dart';

/// App preferences for widget tests, as an install that finished
/// onboarding and kept English words. Screens that read
/// `appPrefsProvider` (Home's one-time word-language notice, Settings,
/// bulk backup) need it overridden.
Future<AppPrefs> testPrefs([Map<String, Object> values = const {}]) async {
  SharedPreferences.setMockInitialValues(<String, Object>{
    'signet.onboarding_completed': true,
    'signet.word_language': 'en',
    ...values,
  });
  return AppPrefs.load();
}
