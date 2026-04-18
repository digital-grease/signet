import 'package:flutter/material.dart';

/// Massive, high-contrast display of the current 4-word rotating TOTP code,
/// with a linear countdown bar for the remaining seconds in the window.
///
/// Words are shown stacked (one per line, large typographic weight) so they
/// can be read aloud cleanly over a voice call and scanned at a glance by a
/// reader who isn't holding the phone right up to their face. The countdown
/// bar turns red in the final 5 seconds so the speaker knows to hurry or
/// wait for the next window.
class WordsDisplay extends StatelessWidget {
  const WordsDisplay({
    super.key,
    required this.words,
    required this.secondsRemaining,
    required this.windowSeconds,
    this.onTap,
  });

  final List<String> words;
  final int secondsRemaining;
  final int windowSeconds;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final progress = windowSeconds == 0
        ? 0.0
        : (secondsRemaining / windowSeconds).clamp(0.0, 1.0);

    final semanticsWords = words.join(' ');

    return Semantics(
      label: 'Verification phrase: $semanticsWords, '
          '$secondsRemaining seconds remaining',
      button: onTap != null,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (final word in words)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      word,
                      style: textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                        color: colors.onSurface,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: colors.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    secondsRemaining <= 5 ? colors.error : colors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$secondsRemaining s',
                style: textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
