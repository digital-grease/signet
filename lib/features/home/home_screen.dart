import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/relationship.dart';
import '../../core/providers.dart';

/// Home — "operator" layout.
///
/// Empty: bordered QR icon placeholder, "Nothing paired yet.", PAIR CONTACT.
/// Paired: PEER section header, display-sized label, mono metadata rows
/// (fingerprint prefix, bound timestamp, cipher), VERIFY + UNPAIR actions.
/// Status chip at top-right asserts OFFLINE-FREE posture — visible trust
/// affordance that the app has no network permission.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _unpair(
    BuildContext context,
    WidgetRef ref,
    Relationship relationship,
  ) async {
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
              foregroundColor:
                  Theme.of(dialogContext).colorScheme.onErrorContainer,
              backgroundColor:
                  Theme.of(dialogContext).colorScheme.errorContainer,
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
      appBar: AppBar(title: const Text('SIGNET')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Align(
                alignment: Alignment.centerRight,
                child: _StatusChip(
                  label: 'OFFLINE-FREE',
                  tone: _Tone.ok,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: relationshipAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
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
            ],
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
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const Spacer(),
        Center(
          child: Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              border: Border.all(color: scheme.outline, width: 2),
            ),
            child: Center(
              child: Icon(
                Icons.qr_code_2,
                size: 48,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
        const SizedBox(height: 32),
        Text(
          'Nothing paired yet.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Pair in person with someone you trust. '
          "You'll both be able to verify each other later over any call.",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: scheme.onSurfaceVariant,
            height: 1.5,
          ),
        ),
        const Spacer(),
        FilledButton(
          onPressed: () => context.go('/pair/start'),
          child: const Text('PAIR CONTACT'),
        ),
      ],
    );
  }
}

class _PairedState extends StatelessWidget {
  const _PairedState({required this.relationship, required this.onUnpair});

  final Relationship relationship;
  final VoidCallback onUnpair;

  String get _fingerprintPrefix {
    // Render first 4 bytes of the id as colon-separated uppercase hex —
    // ssh-style fingerprint prefix, enough to disambiguate visually without
    // exposing the full id.
    final id = relationship.id;
    final bytes = <String>[];
    for (var i = 0; i + 2 <= id.length && bytes.length < 4; i += 2) {
      bytes.add(id.substring(i, i + 2).toUpperCase());
    }
    return bytes.join(':');
  }

  String get _boundAt {
    final dt = relationship.pairedAt.toUtc();
    final y = dt.year.toString().padLeft(4, '0');
    final mo = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final mi = dt.minute.toString().padLeft(2, '0');
    return '$y-$mo-$d $h:$mi UTC';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const _SectionHeader('PEER'),
        const SizedBox(height: 4),
        Text(
          relationship.label,
          style: TextStyle(
            fontSize: 44,
            fontWeight: FontWeight.w600,
            color: scheme.onSurface,
            height: 1.0,
          ),
        ),
        const SizedBox(height: 16),
        _MonoKV(
          k: 'FINGERPRINT //',
          v: 'role:${relationship.role.wireName.toUpperCase()} · $_fingerprintPrefix',
        ),
        _MonoKV(k: 'BOUND //', v: _boundAt),
        const _MonoKV(k: 'CIPHER //', v: 'HKDF-SHA256 · BIP39-4w'),
        const Spacer(),
        FilledButton(
          onPressed: () => context.go('/verify'),
          child: Text('VERIFY ${relationship.label.toUpperCase()}'),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: onUnpair,
          style: OutlinedButton.styleFrom(
            foregroundColor: scheme.error,
            side: BorderSide(color: scheme.error, width: 1),
          ),
          child: const Text('UNPAIR'),
        ),
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
          FilledButton(
            onPressed: onRetry,
            child: const Text('TRY AGAIN'),
          ),
        ],
      ),
    );
  }
}

// -------- Private operator primitives (hoist to shared/widgets/ when Verify
// redesign also needs them in Task 9.3). Keeping inline now to avoid premature
// abstraction.

enum _Tone { ok, warn, fail }

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.tone});

  final String label;
  final _Tone tone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (tone) {
      _Tone.ok => scheme.primary,
      _Tone.warn => scheme.secondary,
      _Tone.fail => scheme.error,
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(Icons.circle, size: 8, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 11,
            color: color,
            letterSpacing: 1.8,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      '$label //',
      style: TextStyle(
        fontFamily: 'monospace',
        fontSize: 10,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        letterSpacing: 2,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _MonoKV extends StatelessWidget {
  const _MonoKV({required this.k, required this.v});
  final String k;
  final String v;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: RichText(
        text: TextSpan(
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 11,
            color: scheme.onSurfaceVariant,
            letterSpacing: 0.5,
          ),
          children: <TextSpan>[
            TextSpan(text: k.padRight(14)),
            TextSpan(
              text: v,
              style: TextStyle(color: scheme.onSurface),
            ),
          ],
        ),
      ),
    );
  }
}

