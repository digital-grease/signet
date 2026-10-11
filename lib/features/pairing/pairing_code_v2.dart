import 'dart:convert';
import 'dart:typed_data';

/// Why a scanned or pasted code could not be used. The UI maps each to its
/// own message; none of them is shown with the raw payload, and none links
/// anywhere (an "update" message must not become an "install this APK"
/// lure: update only from the store Signet came from).
enum PairingCodeError {
  /// Not a Signet pairing code at all (a URL, text, a backup package).
  notAPairingCode,

  /// A pairing code from an older Signet (`signet:p1:`). The other phone
  /// must update; there is no fallback to the old protocol (pairing-
  /// commitment spike, requirement 2).
  peerNeedsUpdate,

  /// A pairing code from a newer Signet (a later version, or a code kind
  /// this build does not know). This phone must update.
  thisNeedsUpdate,

  /// A `signet:p2:` code that is incomplete or damaged: bad encoding, wrong
  /// length, a key with the top bit set. Usually a broken paste; QR error
  /// correction makes a damaged scan rare. Copy must say "incomplete or
  /// damaged, try again", not "tampered", and a malformed input changes no
  /// pairing state.
  malformed,

  /// More than one Signet code in one paste. Paste one code at a time.
  multipleCodes,
}

class PairingCodeException implements Exception {
  const PairingCodeException(this.reason);

  final PairingCodeError reason;

  @override
  String toString() => 'PairingCodeException(${reason.name})';
}

/// A decoded `signet:p2:` code: one of the three transfers of the
/// commit-then-reveal pairing (plan Task 1.7). Compare codes by these
/// bytes, never by the scanned string.
sealed class PairingCode {
  const PairingCode();
}

/// Step 1, shown by Start: the commitment to Start's key and nonce.
final class CommitCode extends PairingCode {
  const CommitCode(this.commitment);
  final Uint8List commitment;
}

/// Step 2, shown by Join: Join's public key.
final class KeyCode extends PairingCode {
  const KeyCode(this.publicKey);
  final Uint8List publicKey;
}

/// Step 3, shown by Start: Start's public key and nonce, which must open
/// the step 1 commitment.
final class RevealCode extends PairingCode {
  const RevealCode({required this.publicKey, required this.nonce});
  final Uint8List publicKey;
  final Uint8List nonce;
}

/// Wire format for in-person pairing codes, version 2.
///
/// Format: `signet:p2:<kind>:<base64url, no padding>`, where kind is
///   - `C` commitment, 32 bytes
///   - `K` X25519 public key, 32 bytes
///   - `R` public key || nonce, 32 + 16 bytes
///
/// Exactly one spelling per code: the body must be canonical unpadded
/// base64url (no `+`, `/` or `=`, no stray trailing bits). Whitespace and
/// zero-width characters anywhere in the input are dropped first, since
/// messaging apps insert them when a code is pasted; a real code never
/// contains them.
///
/// Keys must have the top bit clear. X25519 ignores bit 255 while the
/// phrase transcript hashes the raw bytes, so this removes the cheapest way
/// to give two phones different transcripts for one shared secret. It is
/// not complete (a relay can still add a small-order point, which clamping
/// cancels), but every such change only makes the phrases differ: a denial
/// of service a man-in-the-middle can cause anyway, never a match.
///
/// Decoding never throws anything but [PairingCodeException], so a bad
/// scan becomes a clean, typed failure for the controller.
class PairingCodeV2 {
  const PairingCodeV2._();

  static const String _prefix = 'signet:p2:';
  static const String _v1Prefix = 'signet:p1:';
  static const int keyLength = 32;
  static const int commitmentLength = 32;
  static const int nonceLength = 16;

  // Whitespace (incl. NBSP, line breaks) and zero-width characters/BOM.
  static final RegExp _ignorable =
      RegExp('[\\s​-‍⁠﻿]', unicode: true);
  static final RegExp _version = RegExp(r'^signet:p([0-9]+):');

  static String encodeCommit(List<int> commitment) {
    _requireLength(commitment, commitmentLength, 'commitment');
    return '${_prefix}C:${_b64(commitment)}';
  }

