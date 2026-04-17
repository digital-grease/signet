import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signet/app.dart';
import 'package:signet/core/providers.dart';

import 'support/fake_secure_store.dart';

void main() {
  testWidgets('App boots and lands on the home screen', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          secureStoreProvider.overrideWithValue(FakeSecureStore()),
        ],
        child: SignetApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Signet'), findsOneWidget);
    expect(find.text("You haven't paired with anyone yet."), findsOneWidget);
  });
}
