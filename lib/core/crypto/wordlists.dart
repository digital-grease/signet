// The BIP-39 word lists Signet ships, and the fold every typed or pasted
// word goes through before it is looked up.
//
// A word is only ever a rendering of an 11-bit index: every list maps the
// same 2048 indices, so crypto code works on indices (or on their English
// rendering, the canonical form) and a list is a display and input choice.
// See .devloop/spikes/word-language.md §1.
//
// Pure Dart, no Flutter imports.

import 'bip39_english_wordlist.dart';
import 'bip39_french_wordlist.dart';

class WordList {
  WordList._(this.id, this.words)
      : _index = {
          for (var i = 0; i < words.length; i++) fold(words[i])!: i,
        };

  static final WordList english = WordList._('en', bip39EnglishWordlist);
  static final WordList french = WordList._('fr', bip39FrenchWordlist);

  /// Every list this version can read, English first.
  static final List<WordList> shipped = [english, french];

  /// Registered wordlist id (the `0x01` extension value in a later release).
  final String id;

  /// The 2048 words, precomposed (NFC), as shown to users.
  final List<String> words;

  final Map<String, int> _index;

  String wordAt(int index) => words[index];

  /// The index of [input] in this list after [fold], or null.
  int? indexOf(String input) {
    final folded = fold(input);
    return folded == null ? null : _index[folded];
  }

  bool contains(String input) => indexOf(input) != null;

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

  /// The lookup form of a typed word, or null if it cannot be a word of any
  /// shipped list. In order: locale-independent lowercase; drop format
  /// characters; fold precomposed accents; drop their combining marks;
  /// require a-z only (so fullwidth letters, look-alike scripts and
  /// anything with spaces, digits or hyphens are rejected). Dart's
  /// lowercase also maps a few compatibility letters onto a-z (the Kelvin
  /// sign to k, the Angstrom sign to å): harmless, since they reach the
  /// index of the word they look like.
  static String? fold(String input) {
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
