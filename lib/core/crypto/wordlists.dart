// The word lists Signet ships, and the fold every typed or pasted word goes
// through before it is looked up in a list.
//
// A word is only ever a rendering of an 11-bit index: every list maps the
// same 2048 indices, so crypto code works on indices (or on their English
// rendering, the canonical form) and a list is a display and input choice:
// derivations produce indices and [WordList.render] spells them in the
// contact's list. See .devloop/spikes/word-language.md §1-2.
//
// Pure Dart, no Flutter imports.

import 'bip39_english_wordlist.dart';
import 'bip39_french_wordlist.dart';

class WordList {
  WordList._(this.id, this.languageTag, this.endonym, this.words, this._fold)
      : assert(words.length == size),
        _index = {
          for (var i = 0; i < words.length; i++) _fold(words[i])!: i,
        };

  static final WordList english =
      WordList._('en', 'en', 'English', bip39EnglishWordlist, _latinFold);
  static final WordList french =
      WordList._('fr', 'fr', 'Français', bip39FrenchWordlist, _latinFold);

  /// Every list this version can read, English first.
  static final List<WordList> shipped = [english, french];

  /// Words in every list: one per 11-bit index.
  static const int size = 2048;

  /// The first shipped list for one of [languageCodes] (BCP-47 primary
  /// language subtags, most preferred first, as the device lists them), or
  /// null when none has a list.
  static WordList? suggestFor(Iterable<String> languageCodes) {
    for (final code in languageCodes) {
      final list = byId(code.toLowerCase());
      if (list != null) return list;
    }
    return null;
  }

  /// The shipped list registered as [id], or null for an id this version
  /// does not have.
  static WordList? byId(String id) {
    for (final list in shipped) {
      if (list.id == id) return list;
    }
    return null;
  }

  /// Registered wordlist id: the `0x01` extension value in backups
  /// (docs/WIRE_FORMAT.md).
  final String id;

  /// The BCP-47 tag screen readers should read the words in, so TalkBack
  /// uses a French voice for French words on an English UI and the
  /// reverse. Not the same as [id]: a later list such as `zh-1` reads as
  /// `zh-CN`.
  final String languageTag;

  /// The language's own name for itself ("Français"), shown on pickers
  /// whatever the UI language, so a person finds their language by sight.
  final String endonym;

  /// The 2048 words, precomposed (NFC), as shown to users.
  final List<String> words;

  final Map<String, int> _index;

  final String? Function(String) _fold;

  String wordAt(int index) => words[index];

  /// [indices] spelled in this list, in order.
  List<String> render(Iterable<int> indices) =>
      [for (final i in indices) words[i]];

  /// [canonical], words of the English list (the canonical rendering
  /// crypto code passes around), spelled in this list. Throws [StateError]
  /// on a string that is not an English word: that is a caller bug, never
  /// user input.
  List<String> respell(List<String> canonical) => render([
        for (final w in canonical)
          english.indexOf(w) ??
              (throw StateError('respell takes English words only')),
      ]);

  /// The index of [input] in this list after [fold], or null.
  int? indexOf(String input) {
    final folded = fold(input);
    return folded == null ? null : _index[folded];
  }

  bool contains(String input) => indexOf(input) != null;

  /// The lookup form of a typed word under this list's fold, or null if it
  /// cannot be a word of this list. Each list has its own fold so a list
  /// in another script never changes how the Latin lists read input.
  String? fold(String input) => _fold(input);

  /// Precomposed Latin letters folded to their base letter. Covers the
  /// shipped lists' accents and the near misses a user might type instead
  /// (élêve for élève).
  static const Map<String, String> _baseLetter = {
    'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a', //
    'ç': 'c', //
    'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e', //
    'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i', //
    'ñ': 'n', //
    'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o', //
    'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u', //
    'ý': 'y', 'ÿ': 'y',
  };

  /// Zero-width, soft-hyphen and direction-mark characters, which a paste
  /// can carry invisibly inside or around a word.
  static final RegExp _formatChars =
      RegExp('[\u200B-\u200F\u2060\uFEFF\u00AD\u061C]');

  /// The combining marks the letters in [_baseLetter] decompose to (NFD):
  /// grave, acute, circumflex, tilde, diaeresis, ring, cedilla. Any other
  /// mark is kept, so the word is rejected, just as its precomposed form
  /// would be.
  static final RegExp _combiningMarks =
      RegExp('[\u0300\u0301\u0302\u0303\u0308\u030A\u0327]');

  static final RegExp _plainWord = RegExp(r'^[a-z]+$');

  /// The fold of the Latin lists: the lookup form of a typed word, or null
  /// if it cannot be a word of a Latin list. In order: locale-independent lowercase; drop format
  /// characters; fold precomposed accents; drop their combining marks;
  /// require a-z only (so fullwidth letters, look-alike scripts and
  /// anything with spaces, digits or hyphens are rejected). Dart's
  /// lowercase also maps a few compatibility letters onto a-z (the Kelvin
  /// sign to k, the Angstrom sign to å): harmless, since they reach the
  /// index of the word they look like.
  static String? _latinFold(String input) {
    final lower = input.toLowerCase().replaceAll(_formatChars, '');
    final buffer = StringBuffer();
    for (final rune in lower.runes) {
      final ch = String.fromCharCode(rune);
      buffer.write(_baseLetter[ch] ?? ch);
    }
    final folded = buffer.toString().replaceAll(_combiningMarks, '');
    return _plainWord.hasMatch(folded) ? folded : null;
  }
}
