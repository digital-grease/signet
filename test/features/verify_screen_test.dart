import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signet/core/models/relationship.dart';
import 'package:signet/core/providers.dart';
import 'package:signet/features/verify/verify_screen.dart';

import '../support/fake_secure_store.dart';

Widget _wrap({required Widget child, required FakeSecureStore store}) {
  return ProviderScope(
    overrides: [
      secureStoreProvider.overrideWithValue(store),
    ],
    child: MaterialApp(home: child),
  );
}

final _mom = Relationship(
  id: 'abc',
  label: 'Mom',
  pairedAt: DateTime.utc(2026, 4, 16),
);
final _secret = List<int>.generate(32, (i) => i + 1);

void main() {
  group('VerifyScreen', () {
    testWidgets('shows the relationship label and an 8-digit code', (tester) async {
      await tester.pumpWidget(_wrap(
        store: FakeSecureStore(seeded: _mom, secret: _secret),
        child: const VerifyScreen(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Mom'), findsOneWidget);
      // 8-digit code is displayed as "XXXX XXXX".
      final codeRegex = RegExp(r'^\d{4} \d{4}$');
      final codeText = find.byWidgetPredicate(
        (w) => w is Text && w.data != null && codeRegex.hasMatch(w.data!),
      );
      expect(codeText, findsOneWidget);
    });

    testWidgets('renders a seconds-remaining label', (tester) async {
      await tester.pumpWidget(_wrap(
        store: FakeSecureStore(seeded: _mom, secret: _secret),
        child: const VerifyScreen(),
      ));
      await tester.pumpAndSettle();

      // e.g. "12 s"
      final secondsText = find.byWidgetPredicate(
        (w) => w is Text && w.data != null && RegExp(r'^\d+ s$').hasMatch(w.data!),
      );
      expect(secondsText, findsOneWidget);
    });

    testWidgets('tapping the code copies it to the clipboard', (tester) async {
      final List<MethodCall> clipboardCalls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboardCalls.add(call);
        }
        return null;
      });

      await tester.pumpWidget(_wrap(
        store: FakeSecureStore(seeded: _mom, secret: _secret),
        child: const VerifyScreen(),
      ));
      await tester.pumpAndSettle();

      // Tap the code display area.
      final codeRegex = RegExp(r'^\d{4} \d{4}$');
      final codeFinder = find.byWidgetPredicate(
        (w) => w is Text && w.data != null && codeRegex.hasMatch(w.data!),
      );
      await tester.tap(codeFinder);
      await tester.pumpAndSettle();

      expect(clipboardCalls, hasLength(1));
      final copiedText = (clipboardCalls.single.arguments as Map)['text'] as String;
      expect(RegExp(r'^\d{8}$').hasMatch(copiedText), isTrue);
      expect(find.text('Code copied.'), findsOneWidget);
    });

    testWidgets('shows an error state when no relationship is paired', (tester) async {
      await tester.pumpWidget(_wrap(
        store: FakeSecureStore(),
        child: const VerifyScreen(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Could not read your paired contact.'), findsOneWidget);
      expect(find.text('Back to home'), findsOneWidget);
    });
  });
}
