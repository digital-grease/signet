import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signet/features/pairing/pair_exchange_screen.dart';
import 'package:signet/l10n/app_localizations.dart';

// The in-person intro gained a safety sentence ("only scan the other phone
// itself, never a photo or a video call"). The screen must still fit, or
// scroll, at large text sizes on a small phone (CLAUDE.md: large-text mode
// is first-class).
void main() {
  for (final (size, scale) in const [
    (Size(360, 640), 1.3),
    (Size(412, 915), 2.0),
  ]) {
    testWidgets('exchange screen has no overflow at ${size.width.toInt()}x'
        '${size.height.toInt()} @${scale}x text', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        child: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(scale),
          ),
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: PairExchangeScreen(),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.textContaining('never a photo or a video call'),
          findsOneWidget);

      // The "show my QR" pane must fit too.
      await tester.ensureVisible(find.text('Show my QR'));
      await tester.tap(find.text('Show my QR'));
      await tester.pumpAndSettle();
      expect(find.textContaining('They scanned'), findsOneWidget,
          reason: 'the QR pane is actually showing');
      expect(tester.takeException(), isNull);
    });
  }
}
