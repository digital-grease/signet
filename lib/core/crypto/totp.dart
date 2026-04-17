import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// RFC 6238 TOTP with HMAC-SHA-256, 8-digit output, 30-second steps.
///
/// Pure-function API. Inputs are raw bytes and Unix times (seconds);
/// no `dart:async` outside awaiting `cryptography`, no Flutter dependencies.
/// Verification walks a configurable window on either side of the current
/// step to tolerate clock drift and human reaction time.
class Totp {
  const Totp._();

  static const int defaultTimeStepSeconds = 30;
  static const int defaultDigits = 8;
  static const int defaultWindowTolerance = 1;

  static Future<String> generate({
    required List<int> secret,
    required int unixTimeSeconds,
    int timeStepSeconds = defaultTimeStepSeconds,
    int digits = defaultDigits,
  }) {
    final counter = unixTimeSeconds ~/ timeStepSeconds;
    return _hotp(secret: secret, counter: counter, digits: digits);
  }

  static Future<bool> verify({
    required List<int> secret,
    required String candidate,
    required int unixTimeSeconds,
    int timeStepSeconds = defaultTimeStepSeconds,
    int digits = defaultDigits,
    int windowTolerance = defaultWindowTolerance,
  }) async {
    if (candidate.length != digits) return false;
    final baseCounter = unixTimeSeconds ~/ timeStepSeconds;
    for (var offset = -windowTolerance; offset <= windowTolerance; offset++) {
      final expected = await _hotp(
        secret: secret,
        counter: baseCounter + offset,
        digits: digits,
      );
      if (_constantTimeEquals(expected, candidate)) return true;
    }
    return false;
  }

  static Future<String> _hotp({
    required List<int> secret,
    required int counter,
    required int digits,
  }) async {
    final counterBytes = _encodeCounter(counter);
    final mac = await Hmac.sha256().calculateMac(
      counterBytes,
      secretKey: SecretKey(secret),
    );
    final bytes = mac.bytes;
    final offset = bytes[bytes.length - 1] & 0x0F;
    final truncated = ((bytes[offset] & 0x7F) << 24) |
        ((bytes[offset + 1] & 0xFF) << 16) |
        ((bytes[offset + 2] & 0xFF) << 8) |
        (bytes[offset + 3] & 0xFF);
    final code = truncated % _powerOfTen(digits);
    return code.toString().padLeft(digits, '0');
  }

  static Uint8List _encodeCounter(int counter) {
    final bytes = Uint8List(8);
    var value = counter;
    for (var i = 7; i >= 0; i--) {
      bytes[i] = value & 0xFF;
      value >>= 8;
    }
    return bytes;
  }

  static int _powerOfTen(int digits) {
    var result = 1;
    for (var i = 0; i < digits; i++) {
      result *= 10;
    }
    return result;
  }

  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }
}
