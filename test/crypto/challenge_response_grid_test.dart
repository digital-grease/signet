import 'package:flutter_test/flutter_test.dart';
import 'package:signet/core/crypto/bip39_english_wordlist.dart';
import 'package:signet/core/crypto/challenge_response_grid.dart';
import 'package:signet/core/crypto/verification.dart';

void main() {
  final secret = List<int>.generate(32, (i) => i + 1);

  group('ChallengeResponseGrid.derive', () {
    test('produces 8 row labels, 8 col labels, 8x8 cells of 3 words each',
        () async {
      final grid = await ChallengeResponseGrid.derive(secret);
      expect(grid.rowLabels, hasLength(8));
      expect(grid.colLabels, hasLength(8));
      expect(grid.cells, hasLength(8));
      for (final row in grid.cells) {
        expect(row, hasLength(8));
        for (final cell in row) {
          expect(cell, hasLength(3));
        }
      }
    });

    test('all 16 axis labels are distinct and in the BIP-39 wordlist',
        () async {
      final grid = await ChallengeResponseGrid.derive(secret);
      final all = <String>{...grid.rowLabels, ...grid.colLabels};
      expect(all.length, 16, reason: 'no duplicates across rows + cols');
      for (final w in all) {
        expect(bip39EnglishWordlist.contains(w), isTrue);
      }
    });

    test('every cell word is in the BIP-39 wordlist', () async {
      final grid = await ChallengeResponseGrid.derive(secret);
      for (final row in grid.cells) {
        for (final cell in row) {
          for (final word in cell) {
            expect(bip39EnglishWordlist.contains(word), isTrue);
          }
        }
      }
    });

    test('is deterministic — same secret produces identical grid', () async {
      final a = await ChallengeResponseGrid.derive(secret);
      final b = await ChallengeResponseGrid.derive(secret);
      expect(a.rowLabels, b.rowLabels);
      expect(a.colLabels, b.colLabels);
      expect(a.cells, b.cells);
    });

    test('different secrets produce different grids', () async {
      final a = await ChallengeResponseGrid.derive(secret);
      final b = await ChallengeResponseGrid.derive(
        List<int>.generate(32, (i) => i + 2),
      );
      // At minimum the axis labels should differ (cell contents almost
      // certainly do too, but labels are a cheap structural check).
      expect(a.rowLabels == b.rowLabels, isFalse);
    });

    test('rejects empty shared secret', () async {
      await expectLater(
        ChallengeResponseGrid.derive(const <int>[]),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('is the same grid regardless of which half of the pair derives',
        () async {
      // The grid must be pair-symmetric: device A and device B see the
      // same 8×8 table. Emulate this with two derivations from the same
      // bytes.
      final fromA = await ChallengeResponseGrid.derive(secret);
      final fromB = await ChallengeResponseGrid.derive(secret);
      expect(fromA.rowLabels, fromB.rowLabels);
      expect(fromA.cells, fromB.cells);
    });
  });

  group('ChallengeResponseGrid.answerFor', () {
    test('returns the cell matching the label coordinate', () async {
      final grid = await ChallengeResponseGrid.derive(secret);
      final answer = grid.answerFor(
        rowLabel: grid.rowLabels[3],
        colLabel: grid.colLabels[5],
      );
      expect(answer, grid.cells[3][5]);
    });

    test('throws ArgumentError on unknown row label', () async {
      final grid = await ChallengeResponseGrid.derive(secret);
      expect(
        () => grid.answerFor(
          rowLabel: 'abandon', // not in the derived row labels
          colLabel: grid.colLabels.first,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws ArgumentError on unknown col label', () async {
      final grid = await ChallengeResponseGrid.derive(secret);
      expect(
        () => grid.answerFor(
          rowLabel: grid.rowLabels.first,
          colLabel: 'abandon',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('domain separation', () {
    test(
      'cells do not accidentally collide with the pair-time phrase or any '
      'TOTP-words window (4 BIP-39 words) for the same secret',
      () async {
        final grid = await ChallengeResponseGrid.derive(secret);
        final pairTime = await PairingVerification.derivePhrase(
          sharedSecret: secret,
        );

        // Put the first 3 words of the pair-time phrase next to every
        // 3-word cell — they must never match.
        final pairTimeFirstThree = pairTime.take(3).toList();
        for (final row in grid.cells) {
          for (final cell in row) {
            expect(
              cell,
              isNot(pairTimeFirstThree),
              reason:
                  'grid cells must be domain-separated from pair-time phrase',
            );
          }
        }

        // Full TOTP domain-separation sweep lives in totp_words_test.dart;
        // this spike-level test is only validating that the CR grid's new
        // HKDF info strings don't collide with the pair-time phrase.
      },
    );
  });

  group('immutability', () {
    test('rowLabels is an unmodifiable list', () async {
      final grid = await ChallengeResponseGrid.derive(secret);
      expect(() => grid.rowLabels.add('hack'), throwsUnsupportedError);
    });

    test('cells[row][col] is an unmodifiable list', () async {
      final grid = await ChallengeResponseGrid.derive(secret);
      expect(() => grid.cells[0][0].add('hack'), throwsUnsupportedError);
    });
  });

}
