import 'package:flutter/material.dart';

/// Massive, high-contrast display of the current 8-digit TOTP code,
/// with a linear countdown bar for the remaining seconds in the window.
///
/// Digits are shown as two groups of four ("1234 5678") to make them
/// easier to read aloud and harder to mis-hear over a phone call.
/// On tap the parent's [onTap] fires (typical action: copy to clipboard
/// + snackbar).
class CodeDisplay extends StatelessWidget {
  const CodeDisplay({
    super.key,
    required this.code,
    required this.secondsRemaining,
    required this.windowSeconds,
    this.onTap,
  });

  final String code;
  final int secondsRemaining;
  final int windowSeconds;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final progress = windowSeconds == 0
        ? 0.0
        : (secondsRemaining / windowSeconds).clamp(0.0, 1.0);

    final displayCode = code.length == 8 ? '${code.substring(0, 4)} ${code.substring(4)}' : code;

    return Semantics(
      label: 'Verification code $code, $secondsRemaining seconds remaining',
      button: onTap != null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  displayCode,
                  style: TextStyle(
                    fontSize: 72,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'monospace',
                    fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
                    letterSpacing: 2,
                    color: colors.onSurface,
                  ),
                ),
              ),
              const SizedBox(height: 20),
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
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
