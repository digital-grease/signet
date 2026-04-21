import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/relationship.dart';
import '../../core/providers.dart';
import '../pairing/pairing_controller.dart';

/// Home — "operator" layout, multi-peer capable (Phase 10.4).
///
/// Empty: bordered QR icon placeholder, "Nothing paired yet.", PAIR CONTACT.
/// Paired: OFFLINE-FREE chip + RELATIONSHIPS section header + ListView of
/// per-peer rows (label, fingerprint, bound). Tap row → verify. Long-press
/// → bottom sheet with RENAME / HAPTICS toggle / SHOW BINDING / UNPAIR.
/// Floating action button routes to /pair/start for adding another peer.
/// AppBar overflow "Show intro again" stays.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _toggleSilentHaptics(
    WidgetRef ref,
    Relationship relationship,
  ) async {
    final updated =
        relationship.copyWith(silentHaptics: !relationship.silentHaptics);
    await ref.read(secureStoreProvider).updateRelationshipMetadataV2(updated);
    ref.invalidate(relationshipsProvider);
  }

  Future<void> _editLabel(
    BuildContext context,
    WidgetRef ref,
    Relationship relationship,
  ) async {
    final controller = TextEditingController(text: relationship.label);
    final newLabel = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        String? errorText;
        return StatefulBuilder(
          builder: (stfContext, setState) {
            return AlertDialog(
              title: const Text('Rename peer'),
              content: TextField(
                controller: controller,
                autofocus: true,
                maxLength: 32,
                decoration: InputDecoration(
                  labelText: 'Peer name',
                  errorText: errorText,
                ),
                onSubmitted: (_) => Navigator.of(dialogContext)
                    .pop(controller.text.trim()),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(null),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final value = controller.text.trim();
                    if (value.isEmpty) {
                      setState(() => errorText = 'Name cannot be empty.');
                      return;
                    }
                    Navigator.of(dialogContext).pop(value);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
    // Defer dispose past the dialog exit animation.
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    if (newLabel == null || newLabel == relationship.label) return;

    await ref
        .read(secureStoreProvider)
        .updateRelationshipMetadataV2(relationship.copyWith(label: newLabel));
    ref.invalidate(relationshipsProvider);
  }

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

    final store = ref.read(secureStoreProvider);
    // Snapshot the shared secret BEFORE deleting so the Undo action can
    // restore it. See 9.7 — lives only for the SnackBar window.
    final secretSnapshot = await store.getSharedSecretById(relationship.id);
    await store.deleteRelationshipById(relationship.id);
    ref.invalidate(relationshipsProvider);
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Unpaired from ${relationship.label}.'),
        duration: const Duration(seconds: 5),
        action: secretSnapshot == null
            ? null
            : SnackBarAction(
                label: 'UNDO',
                onPressed: () async {
                  await store.saveRelationshipV2(
                    relationship,
                    sharedSecret: secretSnapshot,
                  );
                  ref.invalidate(relationshipsProvider);
                },
              ),
      ),
    );
  }

  Future<void> _openPairMenu(BuildContext context) async {
    final scheme = Theme.of(context).colorScheme;
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: scheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      showDragHandle: true,
      builder: (sheetCtx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.qr_code_2),
                title: const Text('Pair in person'),
                subtitle: const Text('Both phones together, scan each other'),
                onTap: () => Navigator.of(sheetCtx).pop('in-person'),
              ),
              ListTile(
                leading: const Icon(Icons.alternate_email),
                title: const Text('Send a package'),
                subtitle:
                    const Text('Pair someone far away over a trusted channel'),
                onTap: () => Navigator.of(sheetCtx).pop('send-package'),
              ),
              ListTile(
                leading: const Icon(Icons.download),
                title: const Text('I have a package'),
                subtitle: const Text('Import a package from someone else'),
                onTap: () => Navigator.of(sheetCtx).pop('have-package'),
              ),
              ListTile(
                leading: const Icon(Icons.history_edu),
                title: const Text('Restore from backup'),
                subtitle:
                    const Text('Recover a paired contact from paper'),
                onTap: () => Navigator.of(sheetCtx).pop('restore-backup'),
              ),
            ],
          ),
        );
      },
    );
    if (action == null || !context.mounted) return;
    switch (action) {
      case 'in-person':
        context.go('/pair/start');
      case 'send-package':
        context.go('/pair/transport-out');
      case 'have-package':
        context.go('/pair/transport-in');
      case 'restore-backup':
        context.go('/inspect/import');
    }
  }

  Future<void> _openRowMenu(
    BuildContext context,
    WidgetRef ref,
    Relationship relationship,
  ) async {
    final scheme = Theme.of(context).colorScheme;
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: scheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetCtx) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: Text('Rename ${relationship.label}'),
                  onTap: () => Navigator.of(sheetCtx).pop('rename'),
                ),
                ListTile(
                  leading: Icon(relationship.silentHaptics
                      ? Icons.vibration
                      : Icons.notifications_paused),
                  title: Text(relationship.silentHaptics
                      ? 'Turn haptics on'
                      : 'Turn haptics off'),
                  onTap: () => Navigator.of(sheetCtx).pop('haptics'),
                ),
                ListTile(
                  leading: const Icon(Icons.fingerprint_outlined),
                  title: const Text('Show binding phrase'),
                  onTap: () => Navigator.of(sheetCtx).pop('binding'),
                ),
                ListTile(
                  leading: const Icon(Icons.visibility_outlined),
                  title: const Text('Liveness challenge'),
                  subtitle: const Text(
                      'Physical challenge for video calls'),
                  onTap: () => Navigator.of(sheetCtx).pop('liveness'),
                ),
                ListTile(
                  leading: const Icon(Icons.grid_on_outlined),
                  title: const Text('Challenge-response grid'),
                  subtitle: const Text(
                      'Fallback for when the other side has no phone'),
                  onTap: () => Navigator.of(sheetCtx).pop('cr-grid'),
                ),
                ListTile(
                  leading: const Icon(Icons.autorenew),
                  title: Text('Rekey ${relationship.label}'),
                  subtitle:
                      const Text('Rotate the shared secret in person'),
                  onTap: () => Navigator.of(sheetCtx).pop('rekey'),
                ),
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: const Text('Back up to paper'),
                  subtitle: const Text(
                      'Restore on a new phone if you lose this one'),
                  onTap: () => Navigator.of(sheetCtx).pop('export'),
                ),
                ListTile(
                  leading: Icon(Icons.link_off, color: scheme.error),
                  title: Text(
                    'Unpair from ${relationship.label}',
                    style: TextStyle(color: scheme.error),
                  ),
                  onTap: () => Navigator.of(sheetCtx).pop('unpair'),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (action == null || !context.mounted) return;
    switch (action) {
      case 'rename':
        await _editLabel(context, ref, relationship);
      case 'haptics':
        await _toggleSilentHaptics(ref, relationship);
      case 'binding':
        context.go('/inspect/binding');
      case 'liveness':
        context.go('/liveness/${relationship.id}');
      case 'cr-grid':
        context.go('/inspect/cr-grid/${relationship.id}');
      case 'rekey':
        ref.read(pairingControllerProvider.notifier).startRekey(
              id: relationship.id,
              label: relationship.label,
            );
        context.go('/pair/exchange');
      case 'export':
        context.go('/inspect/export/${relationship.id}');
      case 'unpair':
        await _unpair(context, ref, relationship);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final relationshipsAsync = ref.watch(relationshipsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('SIGNET'),
        actions: <Widget>[
          PopupMenuButton<String>(
            tooltip: 'Help',
            icon: const Icon(Icons.help_outline),
            onSelected: (value) {
              switch (value) {
                case 'faq':
                  context.push('/faq');
                case 'contact':
                  unawaited(launchUrl(
                    Uri.parse(
                      'https://github.com/digital-grease/signet/issues',
                    ),
                    mode: LaunchMode.externalApplication,
                  ));
              }
            },
            itemBuilder: (context) => const <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'faq',
                child: Text('FAQ'),
              ),
              PopupMenuItem<String>(
                value: 'contact',
                child: Text('Contact us'),
              ),
            ],
          ),
          PopupMenuButton<String>(
            tooltip: 'More',
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 'settings':
                  context.push('/settings');
                case 'intro':
                  context.go('/onboarding');
                case 'about':
                  context.push('/about');
              }
            },
            itemBuilder: (context) => const <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'settings',
                child: Text('Settings'),
              ),
              PopupMenuItem<String>(
                value: 'intro',
                child: Text('Show intro again'),
              ),
              PopupMenuItem<String>(
                value: 'about',
                child: Text('About'),
              ),
            ],
          ),
        ],
      ),
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
                child: relationshipsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, _) => _ErrorState(
                    message: 'Could not read your paired contacts.\n$error',
                    onRetry: () => ref.invalidate(relationshipsProvider),
                  ),
                  data: (relationships) => relationships.isEmpty
                      ? const _EmptyState()
                      : _PairedList(
                          relationships: relationships,
                          onTapRow: (r) => context.go('/verify/${r.id}'),
                          onLongPressRow: (r) => _openRowMenu(context, ref, r),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: relationshipsAsync.maybeWhen(
        data: (list) => list.isEmpty
            ? null
            : FloatingActionButton.extended(
                onPressed: () => _openPairMenu(context),
                icon: const Icon(Icons.add),
                label: const Text('PAIR'),
              ),
        orElse: () => null,
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
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: () => context.go('/pair/transport-out'),
          child: const Text('SEND A PACKAGE'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () => context.go('/pair/transport-in'),
          child: const Text('I HAVE A PACKAGE'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () => context.go('/inspect/import'),
          child: const Text('RESTORE FROM BACKUP'),
        ),
      ],
    );
  }
}

