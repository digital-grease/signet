import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/crypto/pair_role.dart';
import '../../core/models/relationship.dart';
import '../../core/providers.dart';
import '../../shared/widgets/big_button.dart';
import 'pairing_controller.dart';

/// Step 3 of the pair flow: show the 4-word verification phrase derived from
/// the shared secret and ask the user to visually confirm it matches the
/// phrase on the other device. A mismatch means either a bad scan or a
/// man-in-the-middle — we abort and clear state rather than save.
class PairConfirmScreen extends ConsumerWidget {
  const PairConfirmScreen({super.key});

  Future<void> _onMatch(BuildContext context, WidgetRef ref) async {
    final pair = ref.read(pairingControllerProvider);
    final label = pair.label;
    final secret = pair.totpSecret;
    final ourPublicKey = pair.ourKeyPair?.publicKey;
    final theirPublicKey = pair.theirPublicKey;
    if (label == null ||
        secret == null ||
        ourPublicKey == null ||
        theirPublicKey == null) {
      await _goBackWithError(context, 'Pairing state is incomplete.');
      return;
    }
    try {
      // Pin the per-device role from the public-key ordering — both sides
      // compute the same assignment independently. This is what makes the
      // rotating verify code asymmetric and defeats reflection attacks.
      final role = PairRole.assign(
        ourPublicKey: ourPublicKey,
        theirPublicKey: theirPublicKey,
      );
      final store = ref.read(secureStoreProvider);
      final rekeyTargetId = pair.rekeyTargetId;
      final Relationship relationship;
      if (rekeyTargetId != null) {
        // Rekey: overwrite the existing relationship with the new secret.
        // Preserve id and label (and silentHaptics, etc.); refresh
        // pairedAt and re-derive role from the new key ordering.
        final existing = await store.getRelationshipById(rekeyTargetId);
        if (existing == null) {
          if (!context.mounted) return;
          await _goBackWithError(
              context, 'Relationship to rekey is no longer paired.');
          return;
        }
        relationship = existing.copyWith(
          role: role,
          pairedAt: DateTime.now().toUtc(),
        );
        await store.saveRelationshipV2(relationship, sharedSecret: secret);
      } else {
        relationship = Relationship.fresh(label: label, role: role);
        await store.saveRelationshipV2(relationship, sharedSecret: secret);
      }
      ref.read(pairingControllerProvider.notifier).reset();
      ref.invalidate(relationshipsProvider);
      if (!context.mounted) return;
      if (rekeyTargetId != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Rekeyed pairing with $label.')),
        );
        // Rekey doesn't need the practice-verify nudge — the user already
        // knows the flow.
        context.go('/');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Paired with $label.')),
        );
        context.go('/pair/complete/${relationship.id}');
      }
    } catch (error) {
      if (!context.mounted) return;
      await _goBackWithError(context, 'Could not save: $error');
    }
  }

  Future<void> _onMismatch(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Phrases don’t match?'),
        content: const Text(
          'If your phrase and theirs don’t match, something went wrong — '
          'this could be a bad scan or someone trying to get in the middle. '
          'Safer to throw this pairing away and start over.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Start over'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    ref.read(pairingControllerProvider.notifier).reset();
    if (!context.mounted) return;
    context.go('/');
  }

  Future<void> _goBackWithError(BuildContext context, String message) async {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    context.go('/');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pair = ref.watch(pairingControllerProvider);
    final phrase = pair.phrase;
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (phrase == null) {
      // User got here without a derived phrase; bounce back home.
      Future<void>.microtask(() {
        if (context.mounted) context.go('/');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(pair.isRekey ? 'Confirm rekey' : 'Confirm'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => _onMismatch(context, ref),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const SizedBox(height: 8),
              Text(
                'Does this match their screen?',
                style: textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Read it out loud. All four words should be identical '
                'on both devices.',
                style: textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 32,
                ),
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: <Widget>[
                    for (final word in phrase)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          word,
                          style: textTheme.displaySmall?.copyWith(
                            color: colors.onPrimaryContainer,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                  ],
                ),
              ),
              const Spacer(),
              BigButton(
                label: 'It matches',
                icon: Icons.check_circle,
                onPressed: () => _onMatch(context, ref),
              ),
              const SizedBox(height: 12),
              BigButton(
                tone: BigButtonTone.destructive,
                label: 'No match — start over',
                onPressed: () => _onMismatch(context, ref),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
