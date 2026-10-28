// zh-1 input (v0.5.0 plan Task 3.1; spike .devloop/spikes/chinese-words.md
// §4): every entry is reachable from every written form and every common
// way to type its pinyin, and no input ever names two entries
// (requirement 3): an input that could mean more than one is not a word.

import 'package:flutter_test/flutter_test.dart';
import 'package:signet/core/crypto/wordlists.dart';
import 'package:signet/core/crypto/zh_input.dart';
import 'package:signet/core/crypto/zh_reading_table.dart';
import 'package:signet/core/crypto/zh_wordlist.dart';

/// "píng guǒ" -> "ping2 guo3" (neutral tone: no digit).
String _toneDigits(String pinyin) => pinyin.split(' ').map((syl) {
      const marks = {
        'āēīōūǖ': 1, 'áéíóúǘ': 2, 'ǎěǐǒǔǚ': 3, 'àèìòùǜ': 4,
      };
      var tone = 0;
      final base = StringBuffer();
      for (final ch in syl.split('')) {
        var plain = ch;
        marks.forEach((set, t) {
          final i = set.indexOf(ch);
          if (i >= 0) {
            tone = t;
            plain = 'aeiouü'[i];
          }
        });
        base.write(plain == 'ü' ? 'v' : plain);
      }
      return tone == 0 ? base.toString() : '$base$tone';
    }).join(' ');

/// Tone-marked pinyin in decomposed form (combining marks).
String _nfd(String pinyin) {
  const map = {
    'ā': 'ā', 'á': 'á', 'ǎ': 'ǎ', 'à': 'à',
    'ē': 'ē', 'é': 'é', 'ě': 'ě', 'è': 'è',
    'ī': 'ī', 'í': 'í', 'ǐ': 'ǐ', 'ì': 'ì',
    'ō': 'ō', 'ó': 'ó', 'ǒ': 'ǒ', 'ò': 'ò',
    'ū': 'ū', 'ú': 'ú', 'ǔ': 'ǔ', 'ù': 'ù',
    'ü': 'ü', 'ǖ': 'ǖ', 'ǘ': 'ǘ',
    'ǚ': 'ǚ', 'ǜ': 'ǜ',
  };
  return pinyin.split('').map((c) => map[c] ?? c).join();
}

String _fullwidth(String s) => String.fromCharCodes(
    s.runes.map((r) => r >= 0x21 && r <= 0x7E ? r + 0xFEE0 : r));

