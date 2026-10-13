// FillOrScroll (plan Task 5.1): fills when it fits, scrolls when not, and
// never throws in a window shorter than its own padding.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signet/shared/widgets/fill_or_scroll.dart';

void main() {
  Widget host(double height) => MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              height: height,
              child: const FillOrScroll(
                padding: EdgeInsets.all(24),
                child: Column(
                  children: <Widget>[Text('top'), Spacer(), Text('bottom')],
                ),
              ),
            ),
          ),
        ),
      );

  testWidgets('a window shorter than the padding does not throw',
      (tester) async {
    await tester.pumpWidget(host(30));
    expect(tester.takeException(), isNull);
  });

  testWidgets('when it fits, the Spacer pushes the last line to the bottom',
      (tester) async {
    await tester.pumpWidget(host(400));
    final bottom = tester.getBottomLeft(find.text('bottom')).dy;
    expect(bottom, closeTo(400 - 24, 1));
  });
}
