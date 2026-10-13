import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signet/shared/widgets/secure_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(SecureScreen.channel, null);
    SecureScreen.debugResetMountCount();
  });

  List<String> recordCalls() {
    final calls = <String>[];
    messenger.setMockMethodCallHandler(SecureScreen.channel, (call) async {
      calls.add(call.method);
      return null;
    });
    return calls;
  }

  Widget app(GlobalKey<NavigatorState> nav, Widget home) => WidgetsApp(
        navigatorKey: nav,
        color: const Color(0xFF000000),
        pageRouteBuilder: <T>(settings, builder) =>
            PageRouteBuilder<T>(
              settings: settings,
              pageBuilder: (context, _, _) => builder(context),
            ),
        home: home,
      );

  // S2 / L5: popping one secure route back to another secure route must not
  // clear FLAG_SECURE while the remaining route still shows secrets.
  testWidgets('pop from a stacked secure route keeps the flag on',
      (tester) async {
    final calls = recordCalls();
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
        app(nav, const SecureScreen(child: Text('import: PAKE words'))));
    await tester.pumpAndSettle();
    unawaited(nav.currentState!.push(PageRouteBuilder<void>(
      pageBuilder: (_, _, _) =>
          const SecureScreen(child: Text('bulk import')),
    )));
    await tester.pumpAndSettle();
    expect(SecureScreen.debugMountCount, 2);

    nav.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.text('import: PAKE words'), findsOneWidget);
    expect(SecureScreen.debugMountCount, 1);
    expect(calls, isNot(contains('secureOff')),
        reason: 'flag must stay on while a secure screen is still visible');

    // Leaving the last secure screen finally clears it.
    await tester.pumpWidget(app(GlobalKey<NavigatorState>(), const Text('home')));
    await tester.pumpAndSettle();
    expect(SecureScreen.debugMountCount, 0);
    expect(calls.last, 'secureOff');
  });

  testWidgets('every mount re-sends secureOn (retries a failed earlier call)',
      (tester) async {
    final calls = recordCalls();
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(app(nav, const SecureScreen(child: Text('a'))));
    await tester.pumpAndSettle();
    unawaited(nav.currentState!.push(PageRouteBuilder<void>(
      pageBuilder: (_, _, _) => const SecureScreen(child: Text('b')),
    )));
    await tester.pumpAndSettle();
    expect(calls.where((c) => c == 'secureOn'), hasLength(2));
  });

  testWidgets('replacing one secure route with another never clears the flag',
      (tester) async {
    final calls = recordCalls();
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
        app(nav, const SecureScreen(child: Text('exchange'))));
    await tester.pumpAndSettle();
    unawaited(nav.currentState!.pushReplacement(PageRouteBuilder<void>(
      pageBuilder: (_, _, _) => const SecureScreen(child: Text('confirm')),
    )));
    await tester.pumpAndSettle();
    expect(find.text('confirm'), findsOneWidget);
    expect(SecureScreen.debugMountCount, 1);
    expect(calls, isNot(contains('secureOff')));
  });

  testWidgets('nested SecureScreens clear the flag only when both are gone',
      (tester) async {
    final calls = recordCalls();
    await tester.pumpWidget(const Directionality(
      textDirection: TextDirection.ltr,
      child: SecureScreen(child: SecureScreen(child: SizedBox())),
    ));
    await tester.pumpAndSettle();
    expect(SecureScreen.debugMountCount, 2);
    await tester.pumpWidget(const Directionality(
      textDirection: TextDirection.ltr,
      child: SecureScreen(child: SizedBox()),
    ));
    await tester.pumpAndSettle();
    expect(calls, isNot(contains('secureOff')));
    await tester.pumpWidget(const Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox(),
    ));
    await tester.pumpAndSettle();
    expect(calls.where((c) => c == 'secureOff'), hasLength(1));
  });

  testWidgets('invokes secureOn on mount and secureOff on dismount',
      (tester) async {
    final calls = <String>[];
    messenger.setMockMethodCallHandler(SecureScreen.channel, (call) async {
      calls.add(call.method);
      return null;
    });

    await tester.pumpWidget(const Directionality(
      textDirection: TextDirection.ltr,
      child: SecureScreen(
        child: SizedBox(),
      ),
    ));
    await tester.pumpAndSettle();

    expect(calls, contains('secureOn'));

    // Replace with a non-SecureScreen subtree to trigger dispose.
    await tester.pumpWidget(const Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox(),
    ));
    await tester.pumpAndSettle();

    expect(calls, <String>['secureOn', 'secureOff']);
  });

  testWidgets('swallows MissingPluginException silently', (tester) async {
    // No handler registered at all — invokeMethod throws
    // MissingPluginException which _SecureScreenState catches.
    await tester.pumpWidget(const Directionality(
      textDirection: TextDirection.ltr,
      child: SecureScreen(
        child: SizedBox(),
      ),
    ));
    await tester.pumpAndSettle();

    // If this test reaches here without an uncaught exception, the handler
    // is swallowing the error correctly.
    expect(find.byType(SecureScreen), findsOneWidget);
  });

  testWidgets('swallows PlatformException silently', (tester) async {
    messenger.setMockMethodCallHandler(SecureScreen.channel, (call) async {
      throw PlatformException(
        code: 'TEST',
        message: 'simulated platform failure',
      );
    });

    await tester.pumpWidget(const Directionality(
      textDirection: TextDirection.ltr,
      child: SecureScreen(
        child: SizedBox(),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(SecureScreen), findsOneWidget);
  });
}
