// Reading zh-1 input (v0.5.0 plan Task 3.1; spike
// .devloop/spikes/chinese-words.md §2 and §4).
//
// An input names an entry by an exact written form (simplified, Taiwan
// traditional or another accepted form), by Latin pinyin (tone marks, tone
// digits or none; spaced, apostrophes or unspaced; with the accent mergers
// the list was built against), or by characters read through the bundled
// reading table. Whatever the route, an input counts only when exactly one
// entry matches, so no input ever names two entries (requirement 3) and
// each word keeps its 11 bits.
//
// The mergers are a port of tool/zh_wordlist/sound.py `classes()`, which
// the generator used to make every entry's sounds disjoint from every
// other's. Pure Dart, no Flutter imports.

import 'zh_reading_table.dart';
import 'zh_wordlist.dart';

class ZhInput {
  ZhInput._(this._list) {
    for (var i = 0; i < _list.length; i++) {
      final w = _list[i];
      for (final form in <String>{w.simplified, w.traditional, ...w.otherForms}) {
        _forms[form] = i;
      }
      for (final reading in w.readings) {
        final syllables = reading.split(' ');
        _syllables.addAll(syllables);
        for (final key in _keysOf(syllables)) {
          (_byKey[key] ??= <int>{}).add(i);
        }
      }
    }
    for (final line in zhReadingTable.split('\n')) {
      final tab = line.indexOf('\t');
      final syllable = line.substring(0, tab);
      _syllables.add(syllable);
      for (final rune in line.substring(tab + 1).runes) {
        _charReading[rune] = syllable;
      }
    }
  }

  /// The matcher for the frozen zh-1 list, built on first use.
  static final ZhInput zh1 = ZhInput._(zhWordlist);

  final List<ZhWord> _list;
  final Map<String, int> _forms = <String, int>{};
  final Map<String, Set<int>> _byKey = <String, Set<int>>{};
  final Set<String> _syllables = <String>{};
  final Map<int, String> _charReading = <int, String>{};

  /// The one entry [input] names, or null when it names none or more than
  /// one.
  int? indexOf(String input) {
    final hits = candidates(input);
    return hits.length == 1 ? hits.single : null;
  }

  /// Every entry [input] could name. [indexOf] accepts only a single one;
  /// visible for the exhaustive requirement-3 tests.
  Set<int> candidates(String input) {
    final text = _clean(input);
    if (text.isEmpty) return const <int>{};
    final exact = _forms[text];
    if (exact != null) return <int>{exact};
    final runes = text.runes.toList();
    final han = runes.where(_isHan).length;
    if (han == runes.length) return _byCharacters(runes);
    if (han > 0) return const <int>{}; // Latin and Han mixed in one slot
    return _byLatin(text);
  }

  /// The lookup form of a typed word: format characters, variation
  /// selectors and whitespace removed, compatibility ideographs unified,
  /// Latin lowercased with fullwidth narrowed. Null when nothing is left.
  static String? fold(String input) {
    final text = _clean(input);
    return text.isEmpty ? null : text;
  }

  // ------------------------------------------------------------------

  static String _clean(String input) {
    final out = StringBuffer();
    for (var rune in input.runes) {
      if (_isFormatOrSelector(rune)) continue;
      if (rune >= 0xFF01 && rune <= 0xFF5E) rune -= 0xFEE0; // fullwidth ASCII
      if (rune == 0x3000) rune = 0x20; // ideographic space
      final unified = zhCompatibilityIdeographs[rune];
      if (unified != null) rune = unified;
      out.writeCharCode(rune);
    }
    // Whitespace only separates syllables, and only Latin needs that: keep
    // it for Latin, drop it between characters ("苹 果").
    final s = out.toString().trim().toLowerCase();
    return s.runes.any(_isHan) ? s.replaceAll(RegExp(r'\s+'), '') : s;
  }

  static bool _isFormatOrSelector(int r) =>
      (r >= 0x200B && r <= 0x200F) ||
      r == 0x2060 ||
      r == 0xFEFF ||
      r == 0x00AD ||
      (r >= 0xFE00 && r <= 0xFE0F) ||
      (r >= 0xE0100 && r <= 0xE01EF);

  static bool _isHan(int r) =>
      (r >= 0x3400 && r <= 0x4DBF) ||
      (r >= 0x4E00 && r <= 0x9FFF) ||
      (r >= 0xF900 && r <= 0xFAFF) ||
      (r >= 0x20000 && r <= 0x3134F) ||
      r == 0x3007;

