/// Inline `<svg>`: parsed as an element with its markup raw, drawn as a
/// picture on a line of its own or inside one, held back while it streams,
/// and sized from `width`, `height` and `viewBox`.
library;

import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/custom_widgets/custom_error_image.dart';
import 'package:gpt_markdown/custom_widgets/svg_image.dart'
    show maxInlineSvgLength;
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:material_ui/material_ui.dart';

Widget _app(Widget child) => MaterialApp(
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

const _circle =
    '<svg width="40" height="20" viewBox="0 0 40 20">'
    '<circle cx="10" cy="10" r="8" fill="currentColor"/></svg>';

HtmlElementData _data(MdNode node) =>
    (node as MdCustomBlock).data as HtmlElementData;

void main() {
  group('parsing', () {
    test('on a line of its own: a block element, markup raw', () {
      final node = Plusparse.parse(
        '<svg viewBox="0 0 10 10">\n  <rect width="10" height="10"/>\n</svg>',
      ).children.single;
      final data = _data(node);
      expect(data.name, 'svg');
      expect(data.block, isTrue);
      expect(data.children, isEmpty);
      expect(data.source.trim(), '<rect width="10" height="10"/>');
      expect(data.attributes['viewbox'], '0 0 10 10');
    });

    test('inside a line: an inline element', () {
      final paragraph =
          Plusparse.parse('Icon $_circle here.').children.single as MdParagraph;
      expect(paragraph.children, hasLength(3));
      expect(_data(paragraph.children[1]).name, 'svg');
    });

    test('a blank line inside does not split it', () {
      final nodes = Plusparse.parse(
        '<svg width="10" height="10">\n<g>\n\n<rect/>\n</g>\n</svg>\n\nafter',
      ).children;
      expect(nodes, hasLength(2));
      expect(_data(nodes.first).source, contains('<rect/>'));
    });

    test('still streaming: the element is open', () {
      final node =
          Plusparse.parse('<svg width="10" height="10">\n<rect').children.single
              as MdCustomBlock;
      expect(node.closed, isFalse);
    });

    test('off with html: false, and remappable', () {
      expect(
        Plusparse.parse('<svg></svg>', html: MarkdownHtml.none).children.single,
        isA<MdParagraph>(),
      );
    });
  });

  group('rendering', () {
    testWidgets('a block <svg> draws at its stated size', (tester) async {
      await tester.pumpWidget(_app(const GptMarkdown('$_circle\n\nAfter')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final picture = find.byType(SvgPicture);
      expect(picture, findsOneWidget);
      expect(tester.getSize(picture), const Size(40, 20));
      expect(find.textContaining('<svg', findRichText: true), findsNothing);
    });

    testWidgets('an inline <svg> sits in the line', (tester) async {
      await tester.pumpWidget(_app(const GptMarkdown('Before $_circle after')));
      await tester.pumpAndSettle();
      expect(find.byType(SvgPicture), findsOneWidget);
      expect(find.textContaining('Before', findRichText: true), findsOneWidget);
    });

    testWidgets('size from the viewBox, and never wider than the space', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          const SizedBox(
            width: 200,
            child: GptMarkdown(
              '<svg viewBox="0 0 1000 500"><rect width="1000" height="500"/></svg>',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(SvgPicture)), const Size(200, 100));

      await tester.pumpWidget(
        _app(
          const GptMarkdown(
            '<svg width="60" viewBox="0 0 30 10"><rect width="30" height="10"/></svg>',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(SvgPicture)), const Size(60, 20));

      await tester.pumpWidget(
        _app(const GptMarkdown('<svg><rect width="5" height="5"/></svg>')),
      );
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(SvgPicture)), const Size(300, 150));
    });

    testWidgets('while streaming, a box of its size and no parse', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(const GptMarkdown('<svg width="40" height="20">\n<circle cx=')),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(SvgPicture), findsNothing);
      expect(find.textContaining('circle', findRichText: true), findsNothing);
    });

    testWidgets('oversized markup shows the error box', (tester) async {
      final huge =
          '<svg width="10" height="10">${'<g></g>' * (maxInlineSvgLength ~/ 7 + 1)}</svg>';
      await tester.pumpWidget(_app(GptMarkdown(huge)));
      await tester.pumpAndSettle();
      expect(find.byType(SvgPicture), findsNothing);
      expect(find.byType(CustomImageError), findsOneWidget);
    });

    testWidgets('currentColor follows the text colour', (tester) async {
      await tester.pumpWidget(
        _app(
          const GptMarkdown(
            _circle,
            style: TextStyle(color: Color(0xFF00AA00)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final picture = tester.widget<SvgPicture>(find.byType(SvgPicture));
      final loader = picture.bytesLoader as SvgStringLoader;
      expect(loader.theme?.currentColor, const Color(0xFF00AA00));
    });

    testWidgets('an app builder for svg still wins', (tester) async {
      await tester.pumpWidget(
        _app(
          GptMarkdown(
            _circle,
            htmlTags: {
              'svg': HtmlTag.block(
                (context, element) => Text('custom ${element.source.length}'),
                null,
                true,
              ),
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SvgPicture), findsNothing);
      expect(find.textContaining('custom', findRichText: true), findsOneWidget);
    });
  });
}
