import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:signet/features/pairing/pairing_code_v2.dart';

String _b64(List<int> bytes) => base64Url.encode(bytes).replaceAll('=', '');

Matcher _failsWith(PairingCodeError reason) => throwsA(
      isA<PairingCodeException>().having((e) => e.reason, 'reason', reason),
    );

void main() {
  final key = Uint8List.fromList(List<int>.generate(32, (i) => i * 7 & 0x7F));
  final commitment = Uint8List.fromList(List<int>.generate(32, (i) => 255 - i));
  final nonce = Uint8List.fromList(List<int>.generate(16, (i) => 100 + i));

  group('encode', () {
    test('uses signet:p2:<kind>:<base64url> with no padding', () {
      expect(PairingCodeV2.encodeCommit(commitment),
          'signet:p2:C:${_b64(commitment)}');
      expect(PairingCodeV2.encodeKey(key), 'signet:p2:K:${_b64(key)}');
      expect(
        PairingCodeV2.encodeReveal(publicKey: key, nonce: nonce),
        'signet:p2:R:${_b64([...key, ...nonce])}',
      );
      expect(PairingCodeV2.encodeKey(key), isNot(contains('=')));
    });

    test('rejects wrong lengths and keys with the top bit set', () {
      expect(() => PairingCodeV2.encodeCommit(commitment.sublist(1)),
          throwsArgumentError);
      expect(() => PairingCodeV2.encodeKey(key.sublist(1)),
          throwsArgumentError);
      expect(
        () => PairingCodeV2.encodeReveal(
            publicKey: key, nonce: nonce.sublist(1)),
        throwsArgumentError,
      );
      final highBit = Uint8List.fromList(key)..[31] |= 0x80;
      expect(() => PairingCodeV2.encodeKey(highBit), throwsArgumentError);
    });
  });

  group('decode round trips', () {
    test('commit', () {
      final code = PairingCodeV2.decode(PairingCodeV2.encodeCommit(commitment));
      expect(code, isA<CommitCode>());
      expect((code as CommitCode).commitment, commitment);
    });

    test('key', () {
      final code = PairingCodeV2.decode(PairingCodeV2.encodeKey(key));
      expect((code as KeyCode).publicKey, key);
    });

    test('reveal', () {
      final code = PairingCodeV2.decode(
          PairingCodeV2.encodeReveal(publicKey: key, nonce: nonce));
      code as RevealCode;
      expect(code.publicKey, key);
      expect(code.nonce, nonce);
    });

    test('whitespace and zero-width characters from a paste are ignored', () {
      final good = PairingCodeV2.encodeKey(key);
      final mid = good.length ~/ 2;
      for (final pasted in [
        '  $good\n',
        '​$good​',
        '﻿$good',
        '${good.substring(0, mid)}\n${good.substring(mid)}',
        '${good.substring(0, mid)}  ${good.substring(mid)}',
      ]) {
        final code = PairingCodeV2.decode(pasted);
        expect((code as KeyCode).publicKey, key);
      }
    });

    test('a nonce byte with the high bit set is fine (only the key is checked)',
        () {
      final highNonce = Uint8List.fromList(nonce)..[15] = 0xFF;
      final code = PairingCodeV2.decode(
          PairingCodeV2.encodeReveal(publicKey: key, nonce: highNonce));
      expect((code as RevealCode).nonce, highNonce);
    });
  });

  group('decode failures are typed, never other exceptions', () {
    test('an older Signet pairing code (p1) means the other phone is older',
        () {
      expect(
        () => PairingCodeV2.decode('signet:p1:${_b64(key)}'),
        _failsWith(PairingCodeError.peerNeedsUpdate),
      );
    });

    test('a newer version or an unknown kind means this phone is older', () {
      for (final s in [
        'signet:p3:K:${_b64(key)}',
        'signet:p10:K:${_b64(key)}',
        'signet:p99999999999999999999:K:${_b64(key)}', // too long to parse
        'signet:p2:Z:${_b64(key)}', // a kind a later Signet added
      ]) {
        expect(() => PairingCodeV2.decode(s),
            _failsWith(PairingCodeError.thisNeedsUpdate),
            reason: s);
      }
    });

    test('more than one code in a paste', () {
      final all = [
        PairingCodeV2.encodeCommit(commitment),
        PairingCodeV2.encodeKey(key),
      ].join('\n');
      expect(() => PairingCodeV2.decode(all),
          _failsWith(PairingCodeError.multipleCodes));
    });

    test('anything else is not a pairing code', () {
      for (final s in [
        '',
        'random text',
        'https://example.com/',
        'signet:tp1:AAAA',
        'SIGNET:p2:K:${_b64(key)}',
        'signet:p02:K:${_b64(key)}', // never a version this format wrote
      ]) {
        expect(() => PairingCodeV2.decode(s),
            _failsWith(PairingCodeError.notAPairingCode),
            reason: s);
      }
    });

    test('a damaged p2 code is malformed', () {
      final highBit = Uint8List.fromList(key)..[31] |= 0x80;
      for (final s in [
        'signet:p2:K:',
        'signet:p2:K',
        'signet:p2:K:!!!not-base64!!!',
        'signet:p2:K:${_b64(key.sublist(1))}', // 31 bytes
        'signet:p2:K:${_b64([...key, 0])}', // 33 bytes
        'signet:p2:C:${_b64(commitment.sublist(1))}',
        'signet:p2:R:${_b64(key)}', // reveal without the nonce
        'signet:p2:R:${_b64([...key, ...nonce, 0])}',
        'signet:p2:K:${_b64(highBit)}', // non-canonical key encoding
        'signet:p2:R:${_b64([...highBit, ...nonce])}',
        'signet:p2:K:${_b64(key)}:extra',
        'signet:p2:K${_b64(key)}', // no separator after the kind
        'signet:p2:K-${_b64(key)}', // wrong separator, valid body after it
        'signet:p2:k:${_b64(key)}', // case-folded kind
        'signet:p2:?:${_b64(key)}',
      ]) {
        expect(() => PairingCodeV2.decode(s),
            _failsWith(PairingCodeError.malformed),
            reason: s);
      }
    });

    test('only the canonical spelling decodes (one spelling per code)', () {
      // A body with '-' and '_' so the standard alphabet differs.
      final k = Uint8List.fromList(List<int>.filled(32, 0x3E)..[31] = 0x7F);
      final good = PairingCodeV2.encodeKey(k);
      expect(good, contains(RegExp('[-_]')));
      expect((PairingCodeV2.decode(good) as KeyCode).publicKey, k);
      final body = good.substring('signet:p2:K:'.length);
      final standard = body.replaceAll('-', '+').replaceAll('_', '/');
      for (final s in [
        'signet:p2:K:$standard', // standard alphabet
        'signet:p2:K:$body=', // explicit padding
      ]) {
        expect(() => PairingCodeV2.decode(s),
            _failsWith(PairingCodeError.malformed),
            reason: s);
      }
    });
  });

  test('fuzz: decode only ever succeeds or throws PairingCodeException', () {
    final rng = Random(20261010); // seeded: reproducible in CI
    final valid = [
      PairingCodeV2.encodeCommit(commitment),
      PairingCodeV2.encodeKey(key),
      PairingCodeV2.encodeReveal(publicKey: key, nonce: nonce),
    ];
    const alphabet = 'signet:p12CKRZ-_+/=AbXyz09 \n​ ';
    for (var i = 0; i < 20000; i++) {
      final String input;
      if (i.isEven) {
        // A valid code with one character replaced, inserted or deleted.
        final base = valid[rng.nextInt(valid.length)];
        final at = rng.nextInt(base.length);
        final ch = alphabet[rng.nextInt(alphabet.length)];
        input = switch (rng.nextInt(3)) {
          0 => base.replaceRange(at, at + 1, ch),
          1 => base.replaceRange(at, at, ch),
          _ => base.replaceRange(at, at + 1, ''),
        };
      } else {
        // Random code units, including lone surrogates.
        input = String.fromCharCodes(List<int>.generate(
            rng.nextInt(90), (_) => rng.nextInt(0x10000)));
      }
      try {
        PairingCodeV2.decode(input);
      } on PairingCodeException {
        // expected
      } catch (e) {
        fail('decode(${jsonEncode(input)}) threw ${e.runtimeType}: $e');
      }
    }
  });
}
