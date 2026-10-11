import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signet/features/help/faq_screen.dart';
import 'package:signet/l10n/app_localizations.dart';

// Plan Task 1.7j: the FAQ explains the "needs an update" messages in both
// directions and names no update source but the app store.
void main() {
  testWidgets('the update entry opens and explains both directions',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: FaqScreen(),
    ));
    await tester.pumpAndSettle();
    final question = find.text('Signet says it needs an update.');
    await tester.scrollUntilVisible(question, 200);
    await tester.tap(question);
    await tester.pumpAndSettle();
    final answer = find.textContaining('this phone needs an update');
    expect(answer, findsOneWidget);
    final text = tester.widget<Text>(answer).data!;
    expect(text, contains('the other phone needs one'));
    expect(text, contains('only from the app store'));
    expect(text, contains('never sends updates as a link or file'));
    expect(text, isNot(contains('http')));
    expect(text, contains('\n\n'), reason: 'short paragraphs');
  });
}
