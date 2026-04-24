import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/prefs/settings_controller.dart';
import '../../core/providers.dart';
import '../../core/theme/signet_theme.dart';

/// Settings — deliberately tiny.
///
/// Signet's UI contract is "brutally minimal". A settings
/// screen dense with toggles contradicts that; it also grows the surface
/// an abuser or shoulder-surfer could quietly change. So this screen ships
/// only the two knobs that add user value without inviting misuse:
///
/// - **Appearance** — theme override (system/dark/light). Signet currently
///   follows the OS theme in all cases; a pinned override helps users with
///   light-sensitivity needs or who run their OS dark but prefer reading
///   security copy on a light background (or vice-versa).
/// - **Replay intro** — a non-destructive way back into the onboarding
///   walkthrough. Previously lived only on the Home overflow menu; keeping
///   the Home entry too for muscle memory.
///
/// Plus nav links to About (existing) so users who find Settings first can
/// get to the source/license/privacy metadata without backtracking.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final relationshipsAsync = ref.watch(relationshipsProvider);
    final relationshipCount = relationshipsAsync.maybeWhen(
      data: (rels) => rels.length,
      orElse: () => 0,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('SETTINGS')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _Section(
                title: 'APPEARANCE',
                body:
                    'Override the system theme. "System" follows your '
                    'device; "Dark" and "Light" pin Signet regardless.',
                child: _ThemeModePicker(
                  current: themeMode,
                  onChanged: (mode) =>
                      ref.read(themeModeProvider.notifier).set(mode),
                ),
              ),
              const SizedBox(height: 12),
              _Section(
                title: 'BULK BACKUP',
                body: relationshipCount == 0
                    ? 'No relationships paired yet. Pair with someone first, '
                        'then you can back up every pairing at once.'
                    : 'Back up all $relationshipCount '
                        '${relationshipCount == 1 ? 'relationship' : 'relationships'} '
                        'into one encrypted file with one 8-word PAKE. Use '
                        'this when switching phones — the new phone unlocks '
                        'every pairing in one step.',
                actionLabel: relationshipCount == 0
                    ? null
                    : 'BACK UP ALL $relationshipCount',
                onAction: relationshipCount == 0
                    ? null
                    : () => _confirmAndStartBulkExport(
                          context,
                          relationshipCount,
                        ),
              ),
              const SizedBox(height: 12),
              _Section(
                title: 'GUIDED TOUR',
                body:
                    'Watch the first-run walkthrough again. Useful after a '
                    'backup restore or if you want to re-read the pairing '
                    'instructions.',
                actionLabel: 'REPLAY INTRO',
                onAction: () => context.go('/onboarding'),
              ),
              const SizedBox(height: 12),
              _Section(
                title: 'ABOUT',
                body:
                    'App version, license, source code, privacy policy, '
                    'and support links.',
                actionLabel: 'OPEN ABOUT',
                onAction: () => context.push('/about'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// One-tap confirm — friction-parity with a seed-phrase export (not a nag).
  /// The abuse concern is that "back up everything" is an attractive button
  /// for an abuser with physical access. Showing the count + the PAKE-loss
  /// consequence once before generation is cheap insurance against a
  /// misclick; beyond that, additional gating would make the grandma-test
  /// path harder.
  Future<void> _confirmAndStartBulkExport(
    BuildContext context,
    int count,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('BACK UP EVERYTHING?'),
        content: Text(
          'This exports the shared secret for all $count '
          '${count == 1 ? 'relationship' : 'relationships'} '
          'into one file. Losing the 8-word PAKE means losing all $count '
          'backups. The PAKE will be shown once — write it down before '
          'closing the screen.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('CONTINUE'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      unawaited(context.push('/inspect/export-bulk'));
    }
  }
}

class _ThemeModePicker extends StatelessWidget {
  const _ThemeModePicker({
    required this.current,
    required this.onChanged,
  });

  final ThemeMode current;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _ThemeModeTile(
          label: 'SYSTEM',
          sublabel: 'Follow device theme',
          value: ThemeMode.system,
          group: current,
          onChanged: onChanged,
        ),
        _ThemeModeTile(
          label: 'DARK',
          sublabel: 'Operator default',
          value: ThemeMode.dark,
          group: current,
          onChanged: onChanged,
        ),
        _ThemeModeTile(
          label: 'LIGHT',
          sublabel: 'High-contrast daylight',
          value: ThemeMode.light,
          group: current,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _ThemeModeTile extends StatelessWidget {
  const _ThemeModeTile({
    required this.label,
    required this.sublabel,
    required this.value,
    required this.group,
    required this.onChanged,
  });

  final String label;
  final String sublabel;
  final ThemeMode value;
  final ThemeMode group;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selected = value == group;
    return InkWell(
      onTap: () => onChanged(value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: <Widget>[
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: selected ? scheme.primary : scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      letterSpacing: 2.8,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sublabel,
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
    this.child,
  });

  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final panelColor = isDark ? SignetTokens.panel : SignetTokens.panelL;
    final borderColor = isDark ? SignetTokens.border : SignetTokens.borderL;

    return Container(
      decoration: BoxDecoration(
        color: panelColor,
        border: Border.all(color: borderColor),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              letterSpacing: 2.8,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(body, style: theme.textTheme.bodyMedium),
          if (child != null) ...[
            const SizedBox(height: 8),
            child!,
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
