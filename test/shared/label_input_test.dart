// Utf8LengthLimitingTextInputFormatter (plan Task 3.6, P7 + review).

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signet/shared/label_input.dart';

TextEditingValue _v(String text, {TextRange composing = TextRange.empty}) =>
    TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
      composing: composing,
    );

void main() {
  final f = Utf8LengthLimitingTextInputFormatter(32);
  const ma = '\u5988'; // 3 bytes

  test('typing up to the limit is accepted; one more character is not', () {
    final ten = ma * 10; // 30 bytes
    expect(f.formatEditUpdate(_v(ma * 9), _v(ten)).text, ten);
    expect(f.formatEditUpdate(_v(ten), _v(ma * 11)).text, ten);
  });

  test('a name already over the limit can be shortened (backspace)', () {
    final legacy = 'z' * 80;
    final shorter = 'z' * 79;
    expect(f.formatEditUpdate(_v(legacy), _v(shorter)).text, shorter);
  });

  test('an over-long paste is cut at a whole character, not dropped', () {
    final out = f.formatEditUpdate(_v(''), _v(ma * 20)).text;
    expect(out, ma * 10);
    expect(utf8.encode(out).length, lessThanOrEqualTo(32));
  });

  test('text still being composed is left alone', () {
    final composing = _v('${ma * 10}zhang', composing: const TextRange(start: 10, end: 15));
    expect(f.formatEditUpdate(_v(ma * 10), composing).text, '${ma * 10}zhang');
  });

  test('typing into a name already over the limit adds nothing and cuts '
      'nothing', () {
    final legacy = 'z' * 40;
    expect(f.formatEditUpdate(_v(legacy), _v('X$legacy')).text, legacy);
  });
}