  Set<int> _byCharacters(List<int> runes) {
    if (runes.length < 2 || runes.length > 3) return const <int>{};
    final syllables = <String>[];
    for (final r in runes) {
      final s = _charReading[r];
      if (s == null) return const <int>{};
      syllables.add(s);
    }
    return _entriesFor(<List<String>>[syllables]);
  }

  Set<int> _byLatin(String text) {
    final chunks = _latinChunks(text);
    if (chunks == null || chunks.isEmpty) return const <int>{};
    final readings = <List<String>>[];
    void walk(int chunk, List<String> sofar) {
      if (sofar.length > 3) return;
      if (chunk == chunks.length) {
        if (sofar.length >= 2) readings.add(List<String>.of(sofar));
        return;
      }
      for (final cut in _splits(chunks[chunk])) {
        walk(chunk + 1, <String>[...sofar, ...cut]);
      }
    }

    walk(0, <String>[]);
    return _entriesFor(readings);
  }

  /// [text] cut at typed boundaries (spaces, apostrophes, hyphens, tone
  /// digits) into letter runs, with tone marks removed and ü written v.
  /// Null on a character that cannot be pinyin.
  static List<String>? _latinChunks(String text) {
    final chunks = <String>[];
    final current = StringBuffer();
    void close() {
      if (current.isNotEmpty) chunks.add(current.toString());
      current.clear();
    }

    final runes = text.runes.toList();
    for (var k = 0; k < runes.length; k++) {
      final r = runes[k];
      final ch = String.fromCharCode(r);
      final base = _toneless[ch];
      if (base != null) {
        current.write(base);
      } else if (r >= 0x61 && r <= 0x7A) {
        // "u:" is ü.
        if (r == 0x75 && k + 1 < runes.length && runes[k + 1] == 0x3A) {
          current.write('v');
          k++;
        } else {
          current.write(ch);
        }
      } else if (r == 0x0308) {
        // A combining diaeresis after u (NFD ü).
        final s = current.toString();
        if (!s.endsWith('u')) return null;
        current
          ..clear()
          ..write('${s.substring(0, s.length - 1)}v');
      } else if (r >= 0x0300 && r <= 0x036F) {
        continue; // NFD tone mark
      } else if ((r >= 0x31 && r <= 0x35) ||
          r == 0x20 ||
          r == 0x27 ||
          r == 0x2019 ||
          r == 0x2018 ||
          r == 0x2D) {
        close(); // tone digit or typed boundary
      } else {
        return null;
      }
    }
    close();
    return chunks;
  }

  /// Every way to cut a letter run into syllables of the inventory.
  Iterable<List<String>> _splits(String s) sync* {
    if (s.isEmpty) {
      yield const <String>[];
      return;
    }
    for (var k = 1; k <= s.length && k <= 6; k++) {
      final head = s.substring(0, k);
      if (!_syllables.contains(head)) continue;
      for (final rest in _splits(s.substring(k))) {
        if (rest.length >= 3) continue;
        yield <String>[head, ...rest];
      }
    }
  }

  Set<int> _entriesFor(List<List<String>> readings) {
    final hits = <int>{};
    for (final r in readings) {
      for (final key in _keysOf(r)) {
        final found = _byKey[key];
        if (found != null) hits.addAll(found);
      }
    }
    return hits;
  }

  /// The merged keys of one reading: every combination of its syllables'
  /// classes, joined by "/" (sound.py `keyset`).
  static Iterable<String> _keysOf(List<String> syllables) sync* {
    final classes = [for (final s in syllables) ZhSound.classes(s)];
    Iterable<String> combine(int k) sync* {
      if (k == classes.length) {
        yield '';
        return;
      }
      for (final c in classes[k]) {
        for (final rest in combine(k + 1)) {
          yield rest.isEmpty ? c : '$c/$rest';
        }
      }
    }

    yield* combine(0);
  }

  /// Tone-marked vowels (precomposed) to their toneless letter, ü as v.
  static const Map<String, String> _toneless = <String, String>{
    'ā': 'a', 'á': 'a', 'ǎ': 'a', 'à': 'a', //
    'ē': 'e', 'é': 'e', 'ě': 'e', 'è': 'e', 'ê': 'e', //
    'ī': 'i', 'í': 'i', 'ǐ': 'i', 'ì': 'i', //
    'ō': 'o', 'ó': 'o', 'ǒ': 'o', 'ò': 'o', //
    'ū': 'u', 'ú': 'u', 'ǔ': 'u', 'ù': 'u', //
    'ü': 'v', 'ǖ': 'v', 'ǘ': 'v', 'ǚ': 'v', 'ǜ': 'v', //
    'ń': 'n', 'ň': 'n', 'ǹ': 'n', 'ḿ': 'm',
  };
}

