import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every (marked text, language tag) pair in the semantics tree: what
/// TalkBack reads in a language other than the UI's.
List<(String, String)> markedWords(WidgetTester tester) => [
      for (final node in find.semantics.byPredicate((_) => true).evaluate())
        for (final a in node.getSemanticsData().attributedLabel.attributes)
          if (a is LocaleStringAttribute)
            (
              node
                  .getSemanticsData()
                  .attributedLabel
                  .string
                  .substring(a.range.start, a.range.end),
              a.locale.toLanguageTag(),
            ),
      for (final node in find.semantics.byPredicate((_) => true).evaluate())
        for (final a in node.getSemanticsData().attributedValue.attributes)
          if (a is LocaleStringAttribute)
            (
              node
                  .getSemanticsData()
                  .attributedValue
                  .string
                  .substring(a.range.start, a.range.end),
              a.locale.toLanguageTag(),
            ),
    ];

/// Each of [words] is read as [tag] somewhere on screen.
void expectMarked(WidgetTester tester, Iterable<String> words, String tag) {
  final marked = markedWords(tester);
  for (final w in words) {
    expect(marked, contains((w, tag)), reason: '"$w" should be read as $tag');
  }
}
