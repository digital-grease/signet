import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:signet/core/crypto/totp.dart';

void main() {
  // RFC 6238 Appendix B test vectors, HMAC-SHA-256 variant.
  // Secret = ASCII "12345678901234567890123456789012" (32 bytes).
  // T0 = 0, time step = 30 s, output = 8 digits.
  final secret = utf8.encode('12345678901234567890123456789012');

  group('Totp.generate — RFC 6238 Appendix B (SHA-256, 8 digits)', () {
    final vectors = <int, String>{
      59: '46119246',
      1111111109: '68084774',
      1111111111: '67062674',
      1234567890: '91819424',
      2000000000: '90698825',
      20000000000: '77737706',
    };

    vectors.forEach((unixTime, expected) {
      test('T=$unixTime → $expected', () async {
        final actual = await Totp.generate(
          secret: secret,
          unixTimeSeconds: unixTime,
        );
        expect(actual, expected);
      });
    });
  });

  group('Totp.verify', () {
    test('accepts the exact current code', () async {
      const t = 1111111109;
      final code = await Totp.generate(secret: secret, unixTimeSeconds: t);
      expect(
        await Totp.verify(secret: secret, candidate: code, unixTimeSeconds: t),
        isTrue,
      );
    });

    test('accepts a code from one window in the past (tolerance ±1)', () async {
      const t = 1111111109;
      final prev = await Totp.generate(secret: secret, unixTimeSeconds: t - 30);
      expect(
        await Totp.verify(secret: secret, candidate: prev, unixTimeSeconds: t),
        isTrue,
      );
    });

    test('accepts a code from one window in the future (tolerance ±1)', () async {
      const t = 1111111109;
      final next = await Totp.generate(secret: secret, unixTimeSeconds: t + 30);
      expect(
        await Totp.verify(secret: secret, candidate: next, unixTimeSeconds: t),
        isTrue,
      );
    });

    test('rejects a code from two windows in the past (outside tolerance)', () async {
      const t = 1111111109;
      final old = await Totp.generate(secret: secret, unixTimeSeconds: t - 60);
      expect(
        await Totp.verify(secret: secret, candidate: old, unixTimeSeconds: t),
        isFalse,
      );
    });

    test('rejects a wrong code', () async {
      expect(
        await Totp.verify(
          secret: secret,
          candidate: '00000000',
          unixTimeSeconds: 1111111109,
        ),
        isFalse,
      );
    });

    test('rejects a code of the wrong length', () async {
      expect(
        await Totp.verify(
          secret: secret,
          candidate: '123456',
          unixTimeSeconds: 1111111109,
        ),
        isFalse,
      );
    });

    test('honors a wider window tolerance when requested', () async {
      const t = 1111111109;
      final twoBack = await Totp.generate(
        secret: secret,
        unixTimeSeconds: t - 60,
      );
      expect(
        await Totp.verify(
          secret: secret,
          candidate: twoBack,
          unixTimeSeconds: t,
          windowTolerance: 2,
        ),
        isTrue,
      );
    });
  });

  group('Totp time-step arithmetic', () {
    test('codes are stable across a single 30 s window', () async {
      final a = await Totp.generate(secret: secret, unixTimeSeconds: 0);
      final b = await Totp.generate(secret: secret, unixTimeSeconds: 29);
      expect(a, b);
    });

    test('codes change at the window boundary', () async {
      final a = await Totp.generate(secret: secret, unixTimeSeconds: 29);
      final b = await Totp.generate(secret: secret, unixTimeSeconds: 30);
      expect(a, isNot(b));
    });
  });
}
