import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:ui' show Locale;

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/crypto/challenge_response_grid.dart';
import '../../core/crypto/wordlists.dart';
import '../../l10n/app_localizations.dart';

/// Renders a [ChallengeResponseGrid] as a one-page letter-size PDF
/// document per the paper layout in
/// `.devloop/spikes/challenge-response.md`.
///
/// Layout (letter, portrait):
///   Header:  title + peer label + generation date
///   Warning: "Keep this card secret..." block
///   Legend:  the 8 row words and 8 col words listed as axis references
///   Table:   8×8 body, each cell shows 3 answer words stacked
///   Footer:  "Signet v0.2 · signet.app"-style attribution (TBD)
class CrGridPdf {
  const CrGridPdf._();

  /// UI languages the embedded fonts can print (v0.5.0 plan Tasks 1.7 and
  /// 3.6).
  static const Set<String> printableLanguages = <String>{'en', 'fr', 'zh'};

  /// The catalog the card is printed in for a UI in [uiLocale]: the UI's
  /// own when the fonts cover it and the app has it, else English. Keeps
  /// the script of a Chinese UI, so a Traditional UI prints the
  /// Traditional card.
  static AppLocalizations printCatalogFor(Locale uiLocale) {
    final code = uiLocale.languageCode;
    final supported = AppLocalizations.supportedLocales
        .any((l) => l.languageCode == code);
    if (!printableLanguages.contains(code) || !supported) {
      return lookupAppLocalizations(const Locale('en'));
    }
    const hant = Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant');
    if (code == 'zh' &&
        uiLocale.scriptCode == 'Hant' &&
        AppLocalizations.supportedLocales.contains(hant)) {
      return lookupAppLocalizations(hant);
    }
    return lookupAppLocalizations(Locale(code));
  }

  /// The embedded Latin subset of Noto Sans (tool/fonts/subset_noto.sh):
  /// the pdf package's built-in Helvetica covers only U+0000-00FF, which
  /// lacks French ’ (U+2019) and œ (U+0153).
  static const String regularFontAsset =
      'assets/fonts/NotoSans-Regular-Latin.ttf';
  static const String boldFontAsset = 'assets/fonts/NotoSans-Bold-Latin.ttf';

  /// The embedded Chinese subsets of Noto Sans CJK
  /// (tool/fonts/subset_noto_cjk.py): every zh-1 word and the Chinese card
  /// strings, in simplified (SC) and Taiwan traditional (TC) glyph shapes.
  /// The Latin font's fallback, for Han and CJK punctuation only.
  static const String regularScFontAsset =
      'assets/fonts/NotoSansCJKsc-Regular-Card.ttf';
  static const String boldScFontAsset =
      'assets/fonts/NotoSansCJKsc-Bold-Card.ttf';
  static const String regularTcFontAsset =
      'assets/fonts/NotoSansCJKtc-Regular-Card.ttf';
  static const String boldTcFontAsset =
      'assets/fonts/NotoSansCJKtc-Bold-Card.ttf';

