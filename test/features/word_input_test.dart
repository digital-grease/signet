import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signet/features/verify/word_input.dart';
import 'package:signet/l10n/app_localizations.dart';

void main() {
  Widget buildHost({
    required Future<void> Function(List<String>) onSubmit,
    int resetKey = 0,
    bool enabled = true,
  }) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
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
          localizationsDelegates: AppLocalizations.localizationsDelegates,
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

  group('prefillWords', () {
    Widget buildWithPrefill({
      required Future<void> Function(List<String>) onSubmit,
      required List<String>? prefill,
      int resetKey = 0,
      int wordCount = 4,
    }) {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: WordInput(
              onSubmit: onSubmit,
              wordCount: wordCount,
              resetKey: resetKey,
              prefillWords: prefill,
              autofocus: false,
            ),
          ),
        ),
      );
    }

    testWidgets('populates all slots on first build and auto-submits once',
        (tester) async {
      final submissions = <List<String>>[];
      await tester.pumpWidget(
        buildWithPrefill(
          onSubmit: (w) async => submissions.add(w),
          prefill: const <String>['orange', 'anchor', 'abandon', 'ability'],
        ),
      );
      await tester.pumpAndSettle();

      for (var i = 0; i < 4; i++) {
        expect(
          tester.widget<TextField>(find.byType(TextField).at(i)).controller!.text,
          ['orange', 'anchor', 'abandon', 'ability'][i],
        );
      }
      expect(submissions, <List<String>>[
        <String>['orange', 'anchor', 'abandon', 'ability'],
      ]);
    });

    testWidgets(
        'length mismatch falls back to empty slots with no auto-submit',
        (tester) async {
      var submitCount = 0;
      await tester.pumpWidget(
        buildWithPrefill(
          onSubmit: (_) async => submitCount++,
          prefill: const <String>['orange', 'anchor', 'abandon'], // wrong length
        ),
      );
      await tester.pumpAndSettle();

      for (var i = 0; i < 4; i++) {
        expect(
          tester.widget<TextField>(find.byType(TextField).at(i)).controller!.text,
          '',
        );
      }
      expect(submitCount, 0);
    });

    testWidgets('resetKey bump re-applies an updated prefill', (tester) async {
      final submissions = <List<String>>[];
      Widget build(int key, List<String> pre) => MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: Scaffold(
              body: WordInput(
                onSubmit: (w) async => submissions.add(w),
                resetKey: key,
                prefillWords: pre,
                autofocus: false,
              ),
            ),
          );

      await tester.pumpWidget(build(0,
          const <String>['orange', 'anchor', 'abandon', 'ability']));
      await tester.pumpAndSettle();
      expect(submissions, hasLength(1));

      await tester.pumpWidget(build(1,
          const <String>['able', 'above', 'absent', 'absurd']));
      await tester.pumpAndSettle();

      expect(submissions, hasLength(2));
      expect(submissions.last,
          <String>['able', 'above', 'absent', 'absurd']);
      expect(
        tester.widget<TextField>(find.byType(TextField).at(0)).controller!.text,
        'able',
      );
    });

    testWidgets('supports 8-slot prefill (PAKE length)', (tester) async {
      final submissions = <List<String>>[];
      const pake = <String>[
        'abandon',
        'ability',
        'able',
        'about',
        'above',
        'absent',
        'absorb',
        'abstract',
      ];
      await tester.pumpWidget(
        buildWithPrefill(
          onSubmit: (w) async => submissions.add(w),
          prefill: pake,
          wordCount: 8,
        ),
      );
      await tester.pumpAndSettle();

      for (var i = 0; i < 8; i++) {
        expect(
          tester.widget<TextField>(find.byType(TextField).at(i)).controller!.text,
          pake[i],
        );
      }
      expect(submissions, <List<String>>[pake]);
    });
  });

  group('submitting (plan Task 3.3)', () {
    Widget host({
      Future<void> Function(List<String>)? onSubmit,
      ValueChanged<List<String>?>? onWordsChanged,
      int wordCount = 4,
      List<String>? prefill,
    }) =>
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: WordInput(
                onSubmit: onSubmit,
                onWordsChanged: onWordsChanged,
                submitLabel: onSubmit == null ? null : 'CHECK THE WORDS',
                wordCount: wordCount,
                prefillWords: prefill,
                autofocus: false,
              ),
            ),
          ),
        );

    Future<void> typeIn(WidgetTester tester, int slot, String text) async {
      await tester.enterText(find.byType(TextField).at(slot), text);
      await tester.pumpAndSettle();
    }

    ButtonStyleButton checkButton(WidgetTester tester) =>
        tester.widget<ButtonStyleButton>(find.ancestor(
            of: find.text('CHECK THE WORDS'),
            matching: find.bySubtype<ButtonStyleButton>()));

    testWidgets('correcting an earlier typo submits once it is unambiguous',
        (tester) async {
      final submitted = <List<String>>[];
      await tester.pumpWidget(host(onSubmit: (w) async => submitted.add(w)));
      await typeIn(tester, 0, 'abandon');
      await typeIn(tester, 1, 'abilitz'); // typo
      await typeIn(tester, 2, 'able');
      await typeIn(tester, 3, 'about');
      expect(submitted, isEmpty);
      expect(checkButton(tester).onPressed, isNull);

      await typeIn(tester, 1, 'ability');
      expect(submitted, <List<String>>[
        <String>['abandon', 'ability', 'able', 'about'],
      ]);
    });

    testWidgets('"act" typed on the way to "action" never submits',
        (tester) async {
      final submitted = <List<String>>[];
      await tester.pumpWidget(host(onSubmit: (w) async => submitted.add(w)));
      await typeIn(tester, 0, 'abandon');
      await typeIn(tester, 1, 'ability');
      await typeIn(tester, 2, 'able');
      await typeIn(tester, 3, 'act');
      expect(submitted, isEmpty, reason: 'no false alarm mid-word');
      expect(find.widgetWithText(ActionChip, 'act'), findsOneWidget,
          reason: 'the prefix word itself is offered first');
      expect(checkButton(tester).onPressed, isNotNull,
          reason: '"act" is a real word, so it can be checked on purpose');

      await typeIn(tester, 3, 'action');
      expect(submitted.single.last, 'action');
    });

    testWidgets('"car" in the last slot: a chip tap submits', (tester) async {
      final submitted = <List<String>>[];
      await tester.pumpWidget(host(onSubmit: (w) async => submitted.add(w)));
      await typeIn(tester, 0, 'abandon');
      await typeIn(tester, 1, 'ability');
      await typeIn(tester, 2, 'able');
      await typeIn(tester, 3, 'car');
      expect(submitted, isEmpty);
      await tester.tap(find.widgetWithText(ActionChip, 'car'));
      await tester.pumpAndSettle();
      expect(submitted.single, <String>['abandon', 'ability', 'able', 'car']);
    });

    testWidgets('a prefix word in an earlier slot blocks auto-submit until '
        'confirmed', (tester) async {
      final submitted = <List<String>>[];
      await tester.pumpWidget(host(onSubmit: (w) async => submitted.add(w)));
      await typeIn(tester, 0, 'car');
      await typeIn(tester, 1, 'ability');
      await typeIn(tester, 2, 'able');
      await typeIn(tester, 3, 'about');
      expect(submitted, isEmpty);
      await tester.tap(find.widgetWithText(ActionChip, 'car'));
      await tester.pumpAndSettle();
      expect(submitted, hasLength(1));
    });

    testWidgets('the check button submits a typed prefix word on purpose',
        (tester) async {
      final submitted = <List<String>>[];
      await tester.pumpWidget(host(onSubmit: (w) async => submitted.add(w)));
      await typeIn(tester, 0, 'abandon');
      await typeIn(tester, 1, 'ability');
      await typeIn(tester, 2, 'able');
      await typeIn(tester, 3, 'act');
      await tester.ensureVisible(find.text('CHECK THE WORDS'));
      await tester.tap(find.text('CHECK THE WORDS'));
      await tester.pumpAndSettle();
      expect(submitted.single.last, 'act');
    });

    testWidgets('an edit that changes nothing does not check twice',
        (tester) async {
      final submitted = <List<String>>[];
      await tester.pumpWidget(host(onSubmit: (w) async => submitted.add(w)));
      await typeIn(tester, 0, 'abandon ability able about');
      expect(submitted, hasLength(1));
      // Pressing the keyboard's Done key on a word already checked.
      await tester.showKeyboard(find.byType(TextField).at(3));
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(submitted, hasLength(1));
    });

    testWidgets('onWordsChanged follows every edit, including after a prefill',
        (tester) async {
      const pake = <String>[
        'abandon', 'ability', 'able', 'about',
        'above', 'absent', 'absorb', 'abstract',
      ];
      final reports = <List<String>?>[];
      await tester.pumpWidget(host(
        onWordsChanged: reports.add,
        wordCount: 8,
        prefill: pake,
      ));
      await tester.pumpAndSettle();
      expect(reports.last, pake);

      await typeIn(tester, 7, 'abstr');
      expect(reports.last, isNull, reason: 'incomplete word');
      await typeIn(tester, 7, 'absurd');
      expect(reports.last, <String>[...pake.take(7), 'absurd'],
          reason: 'the edited word is what the parent unlocks with');
    });
  });

  group('review fixes', () {
    testWidgets('Clear all empties prefilled slots for good', (tester) async {
      const pake = <String>[
        'abandon', 'ability', 'able', 'about',
        'above', 'absent', 'absorb', 'abstract',
      ];
      List<String>? last = pake;
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (context, setState) => WordInput(
                wordCount: 8,
                autofocus: false,
                prefillWords: last?.length == 8 ? last : null,
                onWordsChanged: (w) => setState(() => last = w),
              ),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Clear all'));
      await tester.tap(find.text('Clear all'));
      await tester.pumpAndSettle();
      expect(last, isNull);
      for (var i = 0; i < 8; i++) {
        expect(
            tester.widget<TextField>(find.byType(TextField).at(i))
                .controller!
                .text,
            isEmpty);
      }
    });

    testWidgets('a space after a prefix word confirms it', (tester) async {
      final submitted = <List<String>>[];
      await tester.pumpWidget(buildHost(onSubmit: (w) async => submitted.add(w)));
      for (final (i, w) in <String>['abandon', 'ability', 'able'].indexed) {
        await tester.enterText(slotField(i), w);
        await tester.pumpAndSettle();
      }
      await tester.enterText(slotField(3), 'act');
      await tester.pumpAndSettle();
      expect(submitted, isEmpty);
      await tester.enterText(slotField(3), 'act ');
      await tester.pumpAndSettle();
      expect(submitted.single.last, 'act');
    });
  });
}
