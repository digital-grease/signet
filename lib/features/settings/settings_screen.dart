import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/logging/debug_log_export_scrubber.dart';
import '../../core/logging/report_context.dart';
import '../../core/prefs/settings_controller.dart';
import '../../core/providers.dart';
import '../../core/theme/signet_theme.dart';
import '../../l10n/app_localizations.dart';
import 'debug_logging_controller.dart';
import 'log_export_sheet.dart';

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
    final debugState = ref.watch(debugLoggingProvider);
    final debugAvailable = ref.read(debugLoggingProvider.notifier).available;
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _Section(
                title: l10n.settingsAppearanceSection,
                body: l10n.settingsAppearanceBody,
                child: _ThemeModePicker(
                  current: themeMode,
                  onChanged: (mode) =>
                      ref.read(themeModeProvider.notifier).set(mode),
                ),
              ),
              const SizedBox(height: 12),
              _Section(
                title: l10n.settingsBulkBackupSection,
                body: relationshipCount == 0
                    ? l10n.settingsBulkBackupEmptyBody
                    : l10n.settingsBulkBackupBody(relationshipCount),
                actionLabel: relationshipCount == 0
                    ? null
                    : l10n.settingsBulkBackupAction(relationshipCount),
                onAction: relationshipCount == 0
                    ? null
                    : () => _confirmAndStartBulkExport(
                          context,
                          relationshipCount,
                        ),
              ),
              if (debugAvailable) ...<Widget>[
                const SizedBox(height: 12),
                _Section(
                  title: l10n.settingsDebugSection,
                  body: debugState.active
                      ? l10n.settingsDebugActiveBody(
                          _formatExpiry(context, debugState.expiresAt))
                      : l10n.settingsDebugInactiveBody,
                  actionLabel: debugState.active
                      ? null
                      : l10n.settingsDebugEnableAction,
                  onAction: debugState.active
                      ? null
                      : () =>
                          ref.read(debugLoggingProvider.notifier).enable(),
                  child: debugState.active
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            OutlinedButton(
                              onPressed: () => _startDebugExport(context, ref),
                              child: Text(l10n.settingsDebugExportButton),
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton(
                              onPressed: () => ref
                                  .read(debugLoggingProvider.notifier)
                                  .stop(),
                              child: Text(l10n.settingsDebugStopWipeButton),
                            ),
                          ],
                        )
                      : null,
                ),
              ],
              const SizedBox(height: 12),
              _Section(
                title: l10n.settingsTourSection,
                body: l10n.settingsTourBody,
                actionLabel: l10n.settingsTourReplayAction,
                onAction: () => context.go('/onboarding'),
              ),
              const SizedBox(height: 12),
              _Section(
                title: l10n.settingsAboutSection,
                body: l10n.settingsAboutBody,
                actionLabel: l10n.settingsAboutOpenAction,
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
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.settingsBulkConfirmTitle),
        content: Text(l10n.settingsBulkConfirmBody(count)),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.commonCancelCaps),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.settingsBulkConfirmContinue),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      unawaited(context.push('/inspect/export-bulk'));
    }
  }

  /// Decrypt the session log, run the export scrubber, then open the share
  /// sheet. Gathers device context best-effort for the GitHub-issue pre-fill.
  Future<void> _startDebugExport(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    ref.read(debugLoggingProvider.notifier).refresh();
    final session = ref.read(debugLogProvider).session;
    if (session == null) return;
    final raw = await session.exportPlaintext();
    if (raw.isEmpty) {
      messenger?.showSnackBar(
        SnackBar(content: Text(l10n.settingsDebugNoLogSnackbar)),
      );
      return;
    }
    final rels = await ref.read(secureStoreProvider).listRelationships();
    final scrubbed = DebugLogExportScrubber.scrub(raw, rels);
    final ctx = await gatherReportContext();
    if (!context.mounted) return;
    await showDebugLogExportSheet(
      context,
      scrubbedLog: scrubbed,
      device: ctx.device,
      osVersion: ctx.osVersion,
      appVersion: ctx.appVersion,
    );
  }

  String _formatExpiry(BuildContext context, DateTime? at) {
    final l10n = AppLocalizations.of(context);
    if (at == null) return l10n.settingsDebugExpiryIn24h;
    final l = at.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return l10n.settingsDebugExpiryAt(
      '${two(l.hour)}:${two(l.minute)}',
      '${l.year}-${two(l.month)}-${two(l.day)}',
    );
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
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _ThemeModeTile(
          label: l10n.settingsThemeSystemLabel,
          sublabel: l10n.settingsThemeSystemSubtitle,
          value: ThemeMode.system,
          group: current,
          onChanged: onChanged,
        ),
        _ThemeModeTile(
          label: l10n.settingsThemeDarkLabel,
          sublabel: l10n.settingsThemeDarkSubtitle,
          value: ThemeMode.dark,
          group: current,
          onChanged: onChanged,
        ),
        _ThemeModeTile(
          label: l10n.settingsThemeLightLabel,
          sublabel: l10n.settingsThemeLightSubtitle,
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
