// One secret rendered in every shipped list (v0.5.0 plan Task 1.2): every
// derivation picks indices, and a list only spells them. The English
// renderings stay exactly v0.4.0's (pinned by the snapshot vectors in
// totp_words_test.dart, verification_test.dart, verification_v2_test.dart
// and challenge_response_grid_test.dart); this file checks that every
// other list spells the same indices.

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:signet/core/crypto/challenge_response_grid.dart';
import 'package:signet/core/crypto/pair_role.dart';
import 'package:signet/core/crypto/totp_words.dart';
import 'package:signet/core/crypto/transport_package.dart';
import 'package:signet/core/crypto/verification.dart';
import 'package:signet/core/crypto/wordlists.dart';

void main() {
  final secret = List<int>.generate(32, (i) => i * 7 + 3);
  final own = List<int>.generate(32, (i) => i + 1);
  final peer = List<int>.generate(32, (i) => 200 - i);
  final nonce = List<int>.generate(16, (i) => i);
  const cheap = PhraseKdfParams(memoryKiB: 64, iterations: 1);
  final english = WordList.english;
  final others = [
    for (final l in WordList.shipped)
      if (l != english) l,
  ];

  List<int> indicesOf(List<String> words) =>
      [for (final w in words) english.indexOf(w)!];

  test('English is the default rendering everywhere', () async {
    expect(
      await TotpWords.generate(
          secret: secret, unixTimeSeconds: 1000, senderRole: PairRole.a),
      await TotpWords.generate(
          secret: secret,
          unixTimeSeconds: 1000,
          senderRole: PairRole.a,
          list: english),
    );
    expect(
      await PairingVerification.derivePhrase(sharedSecret: secret),
      await PairingVerification.derivePhrase(
          sharedSecret: secret, list: english),
    );
    final grid = await ChallengeResponseGrid.derive(secret);
    final gridEn = await ChallengeResponseGrid.derive(secret, list: english);
    expect(grid.rowLabels, gridEn.rowLabels);
    expect(grid.colLabels, gridEn.colLabels);
    expect(grid.cells, gridEn.cells);
    expect(
      TransportPackage.mintPakeWords(random: Random(5)),
      TransportPackage.mintPakeWords(random: Random(5), list: english),
    );
  });

  test('generateIndices is what generate spells', () async {
    for (final role in PairRole.values) {
      final indices = await TotpWords.generateIndices(
          secret: secret, unixTimeSeconds: 1000, senderRole: role);
      for (final list in WordList.shipped) {
        expect(
          await TotpWords.generate(
              secret: secret,
              unixTimeSeconds: 1000,
              senderRole: role,
              list: list),
          list.render(indices),
        );
      }
    }
  });

  for (final list in others) {
    group('${list.id} spells the English indices', () {
      test('rotating words', () async {
        for (final role in PairRole.values) {
          for (final t in [0, 59, 1000, 1700000000]) {
            final en = await TotpWords.generate(
                secret: secret, unixTimeSeconds: t, senderRole: role);
            final other = await TotpWords.generate(
                secret: secret,
                unixTimeSeconds: t,
                senderRole: role,
                list: list);
            expect(other, list.render(indicesOf(en)));
          }
        }
      });

      test('pair-time phrases', () async {
        final v1 = await PairingVerification.derivePhrase(sharedSecret: secret);
        expect(
          await PairingVerification.derivePhrase(
              sharedSecret: secret, list: list),
          list.render(indicesOf(v1)),
        );
        final inPerson =
            await PairingVerification.deriveInPersonPhraseWithParams(
          sharedSecret: secret,
          ownPublicKey: own,
          peerPublicKey: peer,
          nonce: nonce,
          params: cheap,
        );
        expect(
          await PairingVerification.deriveInPersonPhraseWithParams(
            sharedSecret: secret,
            ownPublicKey: own,
            peerPublicKey: peer,
            nonce: nonce,
            params: cheap,
            list: list,
          ),
          list.render(indicesOf(inPerson)),
        );
        final ldp = await PairingVerification.deriveLongDistancePhrase(
            sharedSecret: secret, ownPublicKey: own, peerPublicKey: peer);
        expect(
          await PairingVerification.deriveLongDistancePhrase(
              sharedSecret: secret,
              ownPublicKey: own,
              peerPublicKey: peer,
              list: list),
          list.render(indicesOf(ldp)),
        );
      });

      test('in-person phrase at the production Argon2id cost', () async {
        Future<List<String>> derive(WordList? l) =>
            PairingVerification.deriveInPersonPhrase(
              sharedSecret: secret,
              ownPublicKey: own,
              peerPublicKey: peer,
              nonce: nonce,
              list: l,
            );
        expect(await derive(list), list.render(indicesOf(await derive(null))));
      });

      test('challenge grid', () async {
        final en = await ChallengeResponseGrid.derive(secret);
        final other = await ChallengeResponseGrid.derive(secret, list: list);
        expect(other.rowLabels, list.render(indicesOf(en.rowLabels)));
        expect(other.colLabels, list.render(indicesOf(en.colLabels)));
        for (var r = 0; r < ChallengeResponseGrid.rowCount; r++) {
          for (var c = 0; c < ChallengeResponseGrid.colCount; c++) {
            expect(other.cells[r][c], list.render(indicesOf(en.cells[r][c])));
          }
        }
        expect(
          other.answerFor(
              rowLabel: other.rowLabels[2], colLabel: other.colLabels[5]),
          other.cells[2][5],
        );
      });

      test('PAKE words, and they open what English words sealed', () async {
        final en = TransportPackage.mintPakeWords(random: Random(11));
        final other =
            TransportPackage.mintPakeWords(random: Random(11), list: list);
        expect(other, list.render(indicesOf(en)));
        expect(TransportPackage.normalizePakeWords(other), en);

        final wire = await TransportPackage.encodeLdp(
          publicKey: own,
          labelHint: 'Mom',
          pakeWords: other,
        );
        final opened =
            await TransportPackage.decodeLdp(wire, pakeWords: en);
        expect(opened.publicKey, own);
      });

      test('verify reads the words in the list it is given', () async {
        const t = 1000;
        const role = PairRole.b;
        final spelled = await TotpWords.generate(
            secret: secret, unixTimeSeconds: t, senderRole: role, list: list);
        expect(
          await TotpWords.verifyWindow(
              secret: secret,
              candidate: spelled,
              unixTimeSeconds: t,
              senderRole: role,
              list: list),
          TotpWords.counterFor(t),
        );
        final en = await TotpWords.generate(
            secret: secret, unixTimeSeconds: t, senderRole: role);
        // The English words read as French (or the reverse) are other
        // indices or no words at all: never a match.
        expect(
          await TotpWords.verify(
              secret: secret,
              candidate: en,
              unixTimeSeconds: t,
              senderRole: role,
              list: list),
          isFalse,
        );
        expect(
          await TotpWords.verify(
              secret: secret,
              candidate: spelled,
              unixTimeSeconds: t,
              senderRole: role),
          isFalse,
        );
      });
    });
  }

  group('WordList', () {
    test('byId finds every shipped list and nothing else', () {
      for (final l in WordList.shipped) {
        expect(WordList.byId(l.id), same(l));
      }
      expect(WordList.byId('zh-1'), same(WordList.zh1));
      expect(WordList.byId(''), isNull);
      expect(WordList.byId('EN'), isNull);
    });

    test('respell spells English words in each list, by index', () async {
      final phrase = await PairingVerification.deriveInPersonPhraseWithParams(
        sharedSecret: secret,
        ownPublicKey: own,
        peerPublicKey: peer,
        nonce: nonce,
        params: cheap,
      );
      for (final l in WordList.shipped) {
        expect(
          l.respell(phrase),
          await PairingVerification.deriveInPersonPhraseWithParams(
            sharedSecret: secret,
            ownPublicKey: own,
            peerPublicKey: peer,
            nonce: nonce,
            params: cheap,
            list: l,
          ),
        );
      }
      expect(() => english.respell(['élève']), throwsStateError);
    });

    test('render spells indices in order', () {
      for (final l in WordList.shipped) {
        expect(l.render([0, 2047, 5]),
            [l.wordAt(0), l.wordAt(2047), l.wordAt(5)]);
      }
    });
  });
}
