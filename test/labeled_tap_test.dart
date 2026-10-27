// LabeledTap: TalkBack label, at least 48×48 to tap, the icon looks the same.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:splitly/core/widgets/shared_widgets.dart';

void main() {
  testWidgets('small icon: 48×48 tap area, label for TalkBack, icon unchanged',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: LabeledTap(
            label: 'Send message',
            onTap: () => taps++,
            child: const SizedBox(width: 20, height: 20),
          ),
        ),
      ),
    ));

    expect(tester.getSize(find.byType(LabeledTap)), const Size(48, 48));
    expect(tester.getSize(find.byType(SizedBox).last), const Size(20, 20));
    expect(find.bySemanticsLabel('Send message'), findsOneWidget);

    // A tap near the edge (outside the 20×20 icon) still counts
    final topLeft = tester.getTopLeft(find.byType(LabeledTap));
    await tester.tapAt(topLeft + const Offset(4, 4));
    expect(taps, 1);
  });

  testWidgets('a fixed slot (app bar back button) keeps its size',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Center(
        child: SizedBox(
          width: 56,
          height: 56,
          child: LabeledTap(
            label: 'Back',
            onTap: () {},
            child: Container(
              margin: const EdgeInsets.all(8),
              color: Colors.teal,
            ),
          ),
        ),
      ),
    ));
    // The background box is still 40×40 (56 minus the 8 margin each side)
    expect(
        tester.getSize(find.byWidgetPredicate(
            (w) => w is ColoredBox && w.color == Colors.teal)),
        const Size(40, 40));
  });
}
