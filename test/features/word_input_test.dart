import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signet/features/verify/word_input.dart';

void main() {
  Widget buildHost({
    required Future<void> Function(List<String>) onSubmit,
    int resetKey = 0,
    bool enabled = true,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: WordInput(
            onSubmit: onSubmit,
            resetKey: resetKey,
            enabled: enabled,
            autofocus: false,
          ),
        ),
      ),
    );
  }

  Finder slotField(int index) => find.byType(TextField).at(index);

  testWidgets('renders exactly 4 slots by default', (tester) async {
    await tester.pumpWidget(buildHost(onSubmit: (_) async {}));
    expect(find.byType(TextField), findsNWidgets(4));
  });

  testWidgets('shows wordlist chips when 2+ letters typed', (tester) async {
    await tester.pumpWidget(buildHost(onSubmit: (_) async {}));
    await tester.enterText(slotField(0), 'ab');
    await tester.pumpAndSettle();
    // "ab" is a prefix of several BIP-39 words (abandon, ability, able, ...)
    expect(find.byType(ActionChip), findsWidgets);
  });

  testWidgets('tapping a chip fills slot and moves focus to next slot',
      (tester) async {
    await tester.pumpWidget(buildHost(onSubmit: (_) async {}));
    await tester.enterText(slotField(0), 'aban');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ActionChip, 'abandon'));
    await tester.pumpAndSettle();
    expect(
      (tester.widget<TextField>(slotField(0)).controller)!.text,
      'abandon',
    );
  });

  testWidgets('pastes four space-separated words across all slots and submits',
      (tester) async {
    List<String>? submitted;
    await tester.pumpWidget(
      buildHost(
        onSubmit: (w) async {
          submitted = w;
        },
      ),
    );
    await tester.enterText(
      slotField(0),
      'orange anchor abandon ability',
    );
    await tester.pumpAndSettle();
    expect(submitted, <String>['orange', 'anchor', 'abandon', 'ability']);
  });

  testWidgets('pastes four hyphen-separated words', (tester) async {
    List<String>? submitted;
    await tester.pumpWidget(
      buildHost(
        onSubmit: (w) async {
          submitted = w;
        },
      ),
    );
    await tester.enterText(slotField(0), 'orange-anchor-abandon-ability');
    await tester.pumpAndSettle();
    expect(submitted, <String>['orange', 'anchor', 'abandon', 'ability']);
  });

  testWidgets('does not submit on a paste that is not all wordlist words',
      (tester) async {
    List<String>? submitted;
    await tester.pumpWidget(
      buildHost(
        onSubmit: (w) async {
          submitted = w;
        },
      ),
    );
    await tester.enterText(slotField(0), 'orange anchor notaword ability');
    await tester.pumpAndSettle();
    expect(submitted, isNull);
  });

  testWidgets(
      'flags invalid non-wordlist input with errorText in the offending slot',
      (tester) async {
    await tester.pumpWidget(buildHost(onSubmit: (_) async {}));
    await tester.enterText(slotField(0), 'xyzz');
    await tester.pumpAndSettle();
    expect(find.text('Not a valid word'), findsOneWidget);
  });

  testWidgets(
      'submits once all 4 slots are filled via per-slot chip taps',
      (tester) async {
    List<String>? submitted;
    await tester.pumpWidget(
      buildHost(
        onSubmit: (w) async {
          submitted = w;
        },
      ),
    );
    Future<void> fillSlot(int slot, String prefix, String chipWord) async {
      await tester.enterText(slotField(slot), prefix);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ActionChip, chipWord).first);
      await tester.pumpAndSettle();
    }

    await fillSlot(0, 'aban', 'abandon');
    await fillSlot(1, 'abil', 'ability');
    await fillSlot(2, 'abso', 'absorb');
    await fillSlot(3, 'abov', 'above');
    expect(submitted, <String>['abandon', 'ability', 'absorb', 'above']);
  });

  testWidgets('resetKey bump clears all slots', (tester) async {
    await tester.pumpWidget(
      buildHost(onSubmit: (_) async {}),
    );
    await tester.enterText(slotField(0), 'aban');
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(slotField(0)).controller!.text,
      'aban',
    );
    // Re-host with a new resetKey.
    await tester.pumpWidget(
      buildHost(onSubmit: (_) async {}, resetKey: 1),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(slotField(0)).controller!.text,
      '',
    );
  });

  testWidgets('disabled state blocks input', (tester) async {
    await tester.pumpWidget(
      buildHost(onSubmit: (_) async {}, enabled: false),
    );
    expect(tester.widget<TextField>(slotField(0)).enabled, isFalse);
  });

  testWidgets('partial input does not fire onSubmit', (tester) async {
    var submitCount = 0;
    await tester.pumpWidget(
      buildHost(
        onSubmit: (_) async {
          submitCount++;
        },
      ),
    );
    await tester.enterText(slotField(0), 'aban');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ActionChip, 'abandon'));
    await tester.pumpAndSettle();
    await tester.enterText(slotField(1), 'abil');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ActionChip, 'ability'));
    await tester.pumpAndSettle();
    expect(submitCount, 0);
  });

  testWidgets('after resetKey bump, widget can submit again', (tester) async {
    final submissions = <List<String>>[];
    Widget build(int key) => MaterialApp(
          home: Scaffold(
            body: WordInput(
              onSubmit: (w) async {
                submissions.add(w);
              },
              resetKey: key,
              autofocus: false,
            ),
          ),
        );
    await tester.pumpWidget(build(0));
    await tester.enterText(
      slotField(0),
      'orange anchor abandon ability',
    );
    await tester.pumpAndSettle();
    expect(submissions, hasLength(1));
    await tester.pumpWidget(build(1));
    await tester.pumpAndSettle();
    await tester.enterText(
      slotField(0),
      'able above absent absurd',
    );
    await tester.pumpAndSettle();
    expect(submissions, hasLength(2));
    expect(submissions.last, <String>['able', 'above', 'absent', 'absurd']);
  });
}
