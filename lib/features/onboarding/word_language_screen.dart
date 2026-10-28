import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/crypto/wordlists.dart';
import '../../core/prefs/settings_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/fill_or_scroll.dart';
import '../../shared/widgets/word_language_options.dart';

/// First-run word-language picker (v0.5.0 plan Task 1.4), shown before
/// onboarding on a new install. It sets the default word language for new
/// contacts only; the interface language follows the phone. Preselected
/// from the device's language list when a word list exists for one of
/// them, else English, so the usual path is one tap.
class WordLanguageScreen extends ConsumerStatefulWidget {
  const WordLanguageScreen({super.key, this.deviceLanguageCodes});

  /// The device's preferred languages, most preferred first. Null reads
  /// them from the platform; tests pass their own.
  final List<String>? deviceLanguageCodes;

  @override
  ConsumerState<WordLanguageScreen> createState() =>
      _WordLanguageScreenState();
}

class _WordLanguageScreenState extends ConsumerState<WordLanguageScreen> {
  late WordList _selected;

  @override
  void initState() {
    super.initState();
    // The raw device list, not the resolved UI locale: French words are
    // offered on a French phone even when the UI has no French catalog.
    final codes = widget.deviceLanguageCodes ??
        <String>[
          for (final l in PlatformDispatcher.instance.locales) l.languageCode,
        ];
    _selected = WordList.suggestFor(codes) ?? WordList.english;
  }

  Future<void> _continue() async {
    await ref.read(defaultWordListProvider.notifier).set(_selected);
    if (!mounted) return;
    context.go('/onboarding');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final english =
        Localizations.localeOf(context).languageCode == WordList.english.id;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.commonAppTitle)),
      body: SafeArea(
        child: FillOrScroll(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Semantics(
                header: true,
                child: Text(
                  l10n.wordLanguageTitle,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              // Two-language title: the picker comes before anything else,
              // and English is the one language every list page shows.
              if (!english)
                Text(
                  'Word language',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              const SizedBox(height: 12),
              Text(
                l10n.wordLanguagePickerBody,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              WordLanguageOptions(
                selected: _selected,
                onChanged: (list) => setState(() => _selected = list),
              ),
              const Spacer(),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _continue,
                child: Text(l10n.onboardingContinueButton),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
