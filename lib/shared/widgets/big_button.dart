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

    final labelWidget = Text(
      label,
      style: textStyle,
      textAlign: TextAlign.center,
      softWrap: true,
      // Two lines covers max-font + long labels; buttons that need more
      // probably need a shorter label.
      maxLines: 2,
    );
    final child = icon == null
        ? labelWidget
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(icon, color: foreground, size: 24),
              const SizedBox(width: 12),
              Flexible(child: labelWidget),
            ],
          );

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 64),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: background,
            foregroundColor: foreground,
            minimumSize: const Size(0, 64),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          onPressed: onPressed,
          child: child,
        ),
      ),
    );
  }
}

enum BigButtonTone { primary, destructive, neutral }
