import 'package:example/html_gallery_demo.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  test('every built-in tag has a sample', () {
    final covered = {
      for (final group in htmlTagGroups)
        for (final sample in group.samples) ...sample.tags,
    };
    final missing = MarkdownHtml.defaults.names
        .where((tag) => !covered.contains(tag))
        .toList();
    expect(missing, isEmpty);
  });

  testWidgets('gallery renders, filters and toggles', (tester) async {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const HtmlGalleryApp());
    await tester.pumpAndSettle();
    expect(find.text('HTML tags (68)'), findsOneWidget);

    // Build every card, not only those on screen.
    final list = find
        .descendant(
            of: find.byType(ListView), matching: find.byType(Scrollable))
        .first;
    for (final tag in ['<input>', '<html>', '<head>', '<blink>']) {
      await tester.scrollUntilVisible(find.text(tag), 400, scrollable: list);
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);

    await tester.enterText(find.byType(TextField).first, 'table');
    await tester.pumpAndSettle();
    expect(find.text('<table>'), findsWidgets);
    expect(find.text('<mark>'), findsNothing);

    // Editing a source re-renders it, and survives the filter.
    await tester.enterText(find.byType(TextField).first, 'mark');
    await tester.pumpAndSettle();
    final editor = find.byType(TextField).at(1);
    await tester.enterText(editor, 'Now <mark>edited live</mark>.');
    await tester.pumpAndSettle();
    expect(
      find.textContaining('edited live', findRichText: true),
      findsWidgets,
    );
    expect(find.text('Reset'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '');
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'mark');
    await tester.pumpAndSettle();
    expect(find.text('Reset'), findsOneWidget);

    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    expect(find.text('Reset'), findsNothing);
    expect(
      find.textContaining('edited live', findRichText: true),
      findsNothing,
    );

    await tester.tap(find.text('Custom tags'));
    await tester.tap(find.text('HTML on'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