  static String encodeKey(List<int> publicKey) {
    _requireKey(publicKey, 'publicKey');
    return '${_prefix}K:${_b64(publicKey)}';
  }

  static String encodeReveal({
    required List<int> publicKey,
    required List<int> nonce,
  }) {
    _requireKey(publicKey, 'publicKey');
    _requireLength(nonce, nonceLength, 'nonce');
    return '${_prefix}R:${_b64([...publicKey, ...nonce])}';
  }

  static PairingCode decode(String raw) {
    final payload = raw.replaceAll(_ignorable, '');
    if ('signet:'.allMatches(payload).length > 1) {
      throw const PairingCodeException(PairingCodeError.multipleCodes);
    }
    if (payload.startsWith(_v1Prefix)) {
      throw const PairingCodeException(PairingCodeError.peerNeedsUpdate);
    }
    if (!payload.startsWith(_prefix)) {
      final version = _version.firstMatch(payload)?.group(1);
      if (version != null && _isLaterVersion(version)) {
        throw const PairingCodeException(PairingCodeError.thisNeedsUpdate);
      }
      // A different Signet code (a backup package, say) or not Signet's.
      throw const PairingCodeException(PairingCodeError.notAPairingCode);
    }
    final rest = payload.substring(_prefix.length);
    if (rest.length < 2 || rest[1] != ':') _malformed();
    final kind = rest[0];
    final body = rest.substring(2);
    switch (kind) {
      case 'C':
        final bytes = _decodeBody(body);
        if (bytes.length != commitmentLength) _malformed();
        return CommitCode(bytes);
      case 'K':
        final bytes = _decodeBody(body);
        if (bytes.length != keyLength || !_canonical(bytes)) _malformed();
        return KeyCode(bytes);
      case 'R':
        final bytes = _decodeBody(body);
        if (bytes.length != keyLength + nonceLength) _malformed();
        final key = Uint8List.fromList(bytes.sublist(0, keyLength));
        if (!_canonical(key)) _malformed();
        return RevealCode(
          publicKey: key,
          nonce: Uint8List.fromList(bytes.sublist(keyLength)),
        );
      default:
        // An upper-case letter is a kind a later Signet added; anything
        // else (a case-folded paste, punctuation) is damage.
        if (RegExp(r'^[A-Z]$').hasMatch(kind)) {
          throw const PairingCodeException(PairingCodeError.thisNeedsUpdate);
        }
        _malformed();
    }
  }

  /// Versions above 2. Leading zeros (`p02`) are not a version this format
  /// ever wrote; a number too long to parse is certainly later.
  static bool _isLaterVersion(String digits) {
    if (digits.startsWith('0')) return false;
    if (digits.length > 9) return true;
    return int.parse(digits) > 2;
  }

  /// Canonical unpadded base64url only: decoding, then re-encoding, must
  /// give back the same text. Rejects `+`, `/`, `=` and non-zero trailing
  /// bits, so each code has exactly one spelling.
  static Uint8List _decodeBody(String body) {
    final Uint8List bytes;
    try {
      final padding = (4 - body.length % 4) % 4;
      bytes = Uint8List.fromList(base64Url.decode(body + '=' * padding));
    } on FormatException {
      _malformed();
    }
    if (_b64(bytes) != body) _malformed();
    return bytes;
  }

  static bool _canonical(List<int> key) => (key[keyLength - 1] & 0x80) == 0;

  static Never _malformed() =>
      throw const PairingCodeException(PairingCodeError.malformed);

  static String _b64(List<int> bytes) =>
      base64Url.encode(bytes).replaceAll('=', '');

  static void _requireLength(List<int> bytes, int length, String name) {
    if (bytes.length != length) {
      throw ArgumentError.value(
        bytes.length,
        '$name.length',
        'Must be exactly $length bytes.',
      );
    }
  }

  static void _requireKey(List<int> key, String name) {
    _requireLength(key, keyLength, name);
    if (!_canonical(key)) {
      throw ArgumentError.value(
        key,
        name,
        'X25519 public keys must have the top bit clear.',
      );
    }
  }
}
