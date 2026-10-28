// Text colours the theme pairs with its fill colours meet WCAG AA (4.5:1)
// in both themes. The light theme once drew near-white text on amber at
// 2.6:1 (the Home notice and the neutral big buttons; QA 2026-10-28).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signet/core/theme/signet_theme.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  for (final dark in [false, true]) {
    test('${dark ? 'dark' : 'light'} theme pairs', () {
      final s = signetTheme(dark: dark).colorScheme;
      final pairs = <String, (Color, Color)>{
        'primary': (s.onPrimary, s.primary),
        'secondary': (s.onSecondary, s.secondary),
        'secondaryContainer': (s.onSecondaryContainer, s.secondaryContainer),
        'surface': (s.onSurface, s.surface),
        'errorContainer': (s.onErrorContainer, s.errorContainer),
      };
      for (final MapEntry(key: name, value: (fg, bg)) in pairs.entries) {
        expect(_contrast(fg, bg), greaterThanOrEqualTo(4.5), reason: name);
      }
    });
  }
}
