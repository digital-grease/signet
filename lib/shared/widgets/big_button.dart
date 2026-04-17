import 'package:flutter/material.dart';

/// Full-width, high-contrast button sized for stress-moment taps
/// (min 64 dp height, 18 sp label). Follows the Material 3 FilledButton
/// shape so accessibility (focus rings, screen-reader role) comes for free.
///
/// Intentionally not a drop-in ElevatedButton replacement: the call sites
/// want "the one big button on this screen" semantics, not arbitrary styling.
class BigButton extends StatelessWidget {
  const BigButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.tone = BigButtonTone.primary,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final BigButtonTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (background, foreground) = switch (tone) {
      BigButtonTone.primary => (colors.primary, colors.onPrimary),
      BigButtonTone.destructive => (colors.errorContainer, colors.onErrorContainer),
      BigButtonTone.neutral => (colors.secondaryContainer, colors.onSecondaryContainer),
    };

    final textStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w600,
          fontSize: 18,
        );

    final child = icon == null
        ? Text(label, style: textStyle)
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, color: foreground, size: 24),
              const SizedBox(width: 12),
              Text(label, style: textStyle),
            ],
          );

    return SizedBox(
      width: double.infinity,
      height: 64,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24),
        ),
        onPressed: onPressed,
        child: child,
      ),
    );
  }
}

enum BigButtonTone { primary, destructive, neutral }