  /// Build the PDF bytes. Caller hands the result to
  /// `Printing.layoutPdf(onLayout: (_) => bytes)` to open the platform
  /// print dialog, or writes to a file. The card is printed in the UI's
  /// language when [printableLanguages] has it ([printCatalogFor]), with
  /// the grid's words in the contact's list, as on screen.
  ///
  /// The contact's name can hold any character (another script, emoji), so
  /// a name the embedded fonts cannot draw is printed as an image drawn by
  /// the phone's own fonts ([labelImage], [renderLabelImage] by default;
  /// plan decision D5) instead of as empty boxes.
  static Future<Uint8List> build({
    required String peerLabel,
    required ChallengeResponseGrid grid,
    required DateTime generatedAt,
    Locale uiLocale = const Locale('en'),
    PdfPageFormat pageFormat = PdfPageFormat.letter,
    Future<Uint8List?> Function(String label)? labelImage,
  }) async {
    final l10n = printCatalogFor(uiLocale);
    // Characters both scripts share take the shape of the first font: the
    // card's script for its own text, and the script the words are shown
    // in for the words, so no word mixes Mainland and Taiwan shapes.
    final cardTraditional = l10n.localeName.startsWith('zh')
        ? l10n.localeName == 'zh_Hant'
        : WordList.showTraditionalChinese;
    final wordsTraditional = WordList.showTraditionalChinese;
    final fonts = await _CardFonts.load();
    final image = fonts.canDrawBold(peerLabel)
        ? null
        : await (labelImage ?? renderLabelImage)(peerLabel);
    final card = _Card(
      l10n: l10n,
      grid: grid,
      boldFallback: fonts.fallback(traditional: cardTraditional, bold: true),
      wordFallback: fonts.fallback(traditional: wordsTraditional, bold: false),
      wordBoldFallback:
          fonts.fallback(traditional: wordsTraditional, bold: true),
    );
    final doc = pw.Document(
      title: l10n.crPdfDocTitle(peerLabel),
      theme: pw.ThemeData.withFont(
        base: fonts.regular,
        bold: fonts.bold,
        fontFallback: fonts.fallback(traditional: cardTraditional, bold: false),
      ),
    );
    doc.addPage(
      pw.Page(
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.fromLTRB(36, 36, 36, 36),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: <pw.Widget>[
              card.headerBlock(
                peerLabel: peerLabel,
                labelImage: image,
                generatedAt: generatedAt,
              ),
              pw.SizedBox(height: 12),
              card.warningBlock(),
              pw.SizedBox(height: 16),
              card.axisLegend(),
              pw.SizedBox(height: 14),
              card.bodyTable(),
              pw.Spacer(),
              card.footer(),
            ],
          );
        },
      ),
    );
    return doc.save();
  }

  /// Punctuation that must not start a line, and that must not end one,
  /// in Chinese typesetting.
  static const String _noLineStart =
      '，。、；：？！）」』〉》】〕〗］｝”’～·,.;:?!)]}%';
  static const String _noLineEnd = '（「『〈《【〔〖［｛“‘([{';

  /// [text] split into lines no wider than [width], given each
  /// character's [advance] in points: breaks fall at spaces or between two
  /// characters either of which is Han or CJK punctuation, never before
  /// [_noLineStart] (even after a space), after [_noLineEnd], or inside
  /// —— and ……, or either side of a hyphen (挑战-应答). A run of other
  /// letters (a Latin word) stays whole unless it alone is too wide.
  @visibleForTesting
  static List<String> chineseLines(
    String text,
    double width,
    double Function(int rune) advance,
  ) {
    bool wide(int r) => r >= 0x2E80 || r == 0x2014 || r == 0x2026;
    // Units that cannot be split, each with whether a space came first.
    final units = <(String, bool)>[];
    var space = false;
    for (final rune in text.runes) {
      final ch = String.fromCharCode(rune);
      if (ch.trim().isEmpty) {
        space = true;
        continue;
      }
      if (units.isNotEmpty) {
        final (last, lastSpace) = units.last;
        final prev = last.runes.last;
        // Closing punctuation stays with what it closes, space or not.
        if (space && _noLineStart.contains(ch)) {
          units[units.length - 1] = ('$last $ch', lastSpace);
          space = false;
          continue;
        }
        final glue = !space &&
            (_noLineStart.contains(ch) ||
                _noLineEnd.contains(String.fromCharCode(prev)) ||
                (rune == prev && (rune == 0x2014 || rune == 0x2026)) ||
                rune == 0x2D ||
                prev == 0x2D ||
                (!wide(rune) && !wide(prev)));
        if (glue) {
          units[units.length - 1] = (last + ch, lastSpace);
          continue;
        }
      }
      units.add((ch, space));
      space = false;
    }

    double measure(String s) =>
        s.runes.fold(0.0, (sum, r) => sum + advance(r));
    final spaceWidth = advance(0x20);
    final lines = <String>[];
    var line = StringBuffer();
    var lineWidth = 0.0;
    // Half a point of slack, so the pdf package never wraps a line again.
    final limit = width - 0.5;
    for (final (unit, spaced) in units) {
      final unitWidth = measure(unit);
      final gap = spaced && line.isNotEmpty ? spaceWidth : 0.0;
      if (line.isNotEmpty && lineWidth + gap + unitWidth > limit) {
        lines.add(line.toString());
        line = StringBuffer(unit);
        lineWidth = unitWidth;
        continue;
      }
      if (gap > 0) line.write(' ');
      line.write(unit);
      lineWidth += gap + unitWidth;
    }
    if (line.isNotEmpty) lines.add(line.toString());
    return lines;
  }

  /// Size of the printed name, in points.
  static const double labelFontSize = 22;

  /// Widest the printed name may be, in points: the page less the date.
  static const double labelMaxWidth = 420;

  /// Pixels per point of the name image: 4 is 288 dpi, sharp on paper.
  static const double _labelScale = 4;

  /// [label] drawn in black bold by the phone's own fonts, as PNG bytes at
  /// [_labelScale] pixels per point, at most two lines of [labelMaxWidth]
  /// with a little room around them for marks and overhangs; null if it
  /// draws nothing. [locale] picks the regional glyph shapes for Han the
  /// phone draws (Chinese rather than Japanese ones). The print screen
  /// draws it before opening the print dialog, while the app is in front.
  static Future<Uint8List?> renderLabelImage(String label,
      {Locale? locale}) async {
    final builder = ui.ParagraphBuilder(ui.ParagraphStyle(
      fontSize: labelFontSize * _labelScale,
      fontWeight: ui.FontWeight.bold,
      maxLines: 2,
      ellipsis: '\u2026',
      locale: locale,
    ))
      ..pushStyle(ui.TextStyle(
        color: const ui.Color(0xFF000000),
        locale: locale,
      ))
      ..addText(label);
    final paragraph = builder.build()
      ..layout(const ui.ParagraphConstraints(width: labelMaxWidth * _labelScale));
    final pad = (labelFontSize * _labelScale * 0.15).ceil();
    final width = paragraph.longestLine.ceil();
    final height = paragraph.height.ceil();
    if (width <= 0 || height <= 0) {
      paragraph.dispose();
      return null;
    }
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder)
        .drawParagraph(paragraph, ui.Offset(pad.toDouble(), pad.toDouble()));
    paragraph.dispose();
    final picture = recorder.endRecording();
    final image = await picture.toImage(width + 2 * pad, height + 2 * pad);
    picture.dispose();
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return png?.buffer.asUint8List();
  }
}

