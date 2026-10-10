// QrScannerView (plan Task 3.9): camera errors of any kind end in a pane
// with a way out, never an endless spinner; the restore screen can scan a
// package QR. A fake reader stands in for the camera.

import 'package:camera/camera.dart' show CameraController, CameraException;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:signet/core/providers.dart';
import 'package:signet/features/inspect/backup_import_screen.dart';
import 'package:signet/l10n/app_localizations.dart';
import 'package:signet/shared/widgets/qr_scanner.dart';

import '../support/fake_secure_store.dart';

/// Captures the callbacks of the reader currently on screen.
class _FakeReader {
  int built = 0;
  void Function(String text)? onText;
  void Function(CameraController? c, Exception? e)? onControllerCreated;

  Widget build({
    required void Function(String text) onText,
    required void Function(CameraController? c, Exception? e)
        onControllerCreated,
  }) {
    built++;
    this.onText = onText;
    this.onControllerCreated = onControllerCreated;
    return const ColoredBox(color: Colors.black, child: SizedBox.expand());
  }
}

void main() {
  late _FakeReader reader;

  setUp(() {
    reader = _FakeReader();
    qrReaderOverride = reader.build;
  });
  tearDown(() => qrReaderOverride = null);

  Widget host({
    required Future<String?> Function(String) onCode,
    VoidCallback? onUsePaste,
    VoidCallback? onCancel,
  }) =>
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: QrScannerView(
            onCode: onCode,
            onCancel: onCancel ?? () {},
            onUsePaste: onUsePaste,
          ),
        ),
      );

  testWidgets('an unknown camera error shows the error pane, and Try again '
      'restarts the camera', (tester) async {
    await tester.pumpWidget(host(onCode: (_) async => null));
    expect(reader.built, 1);
    reader.onControllerCreated!(null, CameraException('weirdOemCode', 'x'));
    await tester.pumpAndSettle();
    expect(find.text("The camera didn't start"), findsOneWidget);

    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(reader.built, 2, reason: 'a fresh reader, so a fresh camera');
    expect(find.text("The camera didn't start"), findsNothing);
  });

  testWidgets('a camera that never starts shows the error pane',
      (tester) async {
    await tester.pumpWidget(host(onCode: (_) async => null));
    await tester.pump(const Duration(seconds: 11));
    expect(find.text("The camera didn't start"), findsNothing);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text("The camera didn't start"), findsOneWidget);
  });

  testWidgets('a camera that starts does not trip the timeout',
      (tester) async {
    await tester.pumpWidget(host(onCode: (_) async => null));
    reader.onControllerCreated!(null, null);
    await tester.pump(const Duration(seconds: 30));
    expect(find.text("The camera didn't start"), findsNothing);
  });

  testWidgets('a refused permission keeps its own explanation',
      (tester) async {
    await tester.pumpWidget(host(onCode: (_) async => null));
    reader.onControllerCreated!(
        null, CameraException('CameraAccessDenied', 'no'));
    await tester.pumpAndSettle();
    expect(find.text("The camera didn't start"), findsNothing);
    expect(find.byIcon(Icons.no_photography_outlined), findsOneWidget);
  });

  testWidgets('"Paste instead" appears only where pasting exists',
      (tester) async {
    var pasted = false;
    await tester.pumpWidget(host(
        onCode: (_) async => null, onUsePaste: () => pasted = true));
    reader.onControllerCreated!(null, CameraException('x', 'y'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Paste instead'));
    expect(pasted, isTrue);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(host(onCode: (_) async => null));
    reader.onControllerCreated!(null, CameraException('x', 'y'));
    await tester.pumpAndSettle();
    expect(find.text('Paste instead'), findsNothing);
  });

  testWidgets('a rejected code shows why and scanning goes on; an accepted '
      'one stops it', (tester) async {
    final seen = <String>[];
    await tester.pumpWidget(host(onCode: (text) async {
      seen.add(text);
      return text == 'good' ? null : 'Not that one';
    }));
    reader.onControllerCreated!(null, null);
    reader.onText!('bad');
    await tester.pumpAndSettle();
    expect(find.text('Not that one'), findsOneWidget);
    reader.onText!('good');
    await tester.pumpAndSettle();
    reader.onText!('good');
    await tester.pumpAndSettle();
    expect(seen, <String>['bad', 'good']);
  });

  testWidgets('the countdown waits while the permission prompt is open',
      (tester) async {
    await tester.pumpWidget(host(onCode: (_) async => null));
    await tester.pump(const Duration(seconds: 5));
    // The OS prompt takes the app out of the foreground.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump(const Duration(seconds: 30));
    expect(find.text("The camera didn't start"), findsNothing);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(seconds: 11));
    expect(find.text("The camera didn't start"), findsNothing,
        reason: 'the countdown starts over on return');
    await tester.pump(const Duration(seconds: 2));
    expect(find.text("The camera didn't start"), findsOneWidget);
  });

  testWidgets('a late error from the reader replaced by Try again is ignored',
      (tester) async {
    await tester.pumpWidget(host(onCode: (_) async => null));
    final first = reader.onControllerCreated!;
    await tester.pump(const Duration(seconds: 13));
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    first(null, CameraException('lateFailure', 'x'));
    await tester.pump();
    expect(find.text("The camera didn't start"), findsNothing);
  });

  testWidgets('the restore screen scans a package QR into the package field',
      (tester) async {
    final router = GoRouter(
      initialLocation: '/inspect/import',
      routes: <RouteBase>[
        GoRoute(
          path: '/inspect/import',
          builder: (_, _) => const BackupImportScreen(),
        ),
      ],
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [secureStoreProvider.overrideWithValue(FakeSecureStore())],
      child: MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        routerConfig: router,
      ),
    ));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Scan QR'));
    await tester.tap(find.text('Scan QR'));
    await tester.pumpAndSettle();
    reader.onControllerCreated!(null, null);

    reader.onText!('https://example.com');
    await tester.pumpAndSettle();
    expect(find.textContaining("isn't a Signet package"), findsOneWidget);

    reader.onText!('signet:tp1:AQIDBAUGBwgJCgsMDQ4PEA');
    await tester.pumpAndSettle();
    expect(find.byType(QrScannerView), findsNothing, reason: 'page closed');
    final field = tester.widget<TextField>(find.byType(TextField).first);
    expect(field.controller!.text, 'signet:tp1:AQIDBAUGBwgJCgsMDQ4PEA');
  });

  testWidgets(
      'Cancel and an accepted code at the same moment close only the '
      'scanner, never the restore screen', (tester) async {
    final router = GoRouter(
      initialLocation: '/inspect/import',
      routes: <RouteBase>[
        GoRoute(
          path: '/inspect/import',
          builder: (_, _) => const BackupImportScreen(),
        ),
      ],
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [secureStoreProvider.overrideWithValue(FakeSecureStore())],
      child: MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        routerConfig: router,
      ),
    ));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Scan QR'));
    await tester.tap(find.text('Scan QR'));
    await tester.pumpAndSettle();
    reader.onControllerCreated!(null, null);

    await tester.tap(find.text('Cancel'));
    reader.onText!('signet:tp1:AQIDBAUGBwgJCgsMDQ4PEA');
    await tester.pumpAndSettle();
    expect(find.byType(BackupImportScreen), findsOneWidget);
    expect(find.byType(QrScannerView), findsNothing);
  });
}
