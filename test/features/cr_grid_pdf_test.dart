import 'dart:async';
import 'dart:convert' show latin1;
import 'dart:io' show zlib;
import 'dart:typed_data';
import 'dart:ui' show Locale;

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart' show TtfParser;
import 'package:signet/core/crypto/wordlists.dart';
import 'package:signet/l10n/app_localizations.dart';
import 'package:signet/core/crypto/challenge_response_grid.dart';
import 'package:signet/features/inspect/cr_grid_pdf.dart';

void main() {
  // build() loads the embedded font through rootBundle.
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the card prints in the UI language when the font covers it', () {
    expect(CrGridPdf.printCatalogFor(const Locale('en')).localeName, 'en');
    expect(CrGridPdf.printCatalogFor(const Locale('zh')).localeName, 'zh');
    expect(
        CrGridPdf.printCatalogFor(const Locale.fromSubtags(
                languageCode: 'zh', scriptCode: 'Hant'))
            .localeName,
        'zh_Hant');
    expect(CrGridPdf.printCatalogFor(const Locale('de')).localeName, 'en');
    final fr = CrGridPdf.printCatalogFor(const Locale('fr', 'CA'));
    final hasFr = AppLocalizations.supportedLocales
        .any((l) => l.languageCode == 'fr');
    expect(fr.localeName, hasFr ? 'fr' : 'en');
  });

  group('the embedded font covers everything the card prints', () {
    late Set<int> regular;
    late Set<int> bold;
    late Set<int> regularSc;
    late Set<int> boldSc;
    late Set<int> regularTc;
    late Set<int> boldTc;
    setUpAll(() async {
      Future<Set<int>> cmap(String asset) async =>
          TtfParser(await rootBundle.load(asset))
              .charToGlyphIndexMap
              .keys
              .toSet();
      regular = await cmap(CrGridPdf.regularFontAsset);
      bold = await cmap(CrGridPdf.boldFontAsset);
      regularSc = await cmap(CrGridPdf.regularScFontAsset);
      boldSc = await cmap(CrGridPdf.boldScFontAsset);
      regularTc = await cmap(CrGridPdf.regularTcFontAsset);
      boldTc = await cmap(CrGridPdf.boldTcFontAsset);
    });

    void expectCovered(String text, Set<int> font, String what) {
      final missing = <String>{
        for (final r in text.runes)
          if (!font.contains(r) && r != 0x0A) String.fromCharCode(r),
      };
      expect(missing, isEmpty, reason: '$what: "$text"');
    }

    test('every word of every list', () {
      for (final list in [WordList.english, WordList.french]) {
        for (final w in list.words) {
          expectCovered(w, regular, list.id);
        }
      }
      // zh-1 in both scripts, regular in the cells and bold in the row
      // and column headers (tool/fonts/subset_noto_cjk.py).
      final all = List<int>.generate(WordList.size, (i) => i);
      for (final w in WordList.zh1.renderIn(all, traditional: false)) {
        expectCovered(w, regularSc, 'zh-1 simplified');
        expectCovered(w, boldSc, 'zh-1 simplified bold');
      }
      for (final w in WordList.zh1.renderIn(all, traditional: true)) {
        expectCovered(w, regularTc, 'zh-1 traditional');
        expectCovered(w, boldTc, 'zh-1 traditional bold');
      }
    });

    test('every card string of every printable catalog', () {
      for (final l in AppLocalizations.supportedLocales) {
        if (!CrGridPdf.printableLanguages.contains(l.languageCode)) continue;
        final c = lookupAppLocalizations(l);
        // A Chinese card falls back to its script's CJK font.
        final hant = l.scriptCode == 'Hant';
        final zh = l.languageCode == 'zh';
        final r = {...regular, if (zh) ...(hant ? regularTc : regularSc)};
        final b = {...bold, if (zh) ...(hant ? boldTc : boldSc)};
        for (final text in [
          c.crPdfDocTitle('Mom'),
          c.crPdfWarningBody,
          c.crPdfRowsHeader,
          c.crPdfColumnsHeader,
          c.crPdfFooter,
        ]) {
          expectCovered(text, r, l.toLanguageTag());
        }
        for (final text in [c.crPdfCardTitle, c.crPdfWarningTitle]) {
          expectCovered(text, b, '${l.toLanguageTag()} bold');
        }
      }
    });

    test('contact names in Latin, Greek and Cyrillic scripts', () {
      for (final name in [
        'Ștefan Țărnă', 'Nguyễn Thị Ánh', 'Əli', 'Kaʻiulani', 'Łukasz',
        'Ελένη', 'Анна', 'Ørjan', 'Gül', 'José',
      ]) {
        expectCovered(name, regular, 'label');
        expectCovered(name, bold, 'label bold');
      }
    });

    test('French typography: ’ œ « » no-break spaces', () {
      expectCovered('l’œuvre « oui » 100\u00A0% 12\u202F€', regular, 'fr');
    });
  });

  test('a French grid and an accented label print', () async {
    final grid = await ChallengeResponseGrid.derive(
      List<int>.generate(32, (i) => i + 1),
      list: WordList.french,
    );
    final bytes = await CrGridPdf.build(
      peerLabel: 'Mamie Hélène',
      grid: grid,
      generatedAt: DateTime.utc(2026, 4, 19),
      uiLocale: const Locale('fr'),
    );
    expect(bytes.take(5).toList(), <int>[0x25, 0x50, 0x44, 0x46, 0x2D]);
    // The embedded font, not Helvetica (which cannot draw ’ or œ).
    final text = String.fromCharCodes(bytes);
    expect(text, contains('NotoSans'));
    expect(text, isNot(contains('/Helvetica')));
  });

  group('the contact name', () {
    late ChallengeResponseGrid grid;
    setUpAll(() async {
      grid = await ChallengeResponseGrid.derive(
        List<int>.generate(32, (i) => i + 1),
      );
    });

    Future<List<String>> imaged(String label) async {
      final asked = <String>[];
      await CrGridPdf.build(
        peerLabel: label,
        grid: grid,
        generatedAt: DateTime.utc(2026, 4, 19),
        labelImage: (l) async {
          asked.add(l);
          return null;
        },
      );
      return asked;
    }

    test('prints as text when the fonts have it', () async {
      expect(await imaged('Mamie Hélène'), isEmpty);
      // Common family names are in the CJK subsets.
      for (final name in ['妈妈', '媽媽', '外婆', '爷爷', '爺爺', '老公']) {
        expect(await imaged(name), isEmpty, reason: name);
      }
    });

    test('prints as an image when they do not', () async {
      expect(await imaged('👵 Grandma'), <String>['👵 Grandma']);
      expect(await imaged('김민지'), <String>['김민지']);
      expect(await imaged('محمد'), <String>['محمد']);
    });

    test('the image goes in the PDF', () async {
      final png = await CrGridPdf.renderLabelImage('김민지');
      Future<String> card(Uint8List? image) async => _inflated(
            await CrGridPdf.build(
              peerLabel: '김민지',
              grid: grid,
              generatedAt: DateTime.utc(2026, 4, 19),
              labelImage: (_) async => image,
            ),
          );
      expect(await card(png), contains('/Subtype/Image'));
      expect(await card(null), isNot(contains('/Subtype/Image')));
    });

    test('renderLabelImage draws a PNG', () async {
      final png = await CrGridPdf.renderLabelImage('김민지');
      expect(png, isNotNull);
      expect(png!.take(4).toList(), <int>[0x89, 0x50, 0x4E, 0x47]);
      expect(await CrGridPdf.renderLabelImage(''), isNull);
    });
  });

  group('Chinese line breaking', () {
    // Every character 10 points wide; [chars] fit on a line (the breaker
    // keeps half a point of slack).
    List<String> lines(String text, int chars) =>
        CrGridPdf.chineseLines(text, chars * 10 + 1, (_) => 10);

    test('breaks between Han characters to fill each line', () {
      expect(lines('任何捡到这张卡片的人', 4), <String>['任何捡到', '这张卡片', '的人']);
    });

    test('never starts a line with closing punctuation', () {
      // 。 would start the second line: the character before it moves
      // down with it.
      expect(lines('卡片丢失。如果', 4), <String>['卡片丢', '失。如果']);
      expect(lines('一二三四，五', 4), <String>['一二三', '四，五']);
    });

    test('never ends a line with opening punctuation', () {
      expect(lines('一二三「四」', 4), <String>['一二三', '「四」']);
    });

    test('keeps —— together and Latin words whole', () {
      expect(lines('一二三——四', 4), <String>['一二三', '——四']);
      expect(lines('使用 Signet 应用', 9), <String>['使用 Signet', '应用']);
    });

    test('a word wider than the line still prints', () {
      expect(lines('Signet', 3), <String>['Signet']);
    });

    test('the Chinese warnings start no line with punctuation', () async {
      for (final locale in const <Locale>[
        Locale('zh'),
        Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
      ]) {
        final body = lookupAppLocalizations(locale).crPdfWarningBody;
        // Line lengths near the card's (about 57 characters at 9 points).
        for (var n = 30; n <= 60; n++) {
          for (final line in lines(body, n).skip(1)) {
            expect('，。、；：？！）」』'.contains(line[0]), isFalse,
                reason: '$locale at $n: "$line"');
          }
        }
      }
    });
  });

  for (final (name, locale, traditional) in <(String, Locale, bool)>[
    ('simplified', const Locale('zh'), false),
    (
      'traditional',
      const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
      true,
    ),
  ]) {
    test('a $name Chinese card with zh-1 words draws every character',
        () async {
      WordList.showTraditionalChinese = traditional;
      addTearDown(() => WordList.showTraditionalChinese = false);
      final grid = await ChallengeResponseGrid.derive(
        List<int>.generate(32, (i) => i + 1),
        list: WordList.zh1,
      );
      final missing = <String>[];
      final bytes = await runZoned(
        () => CrGridPdf.build(
          peerLabel: '妈妈',
          grid: grid,
          generatedAt: DateTime.utc(2026, 4, 19),
          uiLocale: locale,
        ),
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) {
            if (line.contains('Unable to find a font')) missing.add(line);
            parent.print(zone, line);
          },
        ),
      );
      expect(missing, isEmpty);
      expect(String.fromCharCodes(bytes),
          contains(traditional ? 'NotoSansCJKtc' : 'NotoSansCJKsc'));
    });
  }

  test('CrGridPdf.build produces a non-empty PDF with a %PDF- header',
      () async {
    final grid = await ChallengeResponseGrid.derive(
      List<int>.generate(32, (i) => i + 1),
    );
    final bytes = await CrGridPdf.build(
      peerLabel: 'Mom',
      grid: grid,
      generatedAt: DateTime.utc(2026, 4, 19),
    );
    expect(bytes, isNotEmpty);
    // Standard PDF magic number: "%PDF-" (0x25 0x50 0x44 0x46 0x2D).
    expect(bytes.take(5).toList(), <int>[0x25, 0x50, 0x44, 0x46, 0x2D]);
  });

  test('PDF output is deterministic-by-input-shape (same label + grid + date)',
      () async {
    final grid = await ChallengeResponseGrid.derive(
      List<int>.generate(32, (i) => i + 2),
    );
    final a = await CrGridPdf.build(
      peerLabel: 'Alice',
      grid: grid,
      generatedAt: DateTime.utc(2026, 4, 19, 12, 0),
    );
    final b = await CrGridPdf.build(
      peerLabel: 'Alice',
      grid: grid,
      generatedAt: DateTime.utc(2026, 4, 19, 12, 0),
    );
    // pdf package embeds timestamps in its own metadata stream, so the
    // bytes won't be byte-equal. What we care about is that the output
    // is structurally the same size (±some metadata noise). If this
    // assertion becomes flaky we'll drop it — the real load-bearing
    // test is the happy-path byte-generation above.
    expect((a.length - b.length).abs(), lessThan(256));
  });

  test('renders on landscape / letter without throwing', () async {
    // Pins behavior: if pdf package upgrades tweak their Page DSL
    // semantics we'll catch it here.
    final grid = await ChallengeResponseGrid.derive(
      List<int>.generate(32, (i) => i + 3),
    );
    await expectLater(
      CrGridPdf.build(
        peerLabel: 'Someone with a long-ish label that pushes layout',
        grid: grid,
        generatedAt: DateTime.utc(2026, 4, 19),
      ),
      completes,
    );
  });
}

/// [pdf] with its compressed streams inflated, so tests can look inside
/// the object streams.
String _inflated(Uint8List pdf) {
  final text = latin1.decode(pdf);
  final out = StringBuffer(text);
  for (final m in RegExp(r'stream\r?\n').allMatches(text)) {
    final end = text.indexOf('endstream', m.end);
    if (end < 0) continue;
    try {
      out.write(latin1.decode(zlib.decode(pdf.sublist(m.end, end))));
    } on FormatException {
      // Not a deflated stream.
    }
  }
  return out.toString();
}
