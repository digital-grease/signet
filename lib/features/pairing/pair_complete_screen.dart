import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';

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
  const PairCompleteScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final relationshipAsync = ref.watch(relationshipProvider);
    final label = relationshipAsync.whenOrNull(
          data: (r) => r?.label,
        ) ??
        'your peer';
    return Scaffold(
      appBar: AppBar(
        title: const Text('PAIRED'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'PAIR COMMITTED //',
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
                "You're both still here.\nTry a verify now.",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'This is the easiest moment to practice. Ask $label to '
                'open Signet, tap your name, and read the 4 words on '
                'their Show-my-words screen. Type what you hear into '
                'your verify input. Once the green banner lands, '
                "you'll know it works for real.",
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
                        'Skip this and you can still verify any time from '
                        'Home. But the cheapest practice run you will '
                        'ever get is right now.',
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
                onPressed: () => context.go('/verify'),
                child: Text('VERIFY ${label.toUpperCase()} NOW'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => context.go('/'),
                child: const Text('SKIP — DO IT LATER'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
