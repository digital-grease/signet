import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:signet/core/crypto/bip39_english_wordlist.dart';
import 'package:signet/core/crypto/liveness_challenge.dart';

void main() {
  group('LivenessChallenge.mint', () {
    test('returns a prompt whose action is in the curated corpus', () {
      for (var i = 0; i < 20; i++) {
        final p = LivenessChallenge.mint(random: Random(i));
        expect(LivenessAction.values.contains(p.action), isTrue);
      }
    });

    test('returns a prompt whose word is in the BIP-39 English wordlist', () {
      for (var i = 0; i < 20; i++) {
        final p = LivenessChallenge.mint(random: Random(i));
        expect(bip39EnglishWordlist.contains(p.word), isTrue);
      }
    });

    test('seeded RNG produces deterministic output', () {
      final a = LivenessChallenge.mint(random: Random(42));
      final b = LivenessChallenge.mint(random: Random(42));
      expect(a, b);
    });

    test('unseeded RNG produces varying output across many calls', () {
      final seen = <LivenessPrompt>{};
      for (var i = 0; i < 40; i++) {
        seen.add(LivenessChallenge.mint());
      }
      // Corpus size is 8 * 2048 = 16,384. 40 draws without dupes is the
      // expected outcome at that sparsity (probability of any dupe ≈
      // 40² / (2 * 16384) ≈ 4.9% — low but non-zero, so we assert a
      // reasonable lower bound rather than strict uniqueness).
      expect(seen.length, greaterThanOrEqualTo(30));
    });
  });

  group('LivenessPrompt', () {
    test('instruction combines action humanReadable + quoted word', () {
      const prompt = LivenessPrompt(
        action: LivenessAction.touchNose,
        word: 'abandon',
      );
      expect(
        prompt.instruction,
        'Touch the tip of your nose and say "abandon"',
      );
    });

    test('equality compares action and word', () {
      const a = LivenessPrompt(
        action: LivenessAction.lookUp,
        word: 'apple',
      );
      const b = LivenessPrompt(
        action: LivenessAction.lookUp,
        word: 'apple',
      );
      const c = LivenessPrompt(
        action: LivenessAction.lookDown,
        word: 'apple',
      );
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });

  group('LivenessAction corpus', () {
    test('has exactly 8 curated actions (accessibility gate)', () {
      // If this number changes, review the docstring on LivenessChallenge
      // and confirm the new additions pass the accessibility constraints.
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

  group('LivenessChallenge.corpusSize', () {
    test('reports the actions × wordlist product', () {
      expect(
        LivenessChallenge.corpusSize,
        LivenessAction.values.length * bip39EnglishWordlist.length,
      );
      // Sanity: 8 × 2048 = 16384.
      expect(LivenessChallenge.corpusSize, 16384);
    });
  });
}
