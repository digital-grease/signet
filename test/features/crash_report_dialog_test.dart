import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signet/core/logging/crash_recorder.dart';
import 'package:signet/features/crash_report/crash_report_dialog.dart';

CrashReport _mkReport() => CrashReport(
      recordedAt: DateTime.utc(2026, 5, 21, 12),
      scrubbedTrace:
          'FormatException: Unexpected character\n'
          '#0      VerifyScreen.build (package:signet/features/verify/verify_screen.dart:362:5)',
      appVersion: '0.3.4 (30004)',
      osVersion: '14',
      device: 'Pixel 8',
      dartVersion: '3.5.0',
    );

void main() {
  testWidgets('renders title, scrubbed-trace explainer, and three actions',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (ctx) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => CrashReportDialog.show(
                  ctx,
                  report: _mkReport(),
                  onClose: () {},
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Signet had trouble'), findsOneWidget);
    expect(find.textContaining('redacted:N'), findsOneWidget);
    expect(find.text('DISMISS'), findsOneWidget);
    expect(find.text('COPY LOG'), findsOneWidget);
    expect(find.text('FILE ISSUE'), findsOneWidget);
  });

  testWidgets('DISMISS pops the dialog and fires onClose', (tester) async {
    var closed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (ctx) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => CrashReportDialog.show(
                  ctx,
                  report: _mkReport(),
                  onClose: () => closed = true,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('DISMISS'));
    await tester.pumpAndSettle();

    expect(find.text('Signet had trouble'), findsNothing);
    expect(closed, isTrue);
  });

  testWidgets('COPY LOG writes the scrubbed trace to clipboard', (tester) async {
    final clipboardWrites = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        clipboardWrites.add((call.arguments as Map)['text'] as String);
      }
      return null;
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (ctx) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => CrashReportDialog.show(
                  ctx,
                  report: _mkReport(),
                  onClose: () {},
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('COPY LOG'));
    await tester.pumpAndSettle();

    expect(clipboardWrites, hasLength(1));
    expect(clipboardWrites.single, contains('FormatException'));
  });
}
