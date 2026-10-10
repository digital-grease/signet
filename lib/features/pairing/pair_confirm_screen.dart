import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/crypto/pair_role.dart';
import '../../core/logging/breadcrumb.dart';
import '../../core/models/relationship.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/big_button.dart';
import '../../shared/widgets/secure_screen.dart';
import 'pairing_controller.dart';

/// Step 3 of the pair flow: show the 4-word verification phrase derived from
/// the shared secret and ask the user to visually confirm it matches the
/// phrase on the other device. A mismatch means either a bad scan or a
/// man-in-the-middle — we abort and clear state rather than save.
///
/// Stateful (plan Task 3.5): [_busy] blocks a second "It matches" tap
/// while the first is saving (P3, duplicate relationships), and keeps the
/// screen from bouncing home when the pairing state is reset right after
/// the save, while this route is still on screen during its exit
/// transition (P2, the bounce used to win over the move to the practice
/// screen).
class PairConfirmScreen extends ConsumerStatefulWidget {
  const PairConfirmScreen({super.key});

  @override
  ConsumerState<PairConfirmScreen> createState() => _PairConfirmScreenState();
}

class _PairConfirmScreenState extends ConsumerState<PairConfirmScreen> {
  bool _busy = false;
  bool _bounced = false;

  /// The phrase last shown, kept on screen while the route animates out
  /// after the pairing state is reset.
  List<String>? _shownPhrase;

  Future<void> _onMatch(BuildContext context, WidgetRef ref) async {
    if (_busy) return;
    // Stays busy: every way out of _commit leaves this screen (to the
    // practice screen, or home with a message).
    setState(() => _busy = true);
    await _commit(context, ref);
  }

  Future<void> _commit(BuildContext context, WidgetRef ref) async {
    final pair = ref.read(pairingControllerProvider);
    final label = pair.label;
    final secret = pair.totpSecret;
    final ourPublicKey = pair.ourKeyPair?.publicKey;
    final theirPublicKey = pair.theirPublicKey;
    if (label == null ||
        secret == null ||
        ourPublicKey == null ||
        theirPublicKey == null) {
      await _goBackWithError(
        context,
        AppLocalizations.of(context).pairConfirmStateIncompleteError,
      );
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
              context,
              AppLocalizations.of(context)
                  .pairConfirmRekeyTargetMissingError);
          return;
        }
        relationship = existing.copyWith(
          role: role,
          pairedAt: DateTime.now().toUtc(),
        );
        // Keep the old secret for a while: if the other phone does not
        // finish the rekey, its words can then be recognised as "old
        // pairing" instead of looking like a stranger's (plan Task 3.10).
        await store.saveRelationshipV2(
          relationship,
          sharedSecret: secret,
          keepPrevious: true,
        );
      } else {
        relationship = Relationship.fresh(label: label, role: role);
        await store.saveRelationshipV2(relationship, sharedSecret: secret);
      }
      ref
          .read(debugLogProvider)
          .log(BreadcrumbEvent.pairingCommit, relationship: relationship);
      ref.read(pairingControllerProvider.notifier).reset();
      ref.invalidate(relationshipsProvider);
      if (!context.mounted) return;
      final l10n = AppLocalizations.of(context);
      if (rekeyTargetId != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.pairConfirmRekeySnackbar(label)),
          ),
        );
        // Rekey doesn't need the practice-verify nudge — the user already
        // knows the flow.
        context.go('/');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.pairConfirmPairedSnackbar(label))),
        );
        context.go('/pair/complete/${relationship.id}');
      }
    } catch (_) {
      // Event only: the error text could carry key or label material.
      ref.read(debugLogProvider).log(BreadcrumbEvent.pairingCommitFailed);
      if (!context.mounted) return;
      // The save is journaled (SecureStore.saveRelationshipV2): if it got
      // that far, it completes on the next launch. Tell the user how to
      // check instead of showing a raw error that implies "pair again".
      // A rekey needs different advice: the contact is listed either way.
      final l10n = AppLocalizations.of(context);
      await _goBackWithError(
        context,
        pair.isRekey
            ? l10n.pairConfirmRekeySaveIncompleteError
            : l10n.pairConfirmSaveIncompleteError,
      );
    }
  }

  Future<void> _onMismatch(BuildContext context, WidgetRef ref) async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.pairConfirmMismatchDialogTitle),
        content: Text(l10n.pairConfirmMismatchDialogBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.pairConfirmStartOverButton),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    ref.read(pairingControllerProvider.notifier).reset();
    if (!context.mounted) return;
    context.go('/');
  }

  Future<void> _goBackWithError(BuildContext context, String message) async {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    context.go('/');
  }

  // The pair-time phrase is derived from the shared secret, so this screen
  // blocks screenshots and recording like every other secret-bearing
  // screen (and keeps FLAG_SECURE held across the exchange → confirm
  // transition).
  @override
  Widget build(BuildContext context) =>
      SecureScreen(child: _buildBody(context, ref));

  Widget _buildBody(BuildContext context, WidgetRef ref) {
    final pair = ref.watch(pairingControllerProvider);
    // While saving or leaving, the state may already be reset: keep
    // showing the phrase the user confirmed.
    final phrase = pair.phrase ?? (_busy ? _shownPhrase : null);
    if (pair.phrase != null) _shownPhrase = pair.phrase;
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);

    if (phrase == null) {
      // User got here without a derived phrase; bounce back home, once.
      if (!_bounced) {
        _bounced = true;
        Future<void>.microtask(() {
          if (context.mounted) context.go('/');
        });
      }
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(pair.isRekey
            ? l10n.pairConfirmRekeyTitle
            : l10n.pairConfirmTitle),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _busy ? null : () => _onMismatch(context, ref),
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
                l10n.pairConfirmHeading,
                style: textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.pairConfirmInstructions,
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
                label: l10n.pairConfirmMatchButton,
                icon: Icons.check_circle,
                onPressed: _busy ? null : () => _onMatch(context, ref),
              ),
              const SizedBox(height: 12),
              BigButton(
                tone: BigButtonTone.destructive,
                label: l10n.pairConfirmMismatchButton,
                onPressed: _busy ? null : () => _onMismatch(context, ref),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