class _PairedList extends StatelessWidget {
  const _PairedList({
    required this.relationships,
    required this.onTapRow,
    required this.onLongPressRow,
  });

  final List<Relationship> relationships;
  final void Function(Relationship) onTapRow;
  final void Function(Relationship) onLongPressRow;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const _SectionHeader('RELATIONSHIPS'),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.only(bottom: 96),
            itemCount: relationships.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _RelationshipRow(
              relationship: relationships[i],
              onTap: () => onTapRow(relationships[i]),
              onLongPress: () => onLongPressRow(relationships[i]),
            ),
          ),
        ),
      ],
    );
  }
}

class _RelationshipRow extends StatelessWidget {
  const _RelationshipRow({
    required this.relationship,
    required this.onTap,
    required this.onLongPress,
  });

  final Relationship relationship;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  String get _fingerprintPrefix {
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
    return '$y-$mo-$d';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      relationship.label,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'role:${relationship.role.wireName.toUpperCase()} · '
                      '$_fingerprintPrefix · $_boundAt',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: scheme.onSurfaceVariant,
                        letterSpacing: 0.5,
                      ),
                    ),
                    if (relationship.silentHaptics)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'HAPTICS // OFF',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 10,
                            color: scheme.secondary,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
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

// -------- Private operator primitives (shared with verify_screen; hoist
// to lib/shared/widgets/operator_primitives.dart later if a third consumer
// materializes).

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
