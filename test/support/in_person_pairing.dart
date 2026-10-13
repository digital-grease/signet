import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:signet/core/crypto/verification.dart';
import 'package:signet/features/pairing/in_person_pairing_controller.dart';

/// A phrase deriver for widget tests: HKDF only (the first 4 words of the
/// long-distance phrase over the same keys), no Argon2id, so nothing runs
/// in an isolate under the test's fake clock. Both phones compute the same
/// words, as with the real one; the controller tests cover the real one.
final Override testInPersonPhrase =
    inPersonPhraseDeriverProvider.overrideWithValue(({
  required List<int> sharedSecret,
  required List<int> ownPublicKey,
  required List<int> peerPublicKey,
  required List<int> nonce,
}) async =>
        (await PairingVerification.deriveLongDistancePhrase(
          sharedSecret: sharedSecret,
          ownPublicKey: ownPublicKey,
          peerPublicKey: peerPublicKey,
        ))
            .sublist(0, 4));

/// Runs a real in-person exchange with a simulated peer phone, leaving
/// [container] (which plays Start) on the confirm step. Set the label or
/// the rekey target on [container] first; they survive the exchange.
Future<void> driveToConfirm(ProviderContainer container) async {
  final peer = ProviderContainer(overrides: [testInPersonPhrase]);
  try {
    final start = container.read(inPersonPairingControllerProvider.notifier);
    final join = peer.read(inPersonPairingControllerProvider.notifier);
    String qr(ProviderContainer c) =>
        c.read(inPersonPairingControllerProvider).qrPayload!;

    await start.begin(InPersonRole.start);
    await join.begin(InPersonRole.join);
    await join.onScan(qr(container));
    start.startNext();
    await start.onScan(qr(peer));
    join.joinNext();
    await join.onScan(qr(container));
    await start.startFinish();
    final state = container.read(inPersonPairingControllerProvider);
    if (state.step != InPersonStep.confirm) {
      throw StateError('exchange ended in ${state.step} (${state.failure})');
    }
  } finally {
    peer.dispose();
  }
}