/// The card's embedded fonts: the Latin subset, with the Chinese subsets
/// as its fallback.
class _CardFonts {
  _CardFonts._(this._fonts, this._boldChars);

  /// Latin regular and bold, then SC and TC, each regular and bold.
  final List<pw.Font> _fonts;

  final Set<int> _boldChars;

  pw.Font get regular => _fonts[0];
  pw.Font get bold => _fonts[1];

  /// The CJK fallback, [traditional] shapes first. Bold styles name the
  /// bold subsets themselves: the pdf package does not pick a bold face
  /// from a fallback list.
  List<pw.Font> fallback({required bool traditional, required bool bold}) {
    final sc = _fonts[bold ? 3 : 2];
    final tc = _fonts[bold ? 5 : 4];
    return traditional ? <pw.Font>[tc, sc] : <pw.Font>[sc, tc];
  }

  /// Whether the bold fonts have every character of [text], and it has no
  /// combining mark (the pdf package does not position marks, so "é"
  /// typed as e and U+0301 would print its accent beside the letter).
  bool canDrawBold(String text) => text.runes
      .every((r) => _boldChars.contains(r) && !_isCombiningMark(r));

  static bool _isCombiningMark(int r) =>
      (r >= 0x0300 && r <= 0x036F) ||
      (r >= 0x1AB0 && r <= 0x1AFF) ||
      (r >= 0x1DC0 && r <= 0x1DFF) ||
      (r >= 0x20D0 && r <= 0x20FF) ||
      (r >= 0xFE20 && r <= 0xFE2F);

