import 'package:example/main.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

/// Every piece of text the preview renders.
String _text(WidgetTester tester) => [
      for (final w in tester.widgetList(
        find.byWidgetPredicate((w) => w is RichText),
      ))
        (w as RichText).text.toPlainText(),
    ].join('\n');

GptMarkdown _preview(WidgetTester tester) =>
    tester.widget<GptMarkdown>(find.byType(GptMarkdown));

Future<void> _pumpApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1600, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const App());
  await tester.pumpAndSettle();
}

Future<void> _choose(WidgetTester tester, String key, String item) async {
  await tester.tap(find.byKey(ValueKey(key)));
  await tester.pumpAndSettle();
  await tester.tap(find.text(item).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the tour renders HTML, and the HTML switch shows it raw', (
    tester,
  ) async {
    await _pumpApp(tester);
    expect(tester.takeException(), isNull);
    expect(_text(tester), isNot(contains('<b>bold</b>')));
    expect(find.byType(Table), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('html')));
    await tester.pumpAndSettle();
    expect(_preview(tester).html, isFalse);
    expect(_text(tester), contains('<b>bold</b>'));
  });

  testWidgets('custom tags render the app\'s own widgets', (tester) async {
    await _pumpApp(tester);
    expect(find.byType(ExpansionTile), findsNothing);

    await tester.tap(find.byKey(const ValueKey('custom-tags')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(_preview(tester).htmlTags, isNotNull);
    expect(find.byType(ExpansionTile), findsOneWidget);
    expect(_text(tester), isNot(contains('<badge')));
  });

  testWidgets('the Arabic tour renders right to left', (tester) async {
    await _pumpApp(tester);
    await _choose(tester, 'sample', 'Arabic (RTL) tour');
    expect(tester.takeException(), isNull);
    expect(_preview(tester).textDirection, TextDirection.rtl);
    expect(_text(tester), contains('رحلة إلى مكتبة المستقبل'));
  });

  testWidgets('the text scale reaches the preview', (tester) async {
    await _pumpApp(tester);
    await _choose(tester, 'scale', '2.0x');
    expect(tester.takeException(), isNull);
    expect(_preview(tester).textScaler, const TextScaler.linear(2));
  });
}
