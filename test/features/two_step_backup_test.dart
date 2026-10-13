// Two-step backup save (plan Phase 2, bug S1): the package and its 8 words
// are saved separately, the words never reach the clipboard, and nothing
// handed to the share sheet outlives the screen.
//
// Writing and sweeping the real files is covered in
// test/shared/share_text_file_test.dart; here the saver gets in-memory
// fakes so the tests never mix real file I/O with the fake-async test zone.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:signet/features/inspect/two_step_backup.dart';
import 'package:signet/l10n/app_localizations.dart';
import 'package:signet/shared/secure_clipboard.dart';

const _wire = 'signet:tp1:AQIDBAUGBwgJCgsMDQ4PEA';
const _words = <String>[
  'abandon', 'ability', 'able', 'about',
  'above', 'absent', 'absorb', 'abstract',
];
const _fp = '123 456';
const _secureClipboard = MethodChannel('dev.digitalgrease.signet/clipboard');

void main() {
  late List<({String name, String content})> shared;
  late bool shareFails;
  late bool shareDismissed;
  Completer<void>? shareGate;
  late int sweeps;
  late bool done;

  setUp(() {
    shared = [];
    shareFails = false;
    shareDismissed = false;
    shareGate = null;
    sweeps = 0;
    done = false;
  });

  Future<bool> fakeShare({required String fileName, required String text}) async {
    await shareGate?.future;
    if (shareFails) throw StateError('no share target');
    if (shareDismissed) return false;
    shared.add((name: fileName, content: text));
    return true;
  }

  /// Records every text Signet puts on the clipboard, through the
  /// sensitive-copy channel (prefixed "sensitive:") or the plain one.
  List<String> recordClipboard() {
    final copied = <String>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied.add((call.arguments as Map)['text'] as String);
      }
      return null;
    });
    messenger.setMockMethodCallHandler(_secureClipboard, (call) async {
      if (call.method == 'copySensitive') {
        copied.add('sensitive:${(call.arguments as Map)['text']}');
      }
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(SystemChannels.platform, null);
      messenger.setMockMethodCallHandler(_secureClipboard, null);
    });
    return copied;
  }

  Future<void> fakeSweep() async => sweeps++;

  Widget app({bool showQr = true, bool mounted = true}) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: mounted
              ? SingleChildScrollView(
                  child: TwoStepBackupSaver(
                    wire: _wire,
                    pakeWords: _words,
                    fingerprint: _fp,
                    generatedAt: DateTime.utc(2026, 10, 8),
                    showQr: showQr,
                    onDone: () => done = true,
                    shareFile: fakeShare,
                    sweep: fakeSweep,
                  ),
                )
              : const SizedBox(),
        ),
      );

  Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  bool wordsVisible() => _words.any((w) => find.text(w).evaluate().isNotEmpty);

  testWidgets('the words stay hidden until the package is saved',
      (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(wordsVisible(), isFalse);
    expect(find.textContaining('Finish step 1 first'), findsOneWidget);
    expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton,
                "I'VE SAVED BOTH"))
            .onPressed,
        isNull);
  });

  testWidgets('the shared PACKAGE file has the package and none of the words',
      (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tapAndSettle(tester, find.text('Save package file'));

    expect(shared, hasLength(1));
    final file = shared.single;
    expect(file.name, 'signet-backup-2026-10-08-123456-PACKAGE.txt');
    expect(file.content, contains(_wire));
    expect(file.content, contains('Fingerprint: 123 456'));
    for (final w in _words) {
      expect(file.content.split(RegExp(r'\W+')), isNot(contains(w)));
    }
    expect(wordsVisible(), isTrue, reason: 'step 2 opens after step 1');
  });

  testWidgets('the shared WORDS file has the words and not the package',
      (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tapAndSettle(tester, find.text('I saved it another way'));
    await tapAndSettle(tester, find.text('Save words file instead'));

    final file = shared.single;
    expect(file.name, 'signet-backup-2026-10-08-123456-WORDS.txt');
    expect(file.content, contains(_words.join(' ')));
    expect(file.content, isNot(contains('signet:tp1:')));
    expect(find.text('DONE'), findsNWidgets(2));
  });

  testWidgets('finishing both steps enables the final button',
      (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tapAndSettle(tester, find.text('I saved it another way'));
    await tapAndSettle(tester, find.text('I wrote them on paper'));
    await tapAndSettle(tester, find.text("I'VE SAVED BOTH"));
    expect(done, isTrue);
  });

  testWidgets('the words never reach the clipboard; only the package does',
      (tester) async {
    final copied = recordClipboard();
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tapAndSettle(tester, find.text('Copy package'));
    await tapAndSettle(tester, find.text('I saved it another way'));
    await tapAndSettle(tester, find.text('I wrote them on paper'));
    expect(copied, <String>['sensitive:$_wire'],
        reason: 'the package goes through the sensitive copy, nothing else');
    for (final text in copied) {
      for (final w in _words) {
        expect(text.split(RegExp(r'\W+')), isNot(contains(w)));
      }
    }
    expect(find.byIcon(Icons.copy), findsOneWidget,
        reason: 'a single copy action: the package');
    SecureClipboard.resetForTesting();
  });

  testWidgets('copying the package does not finish step 1', (tester) async {
    recordClipboard();
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tapAndSettle(tester, find.text('Copy package'));
    expect(wordsVisible(), isFalse,
        reason: 'the clipboard is not a place the package is saved');
    expect(find.textContaining('Paste it somewhere off this phone'),
        findsOneWidget);
    SecureClipboard.resetForTesting();
  });

  testWidgets('backing out of the share sheet does not finish the step',
      (tester) async {
    shareDismissed = true;
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tapAndSettle(tester, find.text('Save package file'));
    expect(wordsVisible(), isFalse);
    expect(find.text('DONE'), findsNothing);

    shareDismissed = false;
    await tapAndSettle(tester, find.text('I saved it another way'));
    shareDismissed = true;
    await tapAndSettle(tester, find.text('Save words file instead'));
    expect(find.text('DONE'), findsOneWidget, reason: 'only step 1');
  });

  testWidgets('the save buttons wait while a share sheet is open',
      (tester) async {
    shareGate = Completer<void>();
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save package file'));
    await tester.pump();
    final button = tester.widget<ButtonStyleButton>(find.ancestor(
        of: find.text('Save package file'),
        matching: find.bySubtype<ButtonStyleButton>()));
    expect(button.onPressed, isNull);
    shareGate!.complete();
    await tester.pumpAndSettle();
    expect(shared, hasLength(1));
    expect(wordsVisible(), isTrue);
  });

  testWidgets('a failed share is reported and does not complete the step',
      (tester) async {
    shareFails = true;
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tapAndSettle(tester, find.text('Save package file'));
    expect(find.textContaining('Could not open the share sheet'),
        findsOneWidget);
    expect(wordsVisible(), isFalse, reason: 'step 1 must stay undone');
    expect(find.text('DONE'), findsNothing);
  });

  testWidgets('leaving the screen sweeps the shared files', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(sweeps, 0);
    await tester.pumpWidget(app(mounted: false));
    expect(sweeps, 1);
  });

  testWidgets('a single backup shows the QR code and says to print it',
      (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.textContaining('print the code'), findsOneWidget);
  });

  testWidgets('bulk mode has no QR code and does not mention one',
      (tester) async {
    await tester.pumpWidget(app(showQr: false));
    await tester.pumpAndSettle();
    expect(find.byType(SelectableText), findsOneWidget);
    expect(find.byType(QrImageView), findsNothing);
    expect(find.textContaining('print the code'), findsNothing);
  });
}
