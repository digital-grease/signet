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
import 'zh_input.dart';
import 'zh_wordlist.dart';

class WordList {
  WordList._(
    this.id,
    this._languageTag,
    this._endonym,
    this._words,
    this._fold, {
    int? Function(String input)? lookup,
    _Script? traditional,
  })  : assert(_words.length == size),
        _lookup = lookup,
        _traditionalScript = traditional,
        _index = lookup != null
            ? const <String, int>{}
            : {for (var i = 0; i < _words.length; i++) _fold(_words[i])!: i};

  static final WordList english =
      WordList._('en', 'en', 'English', bip39EnglishWordlist, _latinFold);
  static final WordList french =
      WordList._('fr', 'fr', 'Français', bip39FrenchWordlist, _latinFold);

  /// zh-1, Signet's Mandarin list (lib/core/crypto/zh_wordlist.dart),
  /// shown in simplified characters. Input by any accepted written form,
  /// by pinyin with the list's accent mergers, or by characters through
  /// the reading table, accepted only when exactly one entry matches
  /// ([ZhInput]).
  ///
  /// The script is a local display preference ([showTraditionalChinese]),
  /// never compared between phones: both scripts are the same entries,
  /// and input accepts either.
  static final WordList zh1 = WordList._(
    'zh-1',
    'zh-Hans-CN',
    '中文（普通话）',
    [for (final w in zhWordlist) w.simplified],
    ZhInput.fold,
    lookup: (input) => ZhInput.zh1.indexOf(input),
    traditional: (
      tag: 'zh-Hant-TW',
      endonym: '中文（國語）',
      words: [for (final w in zhWordlist) w.traditional],
    ),
  );

  /// Show zh-1 in traditional characters (Taiwan forms) instead of
  /// simplified: the phone's script setting (plan Task 3.3), set at start
  /// and when the setting changes. Display only: indices, lookup and
  /// everything on the wire are the same in both scripts.
  static bool showTraditionalChinese = false;

  /// Every list this version can read, English first.
  static final List<WordList> shipped = [english, french, zh1];

  /// Words in every list: one per 11-bit index.
  static const int size = 2048;

  /// The first shipped list for one of [languageCodes] (BCP-47 primary
  /// language subtags, most preferred first, as the device lists them), or
  /// null when none has a list.
  static WordList? suggestFor(Iterable<String> languageCodes) {
    for (final code in languageCodes) {
      for (final list in shipped) {
        if (list.languageTag.split('-').first == code.toLowerCase()) {
          return list;
        }
      }
    }
    return null;
  }

  /// The candidate words in pasted or typed [text]: its runs of Latin
  /// letters (and their combining marks), after removing invisible format
  /// characters. Every shipped list is Latin, so anything else separates:
  /// spaces, any punctuation including CJK and fullwidth (、，。), digits
  /// and list numbers, and Han or kana around the words ("密码词：abandon",
  /// "一、abandon"). v0.5.0 plan Task 0.5.
  static List<String> splitWords(String text) => [
        for (final m in _latinRun.allMatches(text.replaceAll(_formatChars, '')))
          m[0]!,
      ];

  static final RegExp _latinRun =
      RegExp(r'\p{Script=Latin}[\p{Script=Latin}\p{M}]*', unicode: true);

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
  /// reverse. Not the same as [id]: zh-1 reads as `zh-Hans-CN`, or
  /// `zh-Hant-TW` in traditional characters.
  String get languageTag =>
      _traditional ? _traditionalScript!.tag : _languageTag;

  /// The language's own name for itself ("Français"), shown on pickers
  /// whatever the UI language, so a person finds their language by sight.
  String get endonym => _traditional ? _traditionalScript!.endonym : _endonym;

  /// The 2048 words, precomposed (NFC), as shown to users.
  List<String> get words => _traditional ? _traditionalScript!.words : _words;

  final String _languageTag;
  final String _endonym;
  final List<String> _words;
  final _Script? _traditionalScript;

  bool get _traditional =>
      showTraditionalChinese && _traditionalScript != null;

  /// Whether this list has a second script (zh-1).
  bool get hasScripts => _traditionalScript != null;

  /// [endonym] and the words of [indices] in a given script, whatever
  /// [showTraditionalChinese] says (the picker offers both scripts).
  String endonymIn({required bool traditional}) =>
      traditional && hasScripts ? _traditionalScript!.endonym : _endonym;

  List<String> renderIn(Iterable<int> indices, {required bool traditional}) {
    final w = traditional && hasScripts ? _traditionalScript!.words : _words;
    return [for (final i in indices) w[i]];
  }

  /// The list a contact's PAKE words (backups, long-distance packages) are
  /// shown in: its own, except zh-1, whose PAKE words stay English in
  /// v0.5.0 (plan decision D4: read before write, as for French in v0.4.0).
  WordList get pakeWordList => _lookup != null ? english : this;

  /// The written forms in the other script, for the confirm screens that
  /// show both (zh-1 only; null for lists with one script).
  List<String>? get otherScriptWords {
    final t = _traditionalScript;
    if (t == null) return null;
    return _traditional ? _words : t.words;
  }

  final Map<String, int> _index;

  /// A list with its own reading of input (zh-1); null for the Latin lists,
  /// which look up their fold in [_index].
  final int? Function(String input)? _lookup;

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
    final lookup = _lookup;
    if (lookup != null) return lookup(input);
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

/// A list's second script: its locale tag, endonym and words.
typedef _Script = ({String tag, String endonym, List<String> words});
