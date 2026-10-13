// Every verify result is spoken (plan Task 5.2): a live region only speaks
// when its text changes, so a second identical failure used to be silent.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signet/core/crypto/pair_role.dart';
import 'package:signet/core/models/relationship.dart';
import 'package:signet/core/providers.dart';
import 'package:signet/features/verify/verify_screen.dart';
import 'package:signet/l10n/app_localizations.dart';

import '../support/fake_secure_store.dart';

void main() {
  late List<Map<Object?, Object?>> announced;

  setUp(() {
    announced = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockDecodedMessageHandler<Object?>(SystemChannels.accessibility,
            (message) async {
      if (message is Map && message['type'] == 'announce') {
        announced.add(message);
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockDecodedMessageHandler<Object?>(
            SystemChannels.accessibility, null);
  });

  Future<void> pump(WidgetTester tester, {required bool supports}) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures(supportsAnnounce: supports);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final mom = Relationship(
      id: 'mom1',
      label: 'Mom',
      pairedAt: DateTime.utc(2026, 1, 1),
      role: PairRole.a,
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        secureStoreProvider.overrideWithValue(
            FakeSecureStore(seeded: mom, secret: List<int>.filled(32, 7))),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: VerifyScreen(
          relationshipId: 'mom1',
          unixTimeSecondsProvider: () => 1735776000,
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> failOnce(WidgetTester tester) async {
    for (final (i, w)
        in <String>['abandon', 'ability', 'able', 'about'].indexed) {
      await tester.enterText(find.byType(TextField).at(i), w);
      await tester.pumpAndSettle();
    }
  }

  String text(Map<Object?, Object?> event) =>
      ((event['data'] as Map?)?['message'] as String?) ?? '';

  testWidgets('two identical failures are both announced', (tester) async {
    await pump(tester, supports: true);
    await failOnce(tester);
    await failOnce(tester);
    expect(announced, hasLength(2));
    for (final e in announced) {
      expect(text(e), contains('NOT VERIFIED'));
    }
  });

  testWidgets('nothing is sent where the platform does not take '
      'announcements', (tester) async {
    await pump(tester, supports: false);
    await failOnce(tester);
    expect(announced, isEmpty);
  });

  testWidgets(
      'without announcements (Android), each identical result is a new '
      'live-region node, so TalkBack reads it again', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester, supports: false);
    await failOnce(tester);
    final first = tester.getSemantics(
        find.bySemanticsLabel(RegExp(r'^NOT VERIFIED')).first);
    expect(first.flagsCollection.isLiveRegion, isTrue);
    final firstId = first.id;
    await failOnce(tester);
    final second = tester.getSemantics(
        find.bySemanticsLabel(RegExp(r'^NOT VERIFIED')).first);
    expect(second.flagsCollection.isLiveRegion, isTrue);
    expect(second.id, isNot(firstId));
    handle.dispose();
  });

  testWidgets('with announcements (iOS), the banner is not also a live '
      'region, so nothing is read twice', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester, supports: true);
    await failOnce(tester);
    final node = tester.getSemantics(
        find.bySemanticsLabel(RegExp(r'^NOT VERIFIED')).first);
    expect(node.flagsCollection.isLiveRegion, isFalse);
    expect(announced, hasLength(1));
    handle.dispose();
  });
}
