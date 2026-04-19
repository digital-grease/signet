import 'package:flutter_test/flutter_test.dart';
import 'package:signet/core/crypto/challenge_response_grid.dart';
import 'package:signet/features/inspect/cr_grid_pdf.dart';

void main() {
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