  static Future<_CardFonts> load() async {
    final assets = <String>[
      CrGridPdf.regularFontAsset,
      CrGridPdf.boldFontAsset,
      CrGridPdf.regularScFontAsset,
      CrGridPdf.boldScFontAsset,
      CrGridPdf.regularTcFontAsset,
      CrGridPdf.boldTcFontAsset,
    ];
    final data = <ByteData>[for (final a in assets) await rootBundle.load(a)];
    final boldChars = <int>{
      for (final i in const <int>[1, 3, 5])
        ...TtfParser(data[i]).charToGlyphIndexMap.keys,
    };
    return _CardFonts._(
      <pw.Font>[for (final d in data) pw.Font.ttf(d)],
      boldChars,
    );
  }
}

/// The card's blocks, in [l10n] with [grid]'s words.
class _Card {
  const _Card({
    required this.l10n,
    required this.grid,
    required this.boldFallback,
    required this.wordFallback,
    required this.wordBoldFallback,
  });

  final AppLocalizations l10n;
  final ChallengeResponseGrid grid;

  /// CJK fallbacks: the card's own bold text, and the grid's words, which
  /// can be in the other script.
  final List<pw.Font> boldFallback;
  final List<pw.Font> wordFallback;
  final List<pw.Font> wordBoldFallback;

  /// Whether the card is in Chinese: no letter spacing (it pulls Han
  /// apart), and paragraphs broken by Chinese rules
  /// ([CrGridPdf.chineseLines]).
  bool get _chinese => l10n.localeName.startsWith('zh');

  pw.TextStyle _bold({required double fontSize, double? letterSpacing}) =>
      pw.TextStyle(
        fontSize: fontSize,
        fontWeight: pw.FontWeight.bold,
        letterSpacing: _chinese ? null : letterSpacing,
        fontFallback: boldFallback,
      );

  pw.TextStyle _word({required double fontSize}) =>
      pw.TextStyle(fontSize: fontSize, fontFallback: wordFallback);

  pw.TextStyle _wordBold({required double fontSize, double? letterSpacing}) =>
      pw.TextStyle(
        fontSize: fontSize,
        fontWeight: pw.FontWeight.bold,
        letterSpacing: _chinese ? null : letterSpacing,
        fontFallback: wordBoldFallback,
      );

  /// [text] as a wrapped paragraph. The pdf package breaks lines anywhere
  /// between Han characters, so a Chinese line could start with 。 or ，
  /// (wrong in Chinese typesetting): Chinese text is broken into lines
  /// here instead.
  pw.Widget _paragraph(String text, pw.TextStyle style) {
    if (!_chinese) return pw.Text(text, style: style);
    return pw.LayoutBuilder(builder: (context, constraints) {
      final resolved = pw.Theme.of(context).defaultTextStyle.merge(style);
      final lines =
          CrGridPdf.chineseLines(text, constraints!.maxWidth, (rune) {
        for (final font in <pw.Font>[
          resolved.font!,
          ...resolved.fontFallback,
        ]) {
          final pdfFont = font.getFont(context);
          if (pdfFont.isRuneSupported(rune)) {
            return pdfFont.glyphMetrics(rune).advanceWidth *
                resolved.fontSize!;
          }
        }
        return resolved.fontSize!;
      });
      return pw.Text(lines.join('\n'), style: style);
    });
  }

