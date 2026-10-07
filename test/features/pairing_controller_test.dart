import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signet/features/pairing/pairing_controller.dart';

void main() {
  group('PairingController.setLabel', () {
    test('trims whitespace', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(pairingControllerProvider.notifier).setLabel('  Mom  ');
      expect(container.read(pairingControllerProvider).label, 'Mom');
    });

    test('treats empty / whitespace-only input as null', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(pairingControllerProvider.notifier).setLabel('   ');
      expect(container.read(pairingControllerProvider).label, isNull);
    });
  });

  group('PairingController.startRekey', () {
    test('seeds label + rekeyTargetId, wipes other state', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final ctrl = container.read(pairingControllerProvider.notifier);

      // Put the controller in a half-way state first.
      await ctrl.ensureOurKeyPair();
      ctrl.setLabel('Dad');
      await ctrl.markQrShown();

      ctrl.startRekey(id: 'abc123', label: 'Mom');

      final state = container.read(pairingControllerProvider);
      expect(state.rekeyTargetId, 'abc123');
      expect(state.label, 'Mom');
      expect(state.isRekey, isTrue);
      expect(state.ourKeyPair, isNull);
      expect(state.theirPublicKey, isNull);
      expect(state.didShowQr, isFalse);
      expect(state.totpSecret, isNull);
      expect(state.phrase, isNull);
    });

    test('isRekey is false in a fresh pair flow', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(pairingControllerProvider).isRekey, isFalse);
    });
  });

  group('PairingController.ensureOurKeyPair', () {
    test('generates a 32-byte public key on first call', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(pairingControllerProvider.notifier).ensureOurKeyPair();
      final kp = container.read(pairingControllerProvider).ourKeyPair;
      expect(kp, isNotNull);
      expect(kp!.publicKey, hasLength(32));
    });

    test('is idempotent — repeated calls keep the same key pair', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final ctrl = container.read(pairingControllerProvider.notifier);
      await ctrl.ensureOurKeyPair();
      final first = container.read(pairingControllerProvider).ourKeyPair!.publicKey;
      await ctrl.ensureOurKeyPair();
      final second = container.read(pairingControllerProvider).ourKeyPair!.publicKey;
      expect(second, equals(first));
    });
  });

  group('PairingController.markQrShown', () {
    test('flips didShowQr to true', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final ctrl = container.read(pairingControllerProvider.notifier);
      expect(container.read(pairingControllerProvider).didShowQr, isFalse);
      await ctrl.markQrShown();
      expect(container.read(pairingControllerProvider).didShowQr, isTrue);
    });
  });

  group('PairingController.recordTheirPublicKey', () {
    test('stores the scanned key but waits for our key pair to derive', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final ctrl = container.read(pairingControllerProvider.notifier);
      await ctrl.recordTheirPublicKey(Uint8List.fromList(List.filled(32, 1)));
      final s = container.read(pairingControllerProvider);
      expect(s.hasScannedTheirKey, isTrue);
      expect(s.totpSecret, isNull);
      expect(s.phrase, isNull);
    });

    // ISSUE #1 regression coverage. Before the fix, recording the
    // counterparty's key alone was enough to derive the phrase + TOTP
    // secret and advance the screen, leaving the other device deadlocked
    // because we'd never shown them our QR. The fix gates derivation on
    // didShowQr as well.
    test('does NOT derive when only scan happened (issue #1)', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final ctrl = container.read(pairingControllerProvider.notifier);
      await ctrl.ensureOurKeyPair();
      await ctrl.recordTheirPublicKey(Uint8List.fromList(List.filled(32, 9)));
      final s = container.read(pairingControllerProvider);
      expect(s.hasScannedTheirKey, isTrue);
      expect(s.didShowQr, isFalse);
      expect(s.confirmationReady, isFalse,
          reason: 'must not auto-advance before user marks QR shown');
      expect(s.phrase, isNull);
      expect(s.totpSecret, isNull);
    });

    test('derives only after BOTH scan AND markQrShown (scan first)', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final ctrl = container.read(pairingControllerProvider.notifier);
      await ctrl.ensureOurKeyPair();
      await ctrl.recordTheirPublicKey(Uint8List.fromList(List.filled(32, 9)));
      // Mid-state: scan done, show pending. Must not be ready yet.
      expect(container.read(pairingControllerProvider).confirmationReady,
          isFalse);
      await ctrl.markQrShown();
      final s = container.read(pairingControllerProvider);
      expect(s.confirmationReady, isTrue);
      expect(s.phrase, hasLength(4));
      expect(s.totpSecret, hasLength(32));
    });

    test('derives only after BOTH scan AND markQrShown (show first)', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final ctrl = container.read(pairingControllerProvider.notifier);
      await ctrl.ensureOurKeyPair();
      await ctrl.markQrShown();
      // Mid-state: show done, scan pending. Must not be ready yet.
      expect(container.read(pairingControllerProvider).confirmationReady,
          isFalse);
      await ctrl.recordTheirPublicKey(Uint8List.fromList(List.filled(32, 9)));
      final s = container.read(pairingControllerProvider);
      expect(s.confirmationReady, isTrue);
      expect(s.phrase, hasLength(4));
      expect(s.totpSecret, hasLength(32));
    });

    // C1 / P1: a MITM substituting a low-order point would otherwise make
    // both phones derive an all-zero secret with matching phrases.
    test('low-order key: no phrase, typed failure, key dropped for rescan',
        () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final ctrl = container.read(pairingControllerProvider.notifier);
      await ctrl.ensureOurKeyPair();
      await ctrl.markQrShown();
      await ctrl.recordTheirPublicKey(Uint8List(32)); // all-zero point
      final s = container.read(pairingControllerProvider);
      expect(s.confirmationReady, isFalse);
      expect(s.phrase, isNull);
      expect(s.totpSecret, isNull);
      expect(s.failure, PairingFailure.weakPublicKey);
      expect(s.error, isNotNull);
      expect(s.hasScannedTheirKey, isFalse,
          reason: 'bad key is dropped so the user can rescan');
      expect(s.ourKeyPair, isNotNull,
          reason: 'our QR stays valid for the other device');
    });

    test('a good rescan after a low-order key clears the failure', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final ctrl = container.read(pairingControllerProvider.notifier);
      await ctrl.ensureOurKeyPair();
      await ctrl.markQrShown();
      await ctrl.recordTheirPublicKey(Uint8List(32));
      await ctrl.recordTheirPublicKey(Uint8List.fromList(List.filled(32, 9)));
      final s = container.read(pairingControllerProvider);
      expect(s.failure, isNull);
      expect(s.error, isNull);
      expect(s.confirmationReady, isTrue);
    });

    test('a wrong-length scan after a weak key replaces the weak-key failure',
        () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final ctrl = container.read(pairingControllerProvider.notifier);
      await ctrl.ensureOurKeyPair();
      await ctrl.markQrShown();
      await ctrl.recordTheirPublicKey(Uint8List(32));
      await ctrl.recordTheirPublicKey(Uint8List.fromList(List.filled(31, 1)));
      final s = container.read(pairingControllerProvider);
      expect(s.failure, isNull);
      expect(s.error, contains('31 bytes'));
    });

    test('records an error if the remote key length is wrong', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final ctrl = container.read(pairingControllerProvider.notifier);
      await ctrl.ensureOurKeyPair();
      await ctrl.recordTheirPublicKey(Uint8List.fromList(List.filled(31, 1)));
      expect(container.read(pairingControllerProvider).error, isNotNull);
    });
  });

  group('PairingController.clearScan', () {
    test('removes the scanned key and any derived phrase', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final ctrl = container.read(pairingControllerProvider.notifier);
      await ctrl.ensureOurKeyPair();
      await ctrl.markQrShown();
      await ctrl.recordTheirPublicKey(Uint8List.fromList(List.filled(32, 4)));
      expect(container.read(pairingControllerProvider).phrase, isNotNull);
      ctrl.clearScan();
      final s = container.read(pairingControllerProvider);
      expect(s.theirPublicKey, isNull);
      expect(s.phrase, isNull);
      expect(s.totpSecret, isNull);
    });
  });

  group('PairingController.reset', () {
    test('clears everything including label and our key pair', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final ctrl = container.read(pairingControllerProvider.notifier);
      ctrl.setLabel('Mom');
      await ctrl.ensureOurKeyPair();
      await ctrl.markQrShown();
      ctrl.reset();
      final s = container.read(pairingControllerProvider);
      expect(s.label, isNull);
      expect(s.ourKeyPair, isNull);
      expect(s.didShowQr, isFalse);
    });
  });
}
