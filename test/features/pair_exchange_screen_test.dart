import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signet/features/pairing/pair_exchange_screen.dart';
import 'package:signet/features/pairing/pairing_controller.dart';
import 'package:signet/l10n/app_localizations.dart';

void main() {
  Widget wrap({Locale locale = const Locale('en')}) => ProviderScope(
        child: MaterialApp(
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const PairExchangeScreen(),
        ),
      );

  Future<void> scanLowOrderKey(WidgetTester tester) async {
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PairExchangeScreen)),
    );
    final ctrl = container.read(pairingControllerProvider.notifier);
    await tester.runAsync(() async {
      await ctrl.ensureOurKeyPair();
      await ctrl.markQrShown();
      await ctrl.recordTheirPublicKey(Uint8List(32));
    });
    await tester.pumpAndSettle();
  }

  // C1 / P1: the in-person screen must show the localized "stop, cancel on
  // both phones" message, not the English-only internal error string.
  for (final locale in const [Locale('en'), Locale('zh')]) {
    testWidgets('a low-order scanned key shows the in-person tamper warning '
        '(${locale.languageCode})', (tester) async {
      await tester.pumpWidget(wrap(locale: locale));
      await tester.pumpAndSettle();
      await scanLowOrderKey(tester);

      final l10n = lookupAppLocalizations(locale);
      expect(find.text(l10n.pairingWeakKeyInPersonError), findsOneWidget);
      expect(find.textContaining('low-order point'), findsNothing,
          reason: 'internal English error must not reach the UI');
    });
  }

  group('showing the QR (plan Task 3.5, P5)', () {
    Future<ProviderContainer> openQr(WidgetTester tester) async {
      await tester.pumpWidget(wrap());
      final container = ProviderScope.containerOf(
        tester.element(find.byType(PairExchangeScreen)),
      );
      await tester.runAsync(() => container
          .read(pairingControllerProvider.notifier)
          .ensureOurKeyPair());
      await tester.pumpAndSettle();
      final l10n = lookupAppLocalizations(const Locale('en'));
      await tester.tap(find.text(l10n.pairExchangeStep1Title));
      await tester.pumpAndSettle();
      expect(find.text(l10n.pairExchangeShowHeading), findsOneWidget);
      return container;
    }

    testWidgets('Back returns to the steps without marking the QR shown',
        (tester) async {
      final container = await openQr(tester);
      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      expect(container.read(pairingControllerProvider).didShowQr, isFalse,
          reason: 'the other phone may not have scanned yet');
      expect(
          find.text(lookupAppLocalizations(const Locale('en'))
              .pairExchangeStep1Title),
          findsOneWidget);
    });

    testWidgets('"They scanned" marks the QR shown', (tester) async {
      final container = await openQr(tester);
      await tester.tap(find.text("They scanned — I'm done"));
      await tester.pumpAndSettle();
      expect(container.read(pairingControllerProvider).didShowQr, isTrue);
    });
  });
}