/// When two toneless syllables can be heard as the same: a port of
/// tool/zh_wordlist/sound.py `classes()`. Each syllable maps to a set of
/// canonical forms, because a merger can map one syllable two ways.
class ZhSound {
  const ZhSound._();

  static const List<String> _initials = <String>[
    'zh', 'ch', 'sh', 'b', 'p', 'm', 'f', 'd', 't', 'n', 'l', 'g', 'k', //
    'h', 'j', 'q', 'x', 'r', 'z', 'c', 's', 'y', 'w',
  ];

  /// Southern hu+V heard as f+V (fei/hui, fan/huan, fen/hun, fu/hu).
  static const Map<String, String> _huToF = <String, String>{
    'u': 'u', 'ui': 'ei', 'un': 'en', 'ua': 'a', 'uan': 'an', //
    'uang': 'ang', 'uo': 'o',
  };

  /// Northeast r to y (ren/yin, ri/yi).
  static const Map<String, String> _rToY = <String, String>{
    'i': 'i', 'e': 'e', 'en': 'in', 'eng': 'ing', 'ou': 'ou', 'ang': 'ang', //
    'an': 'an', 'ao': 'ao', 'u': 'v', 'uan': 'van', 'un': 'vn', //
    'ong': 'ong', 'uo': 'o', 'ui': 'vi',
  };

  /// Onsets confused in noise, applied one step only (h>p, b>f).
  static const Map<String, String> _noise = <String, String>{
    'h': 'p', 'p': 'h', 'b': 'f', 'f': 'b',
  };

  static final Map<String, Set<String>> _cache = <String, Set<String>>{};

  /// Canonical forms of one toneless syllable (ü written v).
  static Set<String> classes(String syllable) =>
      _cache.putIfAbsent(syllable, () => _classes(syllable));

  static Set<String> _classes(String syllable) {
    final syl = syllable.replaceAll('ü', 'v');
    var i = '';
    var f = syl;
    for (final init in _initials) {
      if (syl.startsWith(init)) {
        i = init;
        f = syl.substring(init.length);
        break;
      }
    }
    if (const {'j', 'q', 'x', 'y'}.contains(i) && f.startsWith('u')) {
      f = 'v${f.substring(1)}'; // ju is jü
    }
    final forms = <(String, String)>{(i, f)};
    void add((String, String)? Function(String, String) fn) {
      for (final (a, b) in forms.toList()) {
        final y = fn(a, b);
        if (y != null) forms.add(y);
      }
    }

    add((a, b) => a == 'r' ? ('y', _rToY[b] ?? b) : null);
    add((a, b) => b.startsWith('v') ? (a, 'i${b.substring(1)}') : null);
    add((a, b) => a == 'h' && _huToF.containsKey(b) ? ('f', _huToF[b]!) : null);
    add((a, b) => a == 'h' && b == 'ong' ? ('f', 'eng') : null);
    add((a, b) => switch ((a, b)) {
          ('g', 'uo') => ('g', 'e'),
          ('h', 'uo') => ('h', 'e'),
          _ => null,
        });
    for (final (a, b) in forms.toList()) {
      final j = _noise[a];
      if (j != null) forms.add((j, b));
    }

    final out = <String>{};
    for (var (a, b) in forms) {
      a = switch (a) {
        'zh' => 'z',
        'ch' => 'c',
        'sh' => 's',
        'n' => 'l',
        'r' => 'l',
        _ => a,
      };
      b = b
          .replaceFirst(RegExp(r'ing$'), 'in')
          .replaceFirst(RegExp(r'eng$'), 'en')
          .replaceFirst(RegExp(r'ang$'), 'an');
      if (!const {'j', 'q', 'x', 'y', 'l'}.contains(a)) {
        b = b.replaceAll('v', 'u');
      }
      if (a == 'y' && b.startsWith('i') && !const {'i', 'in', 'ing'}.contains(b)) {
        b = b.substring(1); // yian is spelt yan
      }
      out.add('$a|$b');
    }
    return out;
  }
}