void main() {
  final z = ZhInput.zh1;
  final zh = WordList.zh1;

  test('zh-1 is a full list with its own id and locale', () {
    expect(zh.id, 'zh-1');
    expect(zh.languageTag, 'zh-CN');
    expect(zh.words, hasLength(WordList.size));
    expect(zh.wordAt(0), zhWordlist[0].simplified);
  });

  test('every entry is named by each of its written forms', () {
    for (var i = 0; i < zhWordlist.length; i++) {
      final w = zhWordlist[i];
      for (final form in [w.simplified, w.traditional, ...w.otherForms]) {
        expect(zh.indexOf(form), i, reason: form);
      }
    }
  });

  test('every entry is named by every common way to type its pinyin', () {
    for (var i = 0; i < zhWordlist.length; i++) {
      final w = zhWordlist[i];
      final digits = _toneDigits(w.pinyin);
      for (final input in [
        w.key, // an bian
        w.key.replaceAll(' ', ''), // anbian
        w.key.replaceAll(' ', "'"), // an'bian
        w.pinyin, // àn biān
        w.pinyin.replaceAll(' ', ''), // ànbiān
        _nfd(w.pinyin), // decomposed tone marks
        digits, // an4 bian1
        digits.replaceAll(' ', ''), // an4bian1
        w.key.toUpperCase(),
        _fullwidth(w.key.replaceAll(' ', '')),
        w.key.replaceAll('v', 'ü'),
        w.key.replaceAll('v', 'u:'),
      ]) {
        expect(zh.indexOf(input), i, reason: '${w.simplified}: "$input"');
      }
    }
  });

  test('accent mergers: the southern and Taiwan pronunciations reach the '
      'entry', () {
    // Build each entry's key with zh->z, ch->c, sh->s and -ng->-n applied.
    var checked = 0;
    for (var i = 0; i < zhWordlist.length; i++) {
      final key = zhWordlist[i].key;
      final southern = key
          .replaceAll('zh', 'z')
          .replaceAll('ch', 'c')
          .replaceAll('sh', 's')
          .split(' ')
          .map((s) => s.endsWith('ng') && s != 'ng' ? s.substring(0, s.length - 1) : s)
          .join(' ');
      if (southern == key) continue;
      final hits = z.candidates(southern);
      // Never another entry; usually this one (unless the merged spelling
      // could also mean a second entry, then nothing).
      expect(hits.length <= 1 || zh.indexOf(southern) == null, isTrue);
      if (hits.length == 1) {
        expect(hits.single, i, reason: '$key -> $southern');
        checked++;
      }
    }
    expect(checked, greaterThan(500));
  });

  test('requirement 3, exhaustive: every two-syllable input over the '
      'syllable inventory names at most one entry', () {
    final syllables = <String>{
      for (final l in zhReadingTable.split('\n')) l.split('\t').first,
    };
    var named = 0;
    var ambiguous = 0;
    for (final a in syllables) {
      for (final b in syllables) {
        for (final input in ['$a $b', '$a$b']) {
          final hits = z.candidates(input);
          final got = zh.indexOf(input);
          if (hits.length == 1) {
            expect(got, hits.single);
            named++;
          } else {
            expect(got, isNull, reason: input);
            if (hits.length > 1) ambiguous++;
          }
        }
      }
    }
    // Recorded so a change in the mergers or the list shows up here.
    expect(named, greaterThan(19000));
    expect(ambiguous, lessThan(400));
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('characters through the reading table: a homophone slip still names '
      'the entry when only one entry sounds like it', () {
    // 苹果 typed as 平果 (an IME homophone slip).
    final apple = zhWordlist.indexWhere((w) => w.simplified == '苹果');
    expect(apple, isNonNegative);
    expect(zh.indexOf('平果'), apple);
    // Spaces between characters do not matter.
    expect(zh.indexOf('苹 果'), apple);
  });

  test('rejects what cannot be one entry', () {
    expect(zh.indexOf(''), isNull);
    expect(zh.indexOf('苹'), isNull); // one character
    expect(zh.indexOf('ping'), isNull); // one syllable
    expect(zh.indexOf('苹guo'), isNull); // Han and Latin in one slot
    expect(zh.indexOf('ping guo huo che'), isNull); // four syllables
    expect(zh.indexOf('ping6 guo'), isNull); // not a tone digit
    expect(zh.indexOf('abandon'), isNull); // English
    expect(zh.indexOf('élève'), isNull); // French
  });

  test('variation selectors, format characters and compatibility '
      'ideographs are ignored', () {
    final apple = zhWordlist.indexWhere((w) => w.simplified == '苹果');
    expect(zh.indexOf('苹︀果​'), apple);
    final compat = zhCompatibilityIdeographs.entries.first;
    final unified = String.fromCharCode(compat.value);
    final entry = zhWordlist.indexWhere(
        (w) => w.simplified.contains(unified) || w.traditional.contains(unified));
    if (entry >= 0) {
      final w = zhWordlist[entry];
      final form = w.simplified.contains(unified) ? w.simplified : w.traditional;
      expect(zh.indexOf(form.replaceAll(unified, String.fromCharCode(compat.key))),
          entry);
    }
  });

  test('the mergers match the generator: hui ~ fei, hong ~ feng, ren ~ yin', () {
    expect(ZhSound.classes('hui').intersection(ZhSound.classes('fei')),
        isNotEmpty);
    expect(ZhSound.classes('hong').intersection(ZhSound.classes('feng')),
        isNotEmpty);
    expect(ZhSound.classes('ren').intersection(ZhSound.classes('yin')),
        isNotEmpty);
    // Aspiration pairs stay apart.
    expect(ZhSound.classes('ba').intersection(ZhSound.classes('pa')), isEmpty);
  });

  test('not in the shipped lists unless built with SIGNET_ZH', () {
    expect(WordList.shipped.contains(zh), WordList.chineseEnabled);
    expect(WordList.byId('zh-1') == zh, WordList.chineseEnabled);
  });
}
