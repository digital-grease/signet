import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:signet/features/pairing/pairing_codec.dart';

void main() {
  final validKey = Uint8List.fromList(
    List<int>.generate(32, (i) => i * 7 & 0xFF),
  );

  group('PairingCodec', () {
    test('round trip preserves the key bytes', () {
      final payload = PairingCodec.encodePublicKey(validKey);
      final decoded = PairingCodec.decodePublicKey(payload);
      expect(decoded, equals(validKey));
    });

    test('payload is compact and starts with the Signet pairing prefix', () {
      final payload = PairingCodec.encodePublicKey(validKey);
      expect(payload, startsWith('signet:p1:'));
      expect(payload.length, lessThan(60));
    });

    test('rejects wrong key length on encode', () {
      expect(
        () => PairingCodec.encodePublicKey(List<int>.filled(31, 0)),
        throwsArgumentError,
      );
      expect(
        () => PairingCodec.encodePublicKey(List<int>.filled(64, 0)),
        throwsArgumentError,
      );
    });

    test('rejects payloads without the scheme prefix', () {
      expect(
        () => PairingCodec.decodePublicKey('https://example.com/foo'),
        throwsFormatException,
      );
      expect(
        () => PairingCodec.decodePublicKey('random text'),
        throwsFormatException,
      );
    });

    test('rejects payloads with the wrong version', () {
      expect(
        () => PairingCodec.decodePublicKey('signet:p2:AAAA'),
        throwsFormatException,
      );
    });

    test('rejects payloads that decode to the wrong length', () {
      // Valid prefix + base64 that yields 31 bytes.
      final short = List<int>.filled(31, 0);
      final payload = 'signet:p1:${_unpaddedBase64(short)}';
      expect(
        () => PairingCodec.decodePublicKey(payload),
        throwsFormatException,
      );
    });

    test('rejects malformed base64 after the prefix', () {
      expect(
        () => PairingCodec.decodePublicKey('signet:p1:!!!not-base64!!!'),
        throwsFormatException,
      );
    });
  });
}

String _unpaddedBase64(List<int> bytes) {
  const chars =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_';
  final buf = StringBuffer();
  var value = 0;
  var bits = 0;
  for (final b in bytes) {
    value = (value << 8) | (b & 0xFF);
    bits += 8;
    while (bits >= 6) {
      bits -= 6;
      buf.write(chars[(value >> bits) & 0x3F]);
    }
  }
  if (bits > 0) {
    buf.write(chars[(value << (6 - bits)) & 0x3F]);
  }
  return buf.toString();
}
