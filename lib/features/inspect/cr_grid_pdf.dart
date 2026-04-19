import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/crypto/challenge_response_grid.dart';

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

  /// Build the PDF bytes. Synchronous because neither the layout DSL nor
  /// the grid derivation are I/O-bound. Caller hands the result to
  /// `Printing.layoutPdf(onLayout: (_) => bytes)` to open the platform
  /// print dialog, or writes to a file.
  static Future<Uint8List> build({
    required String peerLabel,
    required ChallengeResponseGrid grid,
    required DateTime generatedAt,
  }) async {
    final doc = pw.Document(title: 'Signet challenge-response · $peerLabel');
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.fromLTRB(36, 36, 36, 36),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: <pw.Widget>[
              _headerBlock(peerLabel: peerLabel, generatedAt: generatedAt),
              pw.SizedBox(height: 12),
              _warningBlock(),
              pw.SizedBox(height: 16),
              _axisLegend(grid: grid),
              pw.SizedBox(height: 14),
              _bodyTable(grid: grid),
              pw.Spacer(),
              _footer(),
            ],
          );
        },
      ),
    );
    return doc.save();
  }

  // ------------------------------------------------------------------

  static pw.Widget _headerBlock({
    required String peerLabel,
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
                'SIGNET CHALLENGE-RESPONSE CARD',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                peerLabel,
                style: pw.TextStyle(
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                ),
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

  static pw.Widget _warningBlock() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.black, width: 0.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          pw.Text(
            'TREAT THIS CARD LIKE A SAFE COMBINATION',
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Anyone who finds this card can answer challenges for this '
            'pairing. Challenge-response is a fallback - the rotating '
            'word verify in the app is still the stronger check for '
            'day-to-day calls. If you lose this card, unpair this '
            'relationship in the app and re-pair in person.',
            style: const pw.TextStyle(fontSize: 9, lineSpacing: 1.4),
          ),
        ],
      ),
    );
  }

  static pw.Widget _axisLegend({required ChallengeResponseGrid grid}) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: <pw.Widget>[
        pw.Expanded(
          child: _axisPanel(title: 'ROWS', words: grid.rowLabels),
        ),
        pw.SizedBox(width: 12),
        pw.Expanded(
          child: _axisPanel(title: 'COLUMNS', words: grid.colLabels),
        ),
      ],
    );
  }

  static pw.Widget _axisPanel({
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
            '$title //',
            style: pw.TextStyle(
              fontSize: 9,
              letterSpacing: 1.5,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Wrap(
            spacing: 8,
            runSpacing: 4,
            children: <pw.Widget>[
              for (final word in words)
                pw.Text(word, style: const pw.TextStyle(fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _bodyTable({required ChallengeResponseGrid grid}) {
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
        _headerTableRow(grid: grid),
        for (var row = 0; row < ChallengeResponseGrid.rowCount; row++)
          _bodyTableRow(grid: grid, row: row),
      ],
    );
  }

  static pw.TableRow _headerTableRow({required ChallengeResponseGrid grid}) {
    return pw.TableRow(
      decoration: const pw.BoxDecoration(color: PdfColors.grey200),
      children: <pw.Widget>[
        _headerCell(''),
        for (final col in grid.colLabels) _headerCell(col),
      ],
    );
  }

  static pw.Widget _headerCell(String text) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      alignment: pw.Alignment.center,
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: pw.FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  static pw.TableRow _bodyTableRow({
    required ChallengeResponseGrid grid,
    required int row,
  }) {
    return pw.TableRow(
      children: <pw.Widget>[
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 4),
          alignment: pw.Alignment.center,
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          child: pw.Text(
            grid.rowLabels[row],
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
        for (var col = 0; col < ChallengeResponseGrid.colCount; col++)
          _bodyCell(grid.cells[row][col]),
      ],
    );
  }

  static pw.Widget _bodyCell(List<String> words) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: <pw.Widget>[
          for (final word in words)
            pw.Text(
              word,
              style: const pw.TextStyle(fontSize: 8),
              textAlign: pw.TextAlign.center,
            ),
        ],
      ),
    );
  }

  static pw.Widget _footer() {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      child: pw.Text(
        'Signet - challenge-response v1',
        style: const pw.TextStyle(
          fontSize: 8,
          color: PdfColors.grey600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
