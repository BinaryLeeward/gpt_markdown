import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/custom_widgets/unordered_ordered_list.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

void main() {
  for (final direction in TextDirection.values) {
    testWidgets(
      'task markers replace bullets in mixed and nested lists ($direction)',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: GptMarkdown(
                '- [x] done\n'
                '- plain\n'
                '- [ ] pending\n'
                '  - [x] nested task\n'
                '  - nested plain\n\n'
                '1. [x] numbered task',
                textDirection: direction,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final lists = find.byType(UnorderedListView);
        expect(lists, findsNWidgets(5));
        // The parent of the nested list still paints its ordinary child's dot.
        const circles = [0, 1, 1, 0, 1];
        for (var i = 0; i < circles.length; i++) {
          expect(
            tester.renderObject(lists.at(i)),
            paintsExactlyCountTimes(#drawCircle, circles[i]),
            reason: 'unordered item $i',
          );
        }
        expect(find.byType(OrderedListView), findsOneWidget);
        expect(
          tester.widget<OrderedListView>(find.byType(OrderedListView)).no,
          '1.',
        );
      },
    );
  }

  testWidgets('hiding a bullet repaints without moving a scaled RTL item', (
    tester,
  ) async {
    Future<void> pump(bool visible) => tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: Align(
              alignment: Alignment.topRight,
              child: SizedBox(
                width: 320,
                child: UnorderedListView(
                  showBullet: visible,
                  textDirection: TextDirection.rtl,
                  child: const Text(
                    'A wrapped label keeps its position when the marker changes.',
                    key: Key('label'),
                    textDirection: TextDirection.rtl,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await pump(true);
    final row = find.byType(UnorderedListView);
    final label = find.byKey(const Key('label'));
    final rowRect = tester.getRect(row);
    final labelRect = tester.getRect(label);
    expect(tester.renderObject(row), paintsExactlyCountTimes(#drawCircle, 1));

    await pump(false);
    expect(tester.getRect(row), rowRect);
    expect(tester.getRect(label), labelRect);
    expect(tester.renderObject(row), paintsExactlyCountTimes(#drawCircle, 0));
  });
}
