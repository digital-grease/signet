import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signet/shared/widgets/words_display.dart';

void main() {
  Widget buildHost({
    required List<String> words,
    required int secondsRemaining,
    int windowSeconds = 30,
    VoidCallback? onTap,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: WordsDisplay(
          words: words,
          secondsRemaining: secondsRemaining,
          windowSeconds: windowSeconds,
          onTap: onTap,
        ),
      ),
    );
  }

  testWidgets('renders all four words', (tester) async {
    await tester.pumpWidget(
      buildHost(
        words: const <String>['orange', 'anchor', 'cat', 'wagon'],
        secondsRemaining: 20,
      ),
    );
    for (final w in ['orange', 'anchor', 'cat', 'wagon']) {
      expect(find.text(w), findsOneWidget);
    }
  });

  testWidgets('shows seconds-remaining label', (tester) async {
    await tester.pumpWidget(
      buildHost(
        words: const <String>['orange', 'anchor', 'cat', 'wagon'],
        secondsRemaining: 17,
      ),
    );
    expect(find.text('17 s'), findsOneWidget);
  });

  testWidgets('progress bar color switches to error when <=5s remaining',
      (tester) async {
    await tester.pumpWidget(
      buildHost(
        words: const <String>['a', 'b', 'c', 'd'],
        secondsRemaining: 5,
      ),
    );
    final bar = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    final color = bar.valueColor!.value;
    final errorColor =
        Theme.of(tester.element(find.byType(LinearProgressIndicator)))
            .colorScheme
            .error;
    expect(color, errorColor);
  });

  testWidgets('progress bar uses primary color when >5s remaining',
      (tester) async {
    await tester.pumpWidget(
      buildHost(
        words: const <String>['a', 'b', 'c', 'd'],
        secondsRemaining: 20,
      ),
    );
    final bar = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    final color = bar.valueColor!.value;
    final primary =
        Theme.of(tester.element(find.byType(LinearProgressIndicator)))
            .colorScheme
            .primary;
    expect(color, primary);
  });

  testWidgets('renders a Semantics label that includes all four words',
      (tester) async {
    await tester.pumpWidget(
      buildHost(
        words: const <String>['orange', 'anchor', 'cat', 'wagon'],
        secondsRemaining: 12,
      ),
    );
    expect(
      find.bySemanticsLabel(
        'Verification phrase: orange anchor cat wagon, '
        '12 seconds remaining',
      ),
      findsOneWidget,
    );
  });

  testWidgets('InkWell fires onTap when tapped', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      buildHost(
        words: const <String>['a', 'b', 'c', 'd'],
        secondsRemaining: 20,
        onTap: () => taps++,
      ),
    );
    await tester.tap(find.byType(InkWell));
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('null onTap renders non-interactive InkWell', (tester) async {
    await tester.pumpWidget(
      buildHost(
        words: const <String>['a', 'b', 'c', 'd'],
        secondsRemaining: 20,
      ),
    );
    final ink = tester.widget<InkWell>(find.byType(InkWell));
    expect(ink.onTap, isNull);
  });
}