  pw.Widget headerBlock({
    required String peerLabel,
    required Uint8List? labelImage,
    required DateTime generatedAt,
  }) {
    final y = generatedAt.toUtc().year.toString().padLeft(4, '0');
    final m = generatedAt.toUtc().month.toString().padLeft(2, '0');
    final d = generatedAt.toUtc().day.toString().padLeft(2, '0');
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.black, width: 1),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: <pw.Widget>[
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: <pw.Widget>[
              pw.Text(
                l10n.crPdfCardTitle,
                style: _bold(fontSize: 12, letterSpacing: 2),
              ),
              pw.SizedBox(height: 4),
              if (labelImage != null)
                _labelImage(labelImage)
              else
                pw.Text(
                  peerLabel,
                  style: _bold(fontSize: CrGridPdf.labelFontSize),
                ),
            ],
          ),
          pw.Text(
            '$y-$m-$d UTC',
            style: const pw.TextStyle(fontSize: 10),
          ),
        ],
      ),
    );
  }

  /// The name image at its size in points: [CrGridPdf._labelScale]
  /// pixels per point.
  static pw.Widget _labelImage(Uint8List png) {
    final image = pw.MemoryImage(png);
    return pw.Image(
      image,
      width: image.width! / CrGridPdf._labelScale,
      height: image.height! / CrGridPdf._labelScale,
    );
  }

  pw.Widget warningBlock() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.black, width: 0.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          pw.Text(
            l10n.crPdfWarningTitle,
            style: _bold(fontSize: 10, letterSpacing: 1.2),
          ),
          pw.SizedBox(height: 4),
          _paragraph(
            l10n.crPdfWarningBody,
            const pw.TextStyle(fontSize: 9, lineSpacing: 1.4),
          ),
        ],
      ),
    );
  }

  pw.Widget axisLegend() {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: <pw.Widget>[
        pw.Expanded(
          child: _axisPanel(title: l10n.crPdfRowsHeader, words: grid.rowLabels),
        ),
        pw.SizedBox(width: 12),
        pw.Expanded(
          child:
              _axisPanel(title: l10n.crPdfColumnsHeader, words: grid.colLabels),
        ),
      ],
    );
  }

  pw.Widget _axisPanel({
    required String title,
    required List<String> words,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.black, width: 0.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          pw.Text(
            title,
            style: _bold(fontSize: 9, letterSpacing: 1.5),
          ),
          pw.SizedBox(height: 6),
          pw.Wrap(
            spacing: 8,
            runSpacing: 4,
            children: <pw.Widget>[
              for (final word in words)
                pw.Text(word, style: _word(fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget bodyTable() {
    const borderSide = pw.BorderSide(color: PdfColors.grey700, width: 0.5);
    return pw.Table(
      border: const pw.TableBorder(
        top: borderSide,
        bottom: borderSide,
        left: borderSide,
        right: borderSide,
        horizontalInside: borderSide,
        verticalInside: borderSide,
      ),
      columnWidths: <int, pw.TableColumnWidth>{
        for (var i = 0; i < 9; i++)
          i: i == 0
              ? const pw.FlexColumnWidth(1.1)
              : const pw.FlexColumnWidth(1.3),
      },
      children: <pw.TableRow>[
        _headerTableRow(),
        for (var row = 0; row < ChallengeResponseGrid.rowCount; row++)
          _bodyTableRow(row),
      ],
    );
  }

  pw.TableRow _headerTableRow() {
    return pw.TableRow(
      decoration: const pw.BoxDecoration(color: PdfColors.grey200),
      children: <pw.Widget>[
        _headerCell(''),
        for (final col in grid.colLabels) _headerCell(col),
      ],
    );
  }

  pw.Widget _headerCell(String text) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      alignment: pw.Alignment.center,
      child: pw.Text(
        text,
        style: _wordBold(fontSize: 9, letterSpacing: 0.5),
      ),
    );
  }

  pw.TableRow _bodyTableRow(int row) {
    return pw.TableRow(
      children: <pw.Widget>[
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 4),
          alignment: pw.Alignment.center,
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          child: pw.Text(
            grid.rowLabels[row],
            style: _wordBold(fontSize: 9),
          ),
        ),
        for (var col = 0; col < ChallengeResponseGrid.colCount; col++)
          _bodyCell(grid.cells[row][col]),
      ],
    );
  }

  pw.Widget _bodyCell(List<String> words) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: <pw.Widget>[
          for (final word in words)
            pw.Text(
              word,
              style: _word(fontSize: 8),
              textAlign: pw.TextAlign.center,
            ),
        ],
      ),
    );
  }

  pw.Widget footer() {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      child: pw.Text(
        l10n.crPdfFooter,
        style: const pw.TextStyle(
          fontSize: 8,
          color: PdfColors.grey600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
