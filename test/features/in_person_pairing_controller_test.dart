import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signet/core/crypto/pairing.dart';
import 'package:signet/core/crypto/pairing_commitment.dart';
import 'package:signet/core/crypto/verification.dart';
import 'package:signet/features/pairing/in_person_pairing_controller.dart';
import 'package:signet/features/pairing/pairing_code_v2.dart';

/// One simulated phone: its own container, with key and nonce factories
/// that record everything they hand out so tests can prove single use.
class _Phone {
  _Phone({this.keysThrow = false}) {
    container = ProviderContainer(overrides: [
      inPersonKeyPairFactoryProvider.overrideWithValue(() async {
        if (keysThrow) throw StateError('no entropy');
        final kp = await PairingHandshake.generateEphemeralKeyPair();
        keys.add(kp.publicKey);
        return kp;
      }),
      inPersonNonceFactoryProvider.overrideWithValue(() {
        final n = PairingCommitment.newNonce();
        nonces.add(n);
        return n;
      }),
      // Cheap Argon2id: these tests check the protocol, not the KDF cost.
      // [deriveGate], when set, holds the derivation open so a test can
      // end the attempt in the middle of it.
      inPersonPhraseDeriverProvider.overrideWithValue(({
        required List<int> sharedSecret,
        required List<int> ownPublicKey,
        required List<int> peerPublicKey,
        required List<int> nonce,
      }) async {
        derivations++;
        final gate = deriveGate;
        if (gate != null) await gate.future;
        return PairingVerification.deriveInPersonPhraseWithParams(
          sharedSecret: sharedSecret,
          ownPublicKey: ownPublicKey,
          peerPublicKey: peerPublicKey,
          nonce: nonce,
          params: const PhraseKdfParams(memoryKiB: 64, iterations: 1),
        );
      }),
    ]);
  }

  final bool keysThrow;
  late final ProviderContainer container;
  final keys = <Uint8List>[];
  final nonces = <Uint8List>[];
  int derivations = 0;
  Completer<void>? deriveGate;

  InPersonPairingController get ctrl =>
      container.read(inPersonPairingControllerProvider.notifier);
  InPersonPairingState get state =>
      container.read(inPersonPairingControllerProvider);
  String get qr => state.qrPayload!;

  void dispose() => container.dispose();
}

/// Both phones through the happy path up to (not including) Join's scan
/// of QR-3. Returns the payloads that crossed the air.
Future<({String commit, String key, String reveal})> _runToReveal(
  _Phone start,
  _Phone join,
) async {
  await start.ctrl.begin(InPersonRole.start);
  await join.ctrl.begin(InPersonRole.join);
  final commit = start.qr;
  await join.ctrl.onScan(commit); // Join scans QR-1, mints its key
  start.ctrl.startNext(); // "the other phone scanned it"
  final key = join.qr;
  await start.ctrl.onScan(key); // Start scans QR-2
  join.ctrl.joinNext();
  final reveal = start.qr;
  return (commit: commit, key: key, reveal: reveal);
}

/// A Join phone that has shown its key for [commit], so its QR is a key
/// code a Start phone would accept.
Future<_Phone> _joinFor(String commit) async {
  final j = _Phone();
  await j.ctrl.begin(InPersonRole.join);
  await j.ctrl.onScan(commit);
  return j;
}

/// The step-1 and step-3 codes for a chosen (here: weak) Start key, so a
/// Join phone can be fed a reveal that does open its commitment.
Future<({String commit, String reveal})> _codesFor(Uint8List startKey) async {
  final nonce = PairingCommitment.newNonce();
  final c = await PairingCommitment.commit(publicKey: startKey, nonce: nonce);
  return (
    commit: PairingCodeV2.encodeCommit(c),
    reveal: PairingCodeV2.encodeReveal(publicKey: startKey, nonce: nonce),
  );
}

