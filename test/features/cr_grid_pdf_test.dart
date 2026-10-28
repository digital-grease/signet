import 'dart:ui' show Locale;

import 'package:flutter/services.dart' show ByteData, rootBundle;
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
    // No CJK font yet (plan decision D5): a Chinese UI prints English.
    expect(CrGridPdf.printCatalogFor(const Locale('zh')).localeName, 'en');
    expect(CrGridPdf.printCatalogFor(const Locale('de')).localeName, 'en');
    final fr = CrGridPdf.printCatalogFor(const Locale('fr', 'CA'));
    final hasFr = AppLocalizations.supportedLocales
        .any((l) => l.languageCode == 'fr');
    expect(fr.localeName, hasFr ? 'fr' : 'en');
  });

  group('the embedded font covers everything the card prints', () {
    late Set<int> regular;
    late Set<int> bold;
    setUpAll(() async {
      Set<int> cmap(ByteData data) =>
          TtfParser(data).charToGlyphIndexMap.keys.toSet();
      regular = cmap(await rootBundle.load(CrGridPdf.regularFontAsset));
      bold = cmap(await rootBundle.load(CrGridPdf.boldFontAsset));
    });

    void expectCovered(String text, Set<int> font, String what) {
      final missing = <String>{
        for (final r in text.runes)
          if (!font.contains(r) && r != 0x0A) String.fromCharCode(r),
      };
      expect(missing, isEmpty, reason: '$what: "$text"');
    }

    test('every word of every list', () {
      // zh-1 needs the CJK font (plan Task 3.6).
      for (final list in [WordList.english, WordList.french]) {
        for (final w in list.words) {
          expectCovered(w, regular, list.id);
        }
      }
    });

    test('every card string of every printable catalog', () {
      for (final l in AppLocalizations.supportedLocales) {
        if (!CrGridPdf.printableLanguages.contains(l.languageCode)) continue;
        final c = lookupAppLocalizations(l);
        for (final text in [
          c.crPdfDocTitle('Mom'),
          c.crPdfWarningBody,
          c.crPdfRowsHeader,
          c.crPdfColumnsHeader,
          c.crPdfFooter,
        ]) {
          expectCovered(text, regular, l.languageCode);
        }
        for (final text in [c.crPdfCardTitle, c.crPdfWarningTitle]) {
          expectCovered(text, bold, '${l.languageCode} bold');
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

  test('a label the font cannot draw does not stop the print', () async {
    final grid = await ChallengeResponseGrid.derive(
      List<int>.generate(32, (i) => i + 1),
    );
    final bytes = await CrGridPdf.build(
      peerLabel: '妈妈',
      grid: grid,
      generatedAt: DateTime.utc(2026, 4, 19),
    );
    expect(bytes, isNotEmpty);
  });

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
