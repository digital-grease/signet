import 'dart:convert';
import 'dart:typed_data';

/// Wire format for Signet pairing QR codes.
///
/// Format: `signet:p1:<base64url(publicKey)>`
///   - `signet:` fixed scheme
///   - `p1`     pairing wire version 1
///   - the base64url-encoded 32-byte X25519 public key
///
/// `base64url` with no padding keeps the payload short (~44 chars) and
/// avoids `+` / `/` characters that tend to break encoders downstream.
class PairingCodec {
  const PairingCodec._();

  static const String _prefix = 'signet:p1:';

  static String encodePublicKey(List<int> publicKey) {
    if (publicKey.length != 32) {
      throw ArgumentError.value(
        publicKey.length,
        'publicKey.length',
        'X25519 public keys must be exactly 32 bytes.',
      );
    }
    final encoded = base64Url.encode(publicKey).replaceAll('=', '');
    return '$_prefix$encoded';
  }

  /// Returns the 32-byte public key, or throws [FormatException] if
  /// the payload is not a valid Signet v1 pairing QR.
  static Uint8List decodePublicKey(String payload) {
    if (!payload.startsWith(_prefix)) {
      throw const FormatException(
        'Not a Signet pairing QR (wrong scheme / version).',
      );
    }
    final body = payload.substring(_prefix.length);
    final padded = _padBase64(body);
    try {
      final bytes = base64Url.decode(padded);
      if (bytes.length != 32) {
        throw FormatException(
          'Decoded payload is ${bytes.length} bytes, expected 32.',
        );
      }
      return Uint8List.fromList(bytes);
    } on FormatException {
      rethrow;
    } catch (error) {
      throw FormatException('Could not decode pairing QR: $error');
    }
  }

  static String _padBase64(String input) {
    final padding = (4 - input.length % 4) % 4;
    return input + '=' * padding;
  }
}
