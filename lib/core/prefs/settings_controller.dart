import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../crypto/wordlists.dart';
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

/// Reactive wrapper around [AppPrefs.defaultWordList]: the word language
/// new contacts start with (first-run picker, Settings). Existing contacts
/// keep their own.
class DefaultWordListNotifier extends Notifier<WordList> {
  @override
  WordList build() => ref.read(appPrefsProvider).defaultWordList;

  Future<void> set(WordList list) async {
    state = list;
    await ref.read(appPrefsProvider).setWordLanguage(list.id);
    // The upgrade notice asks for exactly this; once done it is stale.
    if (ref.read(wordLanguageNoticeProvider) == list) {
      await ref.read(wordLanguageNoticeProvider.notifier).dismiss();
    }
  }
}

final NotifierProvider<DefaultWordListNotifier, WordList>
    defaultWordListProvider =
    NotifierProvider<DefaultWordListNotifier, WordList>(
        DefaultWordListNotifier.new);

/// The one-time Home notice after an upgrade ([AppPrefs.wordLanguageNotice]):
/// the list the device language suggests, until dismissed.
class WordLanguageNoticeNotifier extends Notifier<WordList?> {
  @override
  WordList? build() => ref.read(appPrefsProvider).wordLanguageNotice;

  Future<void> dismiss() async {
    state = null;
    await ref.read(appPrefsProvider).dismissWordLanguageNotice();
  }
}

final NotifierProvider<WordLanguageNoticeNotifier, WordList?>
    wordLanguageNoticeProvider =
    NotifierProvider<WordLanguageNoticeNotifier, WordList?>(
        WordLanguageNoticeNotifier.new);
