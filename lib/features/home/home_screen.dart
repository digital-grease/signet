import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/relationship.dart';
import '../../core/providers.dart';
import '../../shared/widgets/big_button.dart';

/// Two visual states:
///   - Empty: "You haven't paired with anyone yet" + primary "Pair a contact"
///   - Paired: relationship label prominent + primary "Verify {label}" +
///             small destructive "Unpair" at the bottom
/// Loading is brief (disk read of a tiny blob); we show a subtle progress
/// ring rather than blanking the screen. Errors show an inline card with
/// a retry affordance.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _unpair(BuildContext context, WidgetRef ref, Relationship relationship) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Unpair from ${relationship.label}?'),
        content: const Text(
          'This deletes the shared secret on this device. '
          'To verify again you would need to pair from scratch.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            style: FilledButton.styleFrom(
              foregroundColor: Theme.of(dialogContext).colorScheme.onErrorContainer,
              backgroundColor: Theme.of(dialogContext).colorScheme.errorContainer,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Unpair'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await ref.read(secureStoreProvider).deleteRelationship();
    ref.invalidate(relationshipProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unpaired from ${relationship.label}.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final relationshipAsync = ref.watch(relationshipProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Signet'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: relationshipAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => _ErrorState(
              message: 'Could not read your paired contact.\n$error',
              onRetry: () => ref.invalidate(relationshipProvider),
            ),
            data: (relationship) => relationship == null
                ? const _EmptyState()
                : _PairedState(
                    relationship: relationship,
                    onUnpair: () => _unpair(context, ref, relationship),
                  ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Icon(
          Icons.person_add_alt_1,
          size: 72,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 24),
        Text(
          "You haven't paired with anyone yet.",
          textAlign: TextAlign.center,
          style: textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        Text(
          'Pair with someone in person so you can verify '
          'each other later over any call or message.',
          textAlign: TextAlign.center,
          style: textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 40),
        BigButton(
          label: 'Pair a contact',
          icon: Icons.qr_code_2,
          onPressed: () => context.go('/pair/start'),
        ),
      ],
    );
  }
}

class _PairedState extends StatelessWidget {
  const _PairedState({required this.relationship, required this.onUnpair});

  final Relationship relationship;
  final VoidCallback onUnpair;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      children: <Widget>[
        const Spacer(),
        Text(
          'Paired with',
          style: textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          relationship.label,
          style: textTheme.displaySmall,
          textAlign: TextAlign.center,
        ),
        const Spacer(),
        BigButton(
          label: 'Verify ${relationship.label}',
          icon: Icons.verified_user,
          onPressed: () => context.go('/verify'),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: onUnpair,
          child: Text(
            'Unpair',
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.error_outline,
            size: 48,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}
