import 'package:flutter_test/flutter_test.dart';
import 'package:signet/core/crypto/liveness_challenge.dart';

void main() {
  group('LivenessAction corpus', () {
    test('has exactly 8 curated actions (accessibility gate)', () {
      // If this number changes, review the library docs of
      // liveness_challenge.dart and confirm the new additions pass the
      // accessibility constraints.
      expect(LivenessAction.values, hasLength(8));
    });

    test('each action has a non-empty, human-readable instruction', () {
      for (final a in LivenessAction.values) {
        expect(a.humanReadable, isNotEmpty);
        // No placeholder / unfinished strings.
        expect(a.humanReadable.startsWith('TODO'), isFalse);
      }
    });

    test('actions have distinct human-readable text (no dup prompts)', () {
      final texts = LivenessAction.values.map((a) => a.humanReadable).toSet();
      expect(texts.length, LivenessAction.values.length);
    });
  });
}
