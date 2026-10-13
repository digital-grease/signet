import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Lays [child] (typically a [Column] with [Spacer]s) out to fill the
/// available height when it fits, and lets it scroll when it does not, so
/// large text never pushes buttons off screen (plan Task 5.1).
class FillOrScroll extends StatelessWidget {
  const FillOrScroll({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: padding,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: constraints.hasBoundedHeight
                ? math.max(
                    0,
                    constraints.maxHeight -
                        (padding?.resolve(Directionality.of(context)).vertical ??
                            0),
                  )
                : 0,
          ),
          child: IntrinsicHeight(child: child),
        ),
      ),
    );
  }
}