void main() {
  late _Phone start;
  late _Phone join;
  setUp(() {
    start = _Phone();
    join = _Phone();
  });
  tearDown(() {
    start.dispose();
    join.dispose();
  });

  group('happy path', () {
    test('both phones reach the same phrase and secret', () async {
      final air = await _runToReveal(start, join);
      expect(PairingCodeV2.decode(air.commit), isA<CommitCode>());
      expect(PairingCodeV2.decode(air.key), isA<KeyCode>());
      expect(PairingCodeV2.decode(air.reveal), isA<RevealCode>());

      await join.ctrl.onScan(air.reveal); // Join scans QR-3
      await start.ctrl.startFinish(); // "the other phone scanned it"

      expect(start.state.step, InPersonStep.confirm);
      expect(join.state.step, InPersonStep.confirm);
      expect(start.state.phrase, hasLength(4));
      expect(start.state.phrase, join.state.phrase);
      expect(start.state.totpSecret, join.state.totpSecret);
      expect(start.state.ourPublicKey, join.state.theirPublicKey);
      expect(join.state.ourPublicKey, start.state.theirPublicKey);
      // Read-only: the confirm screen cannot alter what it saves.
      expect(() => start.state.phrase!.add('x'), throwsUnsupportedError);
      expect(() => start.state.totpSecret![0] = 0, throwsUnsupportedError);
    });

    test('a man-in-the-middle substituting keys gets different phrases',
        () async {
      // Mallory gives Join a commitment to her own key, and plays Join to
      // Start with another key of hers.
      final mallory = _Phone();
      addTearDown(mallory.dispose);
      await start.ctrl.begin(InPersonRole.start);
      await join.ctrl.begin(InPersonRole.join);
      await mallory.ctrl.begin(InPersonRole.start); // her commitment
      await join.ctrl.onScan(mallory.qr);
      mallory.ctrl.startNext();
      final malloryJoin = await _joinFor(start.qr); // she scans Start's C
      addTearDown(malloryJoin.dispose);
      start.ctrl.startNext();
      await start.ctrl.onScan(malloryJoin.qr);
      await mallory.ctrl.onScan(join.qr);
      join.ctrl.joinNext();
      await join.ctrl.onScan(mallory.qr); // her reveal opens her commit
      await start.ctrl.startFinish();
      expect(start.state.step, InPersonStep.confirm);
      expect(join.state.step, InPersonStep.confirm);
      expect(start.state.phrase, isNot(equals(join.state.phrase)));
    });

    test('Join accepts the reveal while still showing its key', () async {
      await start.ctrl.begin(InPersonRole.start);
      await join.ctrl.begin(InPersonRole.join);
      await join.ctrl.onScan(start.qr);
      start.ctrl.startNext();
      await start.ctrl.onScan(join.qr);
      expect(join.state.step, InPersonStep.joinShowKey); // no Next tapped
      await join.ctrl.onScan(start.qr); // e.g. pasted
      await start.ctrl.startFinish();
      expect(join.state.step, InPersonStep.confirm);
      expect(join.state.phrase, start.state.phrase);
    });
  });

  group('normative rules', () {
    test('Join does not mint a key or show a code before a valid commit',
        () async {
      await join.ctrl.begin(InPersonRole.join);
      expect(join.state.step, InPersonStep.joinScanCommit);
      expect(join.state.qrPayload, isNull);
      expect(join.keys, isEmpty);
      await join.ctrl.onScan('signet:p2:C:not-base64!!');
      expect(join.keys, isEmpty);
      expect(join.state.qrPayload, isNull);
    });

    test('Start shows the reveal only after accepting a key', () async {
      await start.ctrl.begin(InPersonRole.start);
      expect(PairingCodeV2.decode(start.qr), isA<CommitCode>());
      start.ctrl.startNext();
      expect(start.state.step, InPersonStep.startScanKey);
      expect(start.state.qrPayload, isNull);
      await start.ctrl.startFinish(); // too early: no effect
      expect(start.state.step, InPersonStep.startScanKey);
    });

    test('Start receiving a commit: the other phone also tapped Start',
        () async {
      final other = _Phone();
      addTearDown(other.dispose);
      await start.ctrl.begin(InPersonRole.start);
      await other.ctrl.begin(InPersonRole.start);
      start.ctrl.startNext();
      await start.ctrl.onScan(other.qr);
      expect(start.state.step, InPersonStep.failed);
      expect(start.state.failure, InPersonFailure.startStart);
    });

    test('Join receiving a key first: the other phone also tapped Join',
        () async {
      final otherStart = _Phone();
      addTearDown(otherStart.dispose);
      await otherStart.ctrl.begin(InPersonRole.start);
      final otherJoin = await _joinFor(otherStart.qr);
      addTearDown(otherJoin.dispose);
      await join.ctrl.begin(InPersonRole.join);
      await join.ctrl.onScan(otherJoin.qr);
      expect(join.state.failure, InPersonFailure.joinJoin);
      expect(join.keys, isEmpty);
    });

    test('a repeated scan of an accepted code is ignored', () async {
      final air = await _runToReveal(start, join);
      await join.ctrl.onScan(air.commit); // stale QR-1 in view again
      expect(join.state.step, InPersonStep.joinScanReveal);
      await start.ctrl.onScan(air.key); // QR-2 seen twice
      expect(start.state.step, InPersonStep.startShowReveal);
      expect(start.state.failure, isNull);
    });

    test('a different second code of the same kind ends the attempt',
        () async {
      final air = await _runToReveal(start, join);
      final other = await _joinFor(air.commit);
      addTearDown(other.dispose);
      await start.ctrl.onScan(other.qr); // a second, different key
      expect(start.state.failure, InPersonFailure.secondCode);

      final otherStart = _Phone();
      addTearDown(otherStart.dispose);
      await otherStart.ctrl.begin(InPersonRole.start);
      await join.ctrl.onScan(otherStart.qr); // a second, different commit
      expect(join.state.failure, InPersonFailure.secondCode);
    });

    test('two different keys in flight at once end the attempt', () async {
      await start.ctrl.begin(InPersonRole.start);
      final j1 = await _joinFor(start.qr);
      final j2 = await _joinFor(start.qr);
      addTearDown(j1.dispose);
      addTearDown(j2.dispose);
      start.ctrl.startNext();
      await Future.wait([start.ctrl.onScan(j1.qr), start.ctrl.onScan(j2.qr)]);
      expect(start.state.step, InPersonStep.failed);
      expect(start.state.failure, InPersonFailure.secondCode);
    });

    test('the same key scanned twice at once derives once', () async {
      await start.ctrl.begin(InPersonRole.start);
      final j = await _joinFor(start.qr);
      addTearDown(j.dispose);
      start.ctrl.startNext();
      await Future.wait([start.ctrl.onScan(j.qr), start.ctrl.onScan(j.qr)]);
      expect(start.state.step, InPersonStep.startShowReveal);
      expect(start.state.failure, isNull);
      expect(start.derivations, 1);
    });

    test('a reveal that does not open the commitment is tampering', () async {
      final air = await _runToReveal(start, join);
      final r = PairingCodeV2.decode(air.reveal) as RevealCode;
      final forged = PairingCodeV2.encodeReveal(
        publicKey: r.publicKey,
        nonce: Uint8List.fromList(r.nonce)..[0] ^= 1,
      );
      await join.ctrl.onScan(forged);
      expect(join.state.step, InPersonStep.failed);
      expect(join.state.failure, InPersonFailure.revealMismatch);
      expect(join.state.phrase, isNull);
    });

    test('a low-order key ends Start as a weak key', () async {
      await start.ctrl.begin(InPersonRole.start);
      start.ctrl.startNext();
      await start.ctrl.onScan(PairingCodeV2.encodeKey(Uint8List(32)));
      expect(start.state.failure, InPersonFailure.weakKey);
    });

    test('a low-order key in an honest-looking reveal ends Join as weak',
        () async {
      final codes = await _codesFor(Uint8List(32)); // commitment does open
      await join.ctrl.begin(InPersonRole.join);
      await join.ctrl.onScan(codes.commit);
      join.ctrl.joinNext();
      await join.ctrl.onScan(codes.reveal);
      expect(join.state.failure, InPersonFailure.weakKey);
      expect(join.state.phrase, isNull);
    });

    test('damaged or foreign codes change nothing and show a notice',
        () async {
      await join.ctrl.begin(InPersonRole.join);
      for (final (input, notice) in [
        ('signet:p2:C:AAAA', PairingCodeError.malformed),
        ('https://example.com', PairingCodeError.notAPairingCode),
        ('signet:p1:AAAA', PairingCodeError.peerNeedsUpdate),
        ('signet:p3:C:AAAA', PairingCodeError.thisNeedsUpdate),
      ]) {
        await join.ctrl.onScan(input);
        expect(join.state.step, InPersonStep.joinScanCommit, reason: input);
        expect(join.state.notice, notice, reason: input);
        expect(join.state.failure, isNull, reason: input);
      }
    });

    test('the next code that decodes clears the notice', () async {
      final air = await _runToReveal(start, join);
      await join.ctrl.onScan('signet:p2:R:broken');
      expect(join.state.notice, PairingCodeError.malformed);
      await join.ctrl.onScan(air.commit); // valid, already accepted
      expect(join.state.notice, isNull);
      expect(join.state.step, InPersonStep.joinScanReveal);
    });

    test('a key factory that throws ends the attempt, never hangs', () async {
      final broken = _Phone(keysThrow: true);
      addTearDown(broken.dispose);
      await broken.ctrl.begin(InPersonRole.start);
      expect(broken.state.failure, InPersonFailure.internal);

      final brokenJoin = _Phone(keysThrow: true);
      addTearDown(brokenJoin.dispose);
      await start.ctrl.begin(InPersonRole.start);
      await brokenJoin.ctrl.begin(InPersonRole.join);
      await brokenJoin.ctrl.onScan(start.qr);
      expect(brokenJoin.state.failure, InPersonFailure.internal);
    });

    test('Next and Finish from the wrong step do nothing', () async {
      await join.ctrl.begin(InPersonRole.join);
      join.ctrl.joinNext();
      expect(join.state.step, InPersonStep.joinScanCommit);
      await start.ctrl.begin(InPersonRole.start);
      start.ctrl.joinNext();
      await start.ctrl.startFinish();
      expect(start.state.step, InPersonStep.startShowCommit);
      start.ctrl.startNext();
      start.ctrl.startNext();
      expect(start.state.step, InPersonStep.startScanKey);
    });

    test('Finish twice confirms once', () async {
      final air = await _runToReveal(start, join);
      await join.ctrl.onScan(air.reveal);
      await Future.wait([start.ctrl.startFinish(), start.ctrl.startFinish()]);
      expect(start.state.step, InPersonStep.confirm);
      expect(start.state.phrase, join.state.phrase);
    });
  });

  group('ended attempts never write into the next (race guards)', () {
    // Each case starts an async step, ends the attempt before it resumes,
    // and checks the step did not write stale state or material.
    test('begin(start) superseded while minting', () async {
      final first = start.ctrl.begin(InPersonRole.start);
      start.ctrl.abort();
      await first;
      expect(start.state.step, InPersonStep.chooseRole);
      expect(start.state.qrPayload, isNull);
    });

    test('begin(start) twice: the QR is the newest attempt', () async {
      final first = start.ctrl.begin(InPersonRole.start);
      final second = start.ctrl.begin(InPersonRole.start);
      await Future.wait([first, second]);
      final c = PairingCodeV2.decode(start.qr) as CommitCode;
      expect(
        await PairingCommitment.matches(
          commitment: c.commitment,
          publicKey: start.keys.last,
          nonce: start.nonces.last,
        ),
        isTrue,
      );
      expect(start.keys, hasLength(2)); // the first attempt's key unused
    });

    test('Start ended while checking the scanned key', () async {
      await start.ctrl.begin(InPersonRole.start);
      final j = await _joinFor(start.qr);
      addTearDown(j.dispose);
      start.ctrl.startNext();
      final scan = start.ctrl.onScan(j.qr);
      start.ctrl.abort();
      await scan;
      expect(start.state.step, InPersonStep.chooseRole);
      expect(start.state.qrPayload, isNull);
    });

    test('Start ended while finishing', () async {
      start.deriveGate = Completer<void>();
      final air = await _runToReveal(start, join);
      final finish = start.ctrl.startFinish();
      expect(start.state.step, InPersonStep.deriving);
      start.ctrl.abort();
      start.deriveGate!.complete();
      await finish;
      expect(start.state.step, InPersonStep.chooseRole);
      expect(start.state.phrase, isNull);
      expect(air.reveal, isNotEmpty);
    });

    test('Join ended while minting its key', () async {
      await start.ctrl.begin(InPersonRole.start);
      await join.ctrl.begin(InPersonRole.join);
      final scan = join.ctrl.onScan(start.qr);
      join.ctrl.abort();
      await join.ctrl.begin(InPersonRole.join);
      await scan;
      expect(join.state.step, InPersonStep.joinScanCommit);
      expect(join.state.qrPayload, isNull); // no old key shown
    });

    test('a reveal arriving while Join re-mints never uses the old key',
        () async {
      // Attempt 1 gets as far as Start revealing against Join's first key.
      await start.ctrl.begin(InPersonRole.start);
      await join.ctrl.begin(InPersonRole.join);
      await join.ctrl.onScan(start.qr);
      start.ctrl.startNext();
      await start.ctrl.onScan(join.qr);
      final commit = PairingCodeV2.encodeCommit(
        (await PairingCommitment.commit(
          publicKey: start.keys.last,
          nonce: start.nonces.last,
        )),
      );
      final reveal = start.qr;
      // Join leaves and starts again; the same reveal lands while the new
      // key is still being minted.
      join.ctrl.abort();
      await join.ctrl.begin(InPersonRole.join);
      final scanCommit = join.ctrl.onScan(commit);
      final scanReveal = join.ctrl.onScan(reveal);
      await Future.wait([scanCommit, scanReveal]);
      // Ignored: no key yet in this attempt, and the old one is gone.
      expect(join.derivations, 0);
      expect(join.state.step, InPersonStep.joinShowKey);
      expect(join.state.phrase, isNull);
    });

    test('Join ended while checking the reveal', () async {
      final air = await _runToReveal(start, join);
      final scan = join.ctrl.onScan(air.reveal);
      join.ctrl.abort();
      await scan;
      expect(join.state.step, InPersonStep.chooseRole);
      expect(join.state.phrase, isNull);
    });

    test('Join ended while deriving the phrase', () async {
      join.deriveGate = Completer<void>();
      final air = await _runToReveal(start, join);
      final scan = join.ctrl.onScan(air.reveal);
      while (join.state.step != InPersonStep.deriving) {
        await Future<void>.delayed(Duration.zero);
      }
      join.ctrl.abort();
      join.deriveGate!.complete();
      await scan;
      expect(join.state.step, InPersonStep.chooseRole);
      expect(join.state.phrase, isNull);
    });
  });

  group('single-use keys and nonces (spike requirement 3)', () {
    // Every way an attempt can end, followed by a fresh attempt. The
    // regression test the attack simulation points at: if any exit path
    // kept a key or nonce, the birthday attack would work again.
    final exits = <String, Future<void> Function(_Phone, _Phone)>{
      'abort while showing the commit': (s, j) async {
        await s.ctrl.begin(InPersonRole.start);
        s.ctrl.abort();
      },
      'abort while scanning for the key': (s, j) async {
        await s.ctrl.begin(InPersonRole.start);
        s.ctrl.startNext();
        s.ctrl.abort();
      },
      'abort while showing the reveal': (s, j) async {
        await _runToReveal(s, j);
        s.ctrl.abort();
        j.ctrl.abort();
      },
      'abort on the confirm step': (s, j) async {
        final air = await _runToReveal(s, j);
        await j.ctrl.onScan(air.reveal);
        await s.ctrl.startFinish();
        s.ctrl.abort();
        j.ctrl.abort();
      },
      'reset': (s, j) async {
        await _runToReveal(s, j);
        s.ctrl.reset();
        j.ctrl.reset();
      },
      'timeout': (s, j) async {
        await _runToReveal(s, j);
        s.ctrl.timeOut();
        j.ctrl.timeOut();
      },
      'reveal mismatch': (s, j) async {
        final air = await _runToReveal(s, j);
        final r = PairingCodeV2.decode(air.reveal) as RevealCode;
        await j.ctrl.onScan(PairingCodeV2.encodeReveal(
          publicKey: r.publicKey,
          nonce: Uint8List.fromList(r.nonce)..[3] ^= 1,
        ));
        s.ctrl.abort();
      },
      'second code': (s, j) async {
        final air = await _runToReveal(s, j);
        final other = await _joinFor(air.commit);
        await s.ctrl.onScan(other.qr);
        other.dispose();
        j.ctrl.abort();
      },
      'Start/Start': (s, j) async {
        final other = _Phone();
        await other.ctrl.begin(InPersonRole.start);
        await s.ctrl.begin(InPersonRole.start);
        s.ctrl.startNext();
        await s.ctrl.onScan(other.qr);
        other.dispose();
      },
      'Join/Join': (s, j) async {
        await s.ctrl.begin(InPersonRole.start);
        final other = await _joinFor(s.qr);
        await j.ctrl.begin(InPersonRole.join);
        await j.ctrl.onScan(other.qr);
        other.dispose();
        s.ctrl.abort();
      },
      'weak key at Start': (s, j) async {
        await s.ctrl.begin(InPersonRole.start);
        s.ctrl.startNext();
        await s.ctrl.onScan(PairingCodeV2.encodeKey(Uint8List(32)));
      },
      'weak key at Join': (s, j) async {
        final codes = await _codesFor(Uint8List(32));
        await j.ctrl.begin(InPersonRole.join);
        await j.ctrl.onScan(codes.commit);
        await j.ctrl.onScan(codes.reveal);
      },
      'begin again without leaving': (s, j) async {
        await _runToReveal(s, j);
      },
    };

    for (final entry in exits.entries) {
      test('fresh key and nonce after: ${entry.key}', () async {
        await entry.value(start, join);
        final startKeys = start.keys.length;
        final startNonces = start.nonces.length;
        final joinKeys = join.keys.length;

        final air = await _runToReveal(start, join);

        // A new attempt minted new material on both phones...
        expect(start.keys.length, startKeys + 1);
        expect(start.nonces.length, startNonces + 1);
        expect(join.keys.length, joinKeys + 1);
        // ...and what was shown is that new material, never an old value.
        final r = PairingCodeV2.decode(air.reveal) as RevealCode;
        final k = PairingCodeV2.decode(air.key) as KeyCode;
        expect(r.publicKey, start.keys.last);
        expect(r.nonce, start.nonces.last);
        expect(k.publicKey, join.keys.last);
        for (final old in start.keys.sublist(0, start.keys.length - 1)) {
          expect(r.publicKey, isNot(equals(old)));
        }
        for (final old in start.nonces.sublist(0, start.nonces.length - 1)) {
          expect(r.nonce, isNot(equals(old)));
        }
        for (final old in join.keys.sublist(0, join.keys.length - 1)) {
          expect(k.publicKey, isNot(equals(old)));
        }
      });
    }

    test('an ended attempt exposes no key, code or phrase', () async {
      await _runToReveal(start, join);
      start.ctrl.abort();
      expect(start.state.ourPublicKey, isNull);
      expect(start.state.qrPayload, isNull);
      expect(start.state.phrase, isNull);
      expect(start.state.totpSecret, isNull);
    });

    test('timeOut ends a running attempt and is ignored otherwise', () async {
      start.ctrl.timeOut();
      expect(start.state.step, InPersonStep.chooseRole);
      await start.ctrl.begin(InPersonRole.start);
      start.ctrl.timeOut();
      expect(start.state.failure, InPersonFailure.timedOut);
      expect(start.state.qrPayload, isNull);
    });
  });

  group('UI signals', () {
    test('busy while minting or deriving, isScanning on scan steps',
        () async {
      final mint = start.ctrl.begin(InPersonRole.start);
      expect(start.state.busy, isTrue); // no QR yet
      await mint;
      expect(start.state.busy, isFalse);
      expect(start.state.isScanning, isFalse);
      start.ctrl.startNext();
      expect(start.state.isScanning, isTrue);
      await join.ctrl.begin(InPersonRole.join);
      expect(join.state.isScanning, isTrue);
    });
  });

  group('session context', () {
    test('label and rekey target survive a failed attempt', () async {
      start.ctrl.startRekey(id: 'rel-1', label: 'Mom');
      await start.ctrl.begin(InPersonRole.start);
      start.ctrl.startNext();
      await start.ctrl.onScan(PairingCodeV2.encodeKey(Uint8List(32)));
      expect(start.state.failure, InPersonFailure.weakKey);
      expect(start.state.label, 'Mom');
      expect(start.state.rekeyTargetId, 'rel-1');
      await start.ctrl.begin(InPersonRole.start);
      expect(start.state.isRekey, isTrue);
      expect(start.state.failure, isNull);
    });

    test('setLabel starts a new contact: it clears any rekey target', () {
      start.ctrl.startRekey(id: 'rel-1', label: 'Mom');
      start.ctrl.setLabel('  Dad ');
      expect(start.state.label, 'Dad');
      expect(start.state.rekeyTargetId, isNull);
    });

    test('reset clears everything, label and rekey target included', () {
      start.ctrl.startRekey(id: 'rel-1', label: 'Mom');
      start.ctrl.reset();
      expect(start.state.label, isNull);
      expect(start.state.rekeyTargetId, isNull);
      expect(start.state.step, InPersonStep.chooseRole);
    });
  });
}
