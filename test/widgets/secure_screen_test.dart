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
