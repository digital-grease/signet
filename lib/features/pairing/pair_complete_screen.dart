import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';

/// Shown immediately after a successful pair commit. The paired peer
/// just walked through a 30-second QR dance with you, and is standing
/// next to you *right now* — which is the single best moment they'll
/// ever have to practice a verify. If we bounce straight to Home the
/// moment is gone; both users go off with zero muscle memory and will
/// fumble the first real crisis call.
///
/// One-time screen: once dismissed (via VERIFY or SKIP) it is never
/// surfaced again for this pair — the user goes straight to Home on
/// subsequent launches. We rely on the pair flow routing to land here
/// only at commit time.
class PairCompleteScreen extends ConsumerWidget {
  const PairCompleteScreen({super.key, required this.relationshipId});

  /// The id of the relationship that was just committed.
  final String relationshipId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final relationshipsAsync = ref.watch(relationshipsProvider);
    final label = relationshipsAsync.whenOrNull(
          data: (list) {
            for (final r in list) {
              if (r.id == relationshipId) return r.label;
            }
            return null;
          },
        ) ??
        l10n.pairCompleteFallbackPeer;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.pairCompleteTitle),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                l10n.pairCompleteCommittedHeader,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 10,
                  color: scheme.primary,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.pairCompleteHeading,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.pairCompletePracticeBody(label),
                style: TextStyle(
                  fontSize: 14,
                  color: scheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(16),
                color: scheme.surfaceContainerHighest,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(
                      Icons.lightbulb_outline,
                      size: 20,
                      color: scheme.secondary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        l10n.pairCompleteTipBody,
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurface,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.go('/verify/$relationshipId'),
                child: Text(
                  l10n.pairCompleteVerifyNowButton(label.toUpperCase()),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => context.go('/'),
                child: Text(l10n.pairCompleteSkipButton),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
