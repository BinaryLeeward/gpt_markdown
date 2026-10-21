/// `GptMarkdown.html` and `GptMarkdown.htmlTags`, through the real widget:
/// builders for tags of the app's own, the built-in meanings remapped or
/// removed, and HTML switched off.
library;

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

Widget _app(Widget child) => MaterialApp(
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

/// Every piece of text on screen. A predicate, not `find.byType`: the
/// package renders a `RichText` subclass.
String _text(WidgetTester tester) => [
  for (final w in tester.widgetList(
    find.byWidgetPredicate((w) => w is RichText),
  ))
    (w as RichText).text.toPlainText(),
].join('\n');

/// The styles of the spans holding [text], wherever it is rendered.
List<TextStyle?> _stylesOf(WidgetTester tester, String text) {
  final styles = <TextStyle?>[];
  for (final w in tester.widgetList(
    find.byWidgetPredicate((w) => w is RichText),
  )) {
    void walk(InlineSpan span, TextStyle? inherited) {
      final style = inherited?.merge(span.style) ?? span.style;
      if (span is TextSpan && span.text == text) {
        styles.add(style);
      }
      span.visitDirectChildren((child) {
        walk(child, style);
        return true;
      });
    }

    walk((w as RichText).text, null);
  }
  return styles;
}

// Defined once, as an app would — builders compare by identity.
final _seen = <HtmlElementDetails>[];

final _tags = <String, HtmlTag?>{
  'sup': HtmlTag.inline((context, element) {
    _seen.add(element);
    return WidgetSpan(
      child: Text(
        'SUP(${element.source})',
        key: ValueKey('sup-${element['data-id']}'),
      ),
    );
  }),
  'summary': const HtmlTag.block(),
  'details': HtmlTag.block((context, element) {
    _seen.add(element);
    final (:found, :rest) = element.take('summary');
    return Column(
      key: const ValueKey('details'),
      children: [
        Text('TITLE:${found == null ? '' : found.children.length}'),
        element.buildBlocks(rest),
        Text(element.closed ? 'CLOSED' : 'OPEN'),
      ],
    );
  }),
  'mark': HtmlTag.bold,
  'u': null,
};

void main() {
  setUp(_seen.clear);

  testWidgets('an inline builder renders a tag of the app\'s own', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        GptMarkdown('E = mc<sup data-id="7">2</sup> holds.', htmlTags: _tags),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('sup-7')), findsOneWidget);
    expect(find.text('SUP(2)'), findsOneWidget);
    expect(_seen.single.name, 'sup');
    expect(_seen.single.attributes, {'data-id': '7'});
    expect(_seen.single.block, isFalse);
    expect(_text(tester), isNot(contains('<sup')));
  });

  testWidgets('a block builder wraps the Markdown inside', (tester) async {
    await tester.pumpWidget(
      _app(
        GptMarkdown(
          '<details>\n<summary>More</summary>\n\nBody **bold**\n\n</details>\n\nAfter',
          htmlTags: _tags,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('details')), findsOneWidget);
    expect(find.text('TITLE:1'), findsOneWidget);
    expect(find.text('CLOSED'), findsOneWidget);
    final text = _text(tester);
    expect(text, contains('Body bold'));
    expect(text, contains('After'));
    expect(text, isNot(contains('More')));
    expect(text, isNot(contains('<details>')));
  });

  testWidgets('a block element renders before its closing tag streams in', (
    tester,
  ) async {
    const full =
        '<details>\n<summary>S</summary>\n\nFirst\n\nSecond\n</details>';
    for (final length in [12, 30, 40, full.length]) {
      await tester.pumpWidget(
        _app(
          GptMarkdown(
            full.substring(0, length),
            htmlTags: _tags,
            isStreaming: length < full.length,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('CLOSED'), findsOneWidget);
    expect(_text(tester), contains('Second'));
  });

  testWidgets('a built-in meaning can be given to another tag', (tester) async {
    await tester.pumpWidget(
      _app(GptMarkdown('a <mark>marked</mark> word', htmlTags: _tags)),
    );
    await tester.pumpAndSettle();
    expect(
      _stylesOf(tester, 'marked').any((s) => s?.fontWeight == FontWeight.bold),
      isTrue,
    );
  });

  testWidgets('null leaves a tag as written', (tester) async {
    await tester.pumpWidget(
      _app(GptMarkdown('a <u>under</u> b', htmlTags: _tags)),
    );
    await tester.pumpAndSettle();
    expect(_text(tester), contains('a <u>under</u> b'));
  });

  testWidgets('html: false shows every tag as written', (tester) async {
    await tester.pumpWidget(
      _app(GptMarkdown('x<br>y and <b>bold</b>', html: false)),
    );
    await tester.pumpAndSettle();
    expect(_text(tester), contains('x<br>y and <b>bold</b>'));
  });

  testWidgets('an inline element stays inside its list item', (tester) async {
    await tester.pumpWidget(
      _app(
        GptMarkdown('- E = mc<sup data-id="1">2</sup> here', htmlTags: _tags),
      ),
    );
    await tester.pumpAndSettle();
    final text = _text(tester);
    // One line: the element did not split the item into blocks.
    expect(text, contains('E = mc'));
    expect(text, contains(' here'));
    expect(text, isNot(contains('mc\n')));
    expect(find.text('SUP(2)'), findsOneWidget);
  });

  testWidgets('changing the map re-renders', (tester) async {
    await tester.pumpWidget(
      _app(GptMarkdown('a <u>under</u>', htmlTags: _tags)),
    );
    await tester.pumpAndSettle();
    expect(_text(tester), contains('<u>'));
    await tester.pumpWidget(_app(GptMarkdown('a <u>under</u>')));
    await tester.pumpAndSettle();
    expect(_text(tester), isNot(contains('<u>')));
  });
  testWidgets('<mark> takes its colours from the style sheet', (tester) async {
    await tester.pumpWidget(
      _app(
        const GptMarkdown(
          'a <mark>hot</mark> take',
          styleSheet: GptMarkdownStyleSheet(
            highlight: HighlightStyle(backgroundColor: Color(0xFFFFEB3B)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      _stylesOf(
        tester,
        'hot',
      ).any((s) => s?.backgroundColor == const Color(0xFFFFEB3B)),
      isTrue,
    );
  });

  testWidgets('<sup> and <sub> are smaller, scaled by the style sheet', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const GptMarkdown(
          'E = mc<sup>2</sup> and H<sub>9</sub>O',
          style: TextStyle(fontSize: 20),
          styleSheet: GptMarkdownStyleSheet(script: ScriptStyle(scale: 0.5)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(_stylesOf(tester, '2').map((s) => s?.fontSize), contains(10));
    expect(_stylesOf(tester, '9').map((s) => s?.fontSize), contains(10));
    expect(_text(tester), isNot(contains('<sup>')));
  });

  testWidgets('an HTML table renders as a table', (tester) async {
    await tester.pumpWidget(
      _app(
        const GptMarkdown(
          '<table><tr><th>Name</th><th>Age</th></tr>'
          '<tr><td>Ann</td><td>30</td></tr></table>',
        ),
      ),
    );
    await tester.pumpAndSettle();
    // Drawn by the HTML table grid, not Flutter's [Table].
    expect(find.byType(Table), findsNothing);
    final text = _text(tester);
    for (final cell in ['Name', 'Age', 'Ann', '30']) {
      expect(text, contains(cell));
    }
    expect(text, isNot(contains('<td>')));
  });

  testWidgets('an HTML list renders as a list, with task checkboxes', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const GptMarkdown(
          '<ol><li>First</li><li>Second</li></ol>\n\n'
          '<ul><li><input type="checkbox" checked> Done</li></ul>',
        ),
      ),
    );
    await tester.pumpAndSettle();
    final text = _text(tester);
    expect(text, contains('First'));
    expect(text, contains('Second'));
    expect(text, contains('Done'));
    expect(text, isNot(contains('<li>')));
    expect(find.byType(Checkbox), findsOneWidget);
  });
}
