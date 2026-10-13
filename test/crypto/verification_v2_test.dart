import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signet/core/crypto/bip39_english_wordlist.dart';
import 'package:signet/core/crypto/verification.dart';

String _hex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

Uint8List _unhex(String s) => Uint8List.fromList([
      for (var i = 0; i < s.length; i += 2)
        int.parse(s.substring(i, i + 2), radix: 16),
    ]);

/// Independent 11-bits-per-word mapping (MSB first), so the in-person
/// composition check does not reuse the implementation's own mapper.
List<String> _words(List<int> bytes, int n) {
  final bits = bytes.map((b) => b.toRadixString(2).padLeft(8, '0')).join();
  return [
    for (var i = 0; i < n; i++)
      bip39EnglishWordlist[
          int.parse(bits.substring(i * 11, i * 11 + 11), radix: 2)],
  ];
}

/// Cheap Argon2id parameters for property tests that do not pin vectors.
const _fast = PhraseKdfParams(memoryKiB: 64, iterations: 1);

void main() {
  // Reference inputs. Expected values were computed independently with
  // Python's hashlib/hmac (RFC 5869 HKDF), and the Argon2id output with the
  // reference implementation's CLI:
  //   argon2 "$(cat salt)" -id -t 2 -k 19456 -p 1 -l 6 -r < ikm
  // (the salt has no zero or newline bytes, so it passes as an argument).
  final pubA = Uint8List.fromList(List<int>.generate(32, (i) => i));
  final pubB = Uint8List.fromList(List<int>.generate(32, (i) => 32 + i));
  final secret = Uint8List.fromList(List<int>.generate(32, (i) => 100 + i));
  final nonce = Uint8List.fromList(List<int>.generate(16, (i) => 200 + i));
  const saltQrHex =
      'b788ce6febb6da4f9acd9d915b6e6f3ee3b6424dfd2cc1f363cff6ec9315f3e3';
  const ikmQrHex =
      '59094ddf031610b711147a93fff5a3bdce070934b4ff8f4f70bc704eee8d38ad';
  const argonQrHex = 'e5c24bc281a5';
  const qrWords = ['total', 'banner', 'vague', 'addict'];
  const saltLdpHex =
      'dbb7120c7e6bb11da72d08814a178dd23cc8bc4a2621b0223c8cd340a1cd4a81';
  const ldpWords = [
    'impose', 'spot', 'obscure', 'trim', //
    'eternal', 'skull', 'chronic', 'bid',
  ];

  // Two keys equal except in the last byte, so any ordering that does not
  // compare every byte puts them in a different order on the two phones.
  final nearA = Uint8List.fromList(List<int>.generate(32, (i) => 7));
  final nearB = Uint8List.fromList(nearA)..[31] = 8;

  test('Argon2id implementation matches RFC 9106 section 5.3', () async {
    const algo = DartArgon2id(
      parallelism: 4,
      memory: 32,
      iterations: 3,
      hashLength: 32,
    );
    final tag = await algo.deriveKey(
      secretKey: SecretKey(List<int>.filled(32, 0x01)),
      nonce: List<int>.filled(16, 0x02),
      optionalSecret: List<int>.filled(8, 0x03),
      associatedData: List<int>.filled(12, 0x04),
    );
    expect(
      _hex(await tag.extractBytes()),
      '0d640df58d78766c08c037a34a8b53c9d01ef0452d75b65eb52520e96b01e659',
    );
  });

  test('v1 phrase is unchanged (pinned; the binding-phrase check uses it)',
      () async {
    expect(
      await PairingVerification.derivePhrase(sharedSecret: secret),
      ['place', 'room', 'learn', 'run'],
    );
  });

  group('PairingVerification.transcriptSalt', () {
    test('in person: SHA-256(domain || low || high || nonce)', () async {
      expect(
        _hex(await PairingVerification.transcriptSalt(pubA, pubB, nonce)),
        saltQrHex,
      );
      expect(
        _hex(await PairingVerification.transcriptSalt(pubB, pubA, nonce)),
        saltQrHex,
      );
    });

    test('long distance: SHA-256(domain || low || high)', () async {
      expect(_hex(await PairingVerification.transcriptSalt(pubA, pubB)),
          saltLdpHex);
      expect(_hex(await PairingVerification.transcriptSalt(pubB, pubA)),
          saltLdpHex);
    });

    test('orders keys that differ only in the last byte the same way',
        () async {
      expect(
        await PairingVerification.transcriptSalt(nearA, nearB, nonce),
        await PairingVerification.transcriptSalt(nearB, nearA, nonce),
      );
    });

    test('rejects keys that are not 32 bytes, either argument', () {
      expect(
        () => PairingVerification.transcriptSalt(pubA.sublist(1), pubB),
        throwsArgumentError,
      );
      expect(
        () => PairingVerification.transcriptSalt(pubA, pubB.sublist(1)),
        throwsArgumentError,
      );
      expect(
        () => PairingVerification.transcriptSalt(
          pubA,
          Uint8List.fromList([...pubB, 0]),
        ),
        throwsArgumentError,
      );
    });

    test('rejects a nonce that is neither empty nor 16 bytes', () {
      expect(
        () => PairingVerification.transcriptSalt(pubA, pubB, nonce.sublist(1)),
        throwsArgumentError,
      );
    });
  });

  group('PairingVerification.deriveLongDistancePhrase', () {
    test('matches the reference 8 words', () async {
      final words = await PairingVerification.deriveLongDistancePhrase(
        sharedSecret: secret,
        ownPublicKey: pubA,
        peerPublicKey: pubB,
      );
      expect(words, ldpWords);
    });

    test('is the same on both phones, even for near-identical keys',
        () async {
      for (final (x, y) in [(pubA, pubB), (nearA, nearB)]) {
        final mine = await PairingVerification.deriveLongDistancePhrase(
          sharedSecret: secret,
          ownPublicKey: x,
          peerPublicKey: y,
        );
        final theirs = await PairingVerification.deriveLongDistancePhrase(
          sharedSecret: secret,
          ownPublicKey: y,
          peerPublicKey: x,
        );
        expect(mine, theirs);
      }
    });

    test('changes with the transcript (a substituted key)', () async {
      final other = Uint8List.fromList(pubB)..[0] ^= 1;
      final a = await PairingVerification.deriveLongDistancePhrase(
        sharedSecret: secret,
        ownPublicKey: pubA,
        peerPublicKey: pubB,
      );
      final b = await PairingVerification.deriveLongDistancePhrase(
        sharedSecret: secret,
        ownPublicKey: pubA,
        peerPublicKey: other,
      );
      expect(a, isNot(equals(b)));
    });
  });

  group('PairingVerification.deriveInPersonPhrase', () {
    test('production KDF parameters are pinned', () {
      const p = PairingVerification.inPersonKdf;
      expect(p.memoryKiB, 19456);
      expect(p.iterations, 2);
      expect(p.parallelism, 1);
    });

    test('matches the reference phrase at production parameters', () async {
      final words = await PairingVerification.deriveInPersonPhrase(
        sharedSecret: secret,
        ownPublicKey: pubA,
        peerPublicKey: pubB,
        nonce: nonce,
      );
      expect(words, qrWords);
      // Same words from the reference Argon2id output.
      expect(_words(_unhex(argonQrHex), 4), qrWords);
    });

    test('is HKDF(qr domain) then Argon2id over the transcript salt',
        () async {
      // Chain the independent salt and HKDF output through Argon2id.
      const p = PairingVerification.inPersonKdf;
      final argon = DartArgon2id(
        parallelism: p.parallelism,
        memory: p.memoryKiB,
        iterations: p.iterations,
        hashLength: 6,
      );
      final out = await (await argon.deriveKey(
        secretKey: SecretKey(_unhex(ikmQrHex)),
        nonce: _unhex(saltQrHex),
      ))
          .extractBytes();
      expect(_hex(out), argonQrHex);
    });

    test('is the same on both phones, even for near-identical keys',
        () async {
      for (final (x, y) in [(pubA, pubB), (nearA, nearB)]) {
        final mine = await PairingVerification.deriveInPersonPhraseWithParams(
          sharedSecret: secret,
          ownPublicKey: x,
          peerPublicKey: y,
          nonce: nonce,
          params: _fast,
        );
        final theirs =
            await PairingVerification.deriveInPersonPhraseWithParams(
          sharedSecret: secret,
          ownPublicKey: y,
          peerPublicKey: x,
          nonce: nonce,
          params: _fast,
        );
        expect(mine, theirs);
      }
    });

    test('changes with the nonce', () async {
      final other = Uint8List.fromList(nonce)..[15] ^= 1;
      final a = await PairingVerification.deriveInPersonPhraseWithParams(
        sharedSecret: secret,
        ownPublicKey: pubA,
        peerPublicKey: pubB,
        nonce: nonce,
        params: _fast,
      );
      final b = await PairingVerification.deriveInPersonPhraseWithParams(
        sharedSecret: secret,
        ownPublicKey: pubA,
        peerPublicKey: pubB,
        nonce: other,
        params: _fast,
      );
      expect(a, isNot(equals(b)));
    });

    test('rejects a nonce that is not 16 bytes and an empty secret', () {
      expect(
        () => PairingVerification.deriveInPersonPhrase(
          sharedSecret: secret,
          ownPublicKey: pubA,
          peerPublicKey: pubB,
          nonce: nonce.sublist(1),
        ),
        throwsArgumentError,
      );
      expect(
        () => PairingVerification.deriveInPersonPhrase(
          sharedSecret: const <int>[],
          ownPublicKey: pubA,
          peerPublicKey: pubB,
          nonce: nonce,
        ),
        throwsArgumentError,
      );
    });
  });

  test('domains are separated: v1, in person and long distance differ',
      () async {
    final v1 = await PairingVerification.derivePhrase(sharedSecret: secret);
    final ldp = await PairingVerification.deriveLongDistancePhrase(
      sharedSecret: secret,
      ownPublicKey: pubA,
      peerPublicKey: pubB,
    );
    expect(qrWords, isNot(equals(v1)));
    expect(ldp.sublist(0, 4), isNot(equals(v1)));
    expect(ldp.sublist(0, 4), isNot(equals(qrWords)));
  });
}
