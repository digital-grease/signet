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

  testWidgets('the word-language entry says how to fix it, and never to '
      'change it for a caller (v0.5.0 Task 1.8)', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: FaqScreen(),
    ));
    await tester.pumpAndSettle();
    final question = find.text("My contact's words are in another language.");
    await tester.scrollUntilVisible(question, 200);
    await tester.ensureVisible(question);
    await tester.pumpAndSettle();
    await tester.tap(question);
    await tester.pumpAndSettle();
    final answer = find.textContaining('still says NOT VERIFIED',
        skipOffstage: false);
    expect(answer, findsOneWidget);
    final text = tester.widget<Text>(answer).data!;
    expect(text, contains('press and hold the contact'));
    expect(text, contains('never because a caller asks you to'));
  });

  testWidgets('the beta entry says no native speaker checked the Chinese '
      'words and where to report one (v0.5.0 Task 3.8)', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: FaqScreen(),
    ));
    await tester.pumpAndSettle();
    final question = find.text('Why are Chinese words marked beta?');
    await tester.scrollUntilVisible(question, 200);
    await tester.ensureVisible(question);
    await tester.pumpAndSettle();
    await tester.tap(question);
    await tester.pumpAndSettle();
    final answer = find.textContaining('No native speaker has checked',
        skipOffstage: false);
    expect(answer, findsOneWidget);
    expect(tester.widget<Text>(answer).data, contains('CONTACT US'));
  });
}
