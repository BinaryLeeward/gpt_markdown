/// The HTML rule table ([MarkdownHtml]): the parser, the segment splitters
/// and the streaming hold all read it, so a tag means one thing everywhere —
/// and an app can change what any tag means.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

List<MdNode> _parse(String markdown, [MarkdownHtml? html]) =>
    Plusparse.parse(markdown, html: html).children;

List<MdNode> _inline(String markdown, [MarkdownHtml? html]) =>
    (_parse(markdown, html).single as MdParagraph).children;

HtmlElementData _data(MdNode node) =>
    (node as MdCustomBlock).data as HtmlElementData;

/// A table element's content, one string per child: `name{attributes}`
/// then its rows or cells in `[…]`, or a cell's plain text in `(…)`.
List<String> _shape(HtmlElementData table) {
  String text(List<MdNode> nodes) => nodes
      .map(
        (n) => switch (n) {
          MdText(:final text) => text,
          MdLineBreak() => '⏎',
          MdBold(:final children) => text(children),
          _ => '?',
        },
      )
      .join();
  String one(MdNode node) {
    final data = _data(node);
    final attributes = data.attributes.isEmpty
        ? ''
        : '{${data.attributes.entries.map((e) => '${e.key}: ${e.value}').join(', ')}}';
    final inner = data.block
        ? '[${data.children.map(one).join(' ')}]'
        : '(${text(data.children)})';
    return '${data.name}$attributes$inner';
  }

  return [for (final child in table.children) one(child)];
}

void main() {
  group('the table', () {
    test('none leaves every tag as text', () {
      final nodes = _inline('<b>x</b> a<br>b', MarkdownHtml.none);
      expect(nodes.single, isA<MdText>());
      expect((nodes.single as MdText).text, '<b>x</b> a<br>b');
    });

    test('extend adds, replaces and removes rules', () {
      final html = MarkdownHtml.defaults.extend({
        'mark': HtmlTagSyntax.bold,
        'b': null,
        'SUP': HtmlTagSyntax.inlineElement,
      });
      expect(html['mark'], HtmlTagSyntax.bold);
      expect(html['b'], isNull);
      expect(html['sup'], HtmlTagSyntax.inlineElement);
      expect(MarkdownHtml.defaults['b'], HtmlTagSyntax.bold);
      expect(_inline('<mark>m</mark>', html).single, isA<MdBold>());
      expect(_inline('<b>b</b>', html).single, isA<MdText>());
    });

    test('tables compare by value', () {
      expect(
        MarkdownHtml.defaults.extend({'x': HtmlTagSyntax.bold}),
        MarkdownHtml.defaults.extend({'x': HtmlTagSyntax.bold}),
      );
      expect(MarkdownHtml.defaults.extend({}), same(MarkdownHtml.defaults));
    });
  });

  group('elements', () {
    final html = MarkdownHtml.defaults.extend({
      'sup': HtmlTagSyntax.inlineElement,
      'details': HtmlTagSyntax.blockElement,
      'summary': HtmlTagSyntax.blockElement,
      'chart': const HtmlTagSyntax(HtmlTagKind.blockElement, rawContent: true),
      'input': HtmlTagSyntax.inlineElement,
    });

    test('an inline element keeps its name, attributes and content', () {
      final nodes = _inline('x<sup class="a&amp;b">2 *n*</sup> y', html);
      expect(nodes, hasLength(3));
      final data = _data(nodes[1]);
      expect(data.name, 'sup');
      expect(data.attributes, {'class': 'a&b'});
      expect(data.source, '2 *n*');
      expect(data.block, isFalse);
      expect(data.children.last, isA<MdItalic>());
    });

    test('a block element holds the Markdown blocks inside it', () {
      final nodes = _parse(
        'Before\n\n<details open>\n<summary>More</summary>\n\nBody *x*\n\n- a\n</details>\n\nAfter',
        html,
      );
      expect(nodes, hasLength(3));
      final details = nodes[1] as MdCustomBlock;
      expect(details.type, htmlElementType);
      expect(details.closed, isTrue);
      final data = _data(details);
      expect(data.block, isTrue);
      expect(data.attributes, {'open': ''});
      expect(data.children.first, isA<MdCustomBlock>());
      expect(_data(data.children.first).name, 'summary');
      expect(data.children[1], isA<MdParagraph>());
      expect(data.children[2], isA<MdUnorderedList>());
      expect(nodes.last, isA<MdParagraph>());
    });

    test('an unclosed block element runs to the end, marked open', () {
      final node = _parse('<details>\n\nstill arriving', html).single;
      expect((node as MdCustomBlock).closed, isFalse);
      expect(_data(node).children.single, isA<MdParagraph>());
    });

    test('nested elements of the same name pair up', () {
      final node = _parse(
        '<details>\nouter\n<details>\ninner\n</details>\n</details>\nafter',
        html,
      );
      expect(node, hasLength(2));
      expect(_data(node.first).children.last, isA<MdCustomBlock>());
    });

    test('raw content is kept as written, not parsed', () {
      final node = _parse('<chart>\n*a*: 1\n\nb: 2\n</chart>', html).single;
      final data = _data(node);
      expect(data.children, isEmpty);
      expect(data.source, '*a*: 1\n\nb: 2');
    });

    test('a void element has no content and no closing tag', () {
      final nodes = _inline('Done <input type="checkbox" checked> yes', html);
      expect(_data(nodes[1]).attributes, {'type': 'checkbox', 'checked': ''});
      expect(_data(nodes[1]).children, isEmpty);
      expect((nodes.last as MdText).text, ' yes');
    });

    test('definitions inside a block element count', () {
      final nodes = _parse('<details>\n[a]: /url\n</details>\n\n[a]', html);
      final link = (nodes.last as MdParagraph).children.single as MdLink;
      expect(link.url, '/url');
    });
  });

  group('built-in block tags', () {
    test('<h1>–<h6> are headings', () {
      final heading = _parse('<h2>The *title*</h2>').single as MdHeading;
      expect(heading.level, 2);
      expect(heading.children.last, isA<MdItalic>());
    });

    test('<blockquote> is a quote of the Markdown inside', () {
      final quote = _parse('<blockquote>\n**a**\n\nb\n</blockquote>').single;
      expect((quote as MdBlockQuote).children, hasLength(2));
    });

    test('a <pre> ends at its first closing tag, as raw text does', () {
      final nodes = _parse('<pre>a <pre> b</pre>\n\nafter');
      expect((nodes.first as MdCodeBlock).code, 'a <pre> b');
      expect(nodes.last, isA<MdParagraph>());
    });

    test('<pre> is a code block, its language from <code class>', () {
      final code =
          _parse(
                '<pre><code class="language-dart">if (a &lt; b) {}\n\nx();\n</code></pre>',
              ).single
              as MdCodeBlock;
      expect(code.language, 'dart');
      expect(code.code, 'if (a < b) {}\n\nx();');
    });
  });

  group('built-in inline tags', () {
    test('<sup>, <sub> and <mark> are their own nodes', () {
      final nodes = _inline('x<sup>2</sup> H<sub>2</sub>O <mark>*hot*</mark>');
      expect(nodes.whereType<MdSuperscript>(), hasLength(1));
      expect(nodes.whereType<MdSubscript>(), hasLength(1));
      final mark = nodes.whereType<MdHighlight>().single;
      expect(mark.children.single, isA<MdItalic>());
    });

    test('a checkbox inside a line is its glyph', () {
      expect(
        (_inline('a <input type="checkbox" checked> b').single as MdText).text,
        'a ☑ b',
      );
      expect(
        (_inline('a <input type="text"> b').single as MdText).text,
        'a <input type="text"> b',
      );
    });
  });

  group('pairing', () {
    /// The paragraph, `<b>` as `B{…}` and other formatting by name.
    String dump(String markdown) {
      String one(MdNode n) => switch (n) {
        MdText(:final text) => text,
        MdBold(:final children) => 'B{${children.map(one).join()}}',
        MdItalic(:final children) => 'I{${children.map(one).join()}}',
        MdUnderline(:final children) => 'U{${children.map(one).join()}}',
        MdHighlight(:final children) => 'M{${children.map(one).join()}}',
        MdLink(:final children, :final url) =>
          'A[$url]{${children.map(one).join()}}',
        MdInlineCode(:final text) => 'C{$text}',
        _ => n.runtimeType.toString(),
      };
      return _inline(markdown).map(one).join();
    }

    test('a closing tag takes the nearest opening tag before it', () {
      expect(
        dump('The <b> tag makes <b>text bold.</b>'),
        'The <b> tag makes B{text bold.}',
      );
    });

    test('a stray opening tag does not stop a later pair', () {
      expect(
        dump('The <b> tag makes text bold.<b>adsfasfaf</b>'),
        'The <b> tag makes text bold.B{adsfasfaf}',
      );
      expect(
        dump('The <b> tag. <b>x</b> and <b>y</b>'),
        'The <b> tag. B{x} and B{y}',
      );
    });

    test('an opening tag never closed stays text', () {
      expect(
        dump('The <b> tag makes text bold.'),
        'The <b> tag makes text bold.',
      );
      expect(dump('<b>x</b> then <b> alone'), 'B{x} then <b> alone');
    });

    test('real nesting still nests', () {
      expect(dump('a <b>one <b>two</b> three</b>'), 'a B{one B{two} three}');
    });

    test('every paired tag follows the same rule', () {
      expect(dump('an <i> tag, <i>this</i>'), 'an <i> tag, I{this}');
      expect(dump('a <u> tag, <u>this</u>'), 'a <u> tag, U{this}');
      expect(dump('a <mark> tag, <mark>this</mark>'), 'a <mark> tag, M{this}');
      expect(
        dump('an <a href="/x"> tag, <a href="/y">this</a>'),
        'an <a href="/x"> tag, A[/y]{this}',
      );
    });

    test('raw content ends at its first closing tag', () {
      expect(dump('<code>use <code> here</code>'), 'C{use <code> here}');
      expect(dump('<code>a</code> and <code>b</code>'), 'C{a} and C{b}');
      expect(dump('x <script>a<script>b</script> y'), 'x  y');
    });
  });

  group('HTML tables', () {
    test('a table keeps its sections, rows, cells and attributes', () {
      final table = _data(
        _parse(
          '<table>\n'
          '  <caption>Scores</caption>\n'
          '  <thead><tr><th align="left">Name</th>'
          '<th style="text-align: right">Score</th></tr></thead>\n'
          '  <tbody>\n'
          '    <tr><td>Ann</td><td>9<br>of 10</td></tr>\n'
          '    <tr><td colspan="2" rowspan="3"><b>Bo</b></td></tr>\n'
          '  </tbody>\n'
          '</table>',
        ).single,
      );
      expect(table.name, 'table');
      expect(_shape(table), [
        'caption(Scores)',
        'thead[tr[th{align: left}(Name) th{style: text-align: right}(Score)]]',
        'tbody[tr[td(Ann) td(9⏎of 10)] tr[td{colspan: 2, rowspan: 3}(Bo)]]',
      ]);
      final bold = _data(
        _data(_data(table.children[2]).children[1]).children[0],
      );
      expect(bold.children.single, isA<MdBold>());
      expect(bold.block, isFalse);
    });

    test('rows outside a section, and cells outside a row, are kept', () {
      final table = _data(
        _parse('<table><td>a</td><tr><td>b</td></tr></table>').single,
      );
      expect(_shape(table), ['tr[td(a)]', 'tr[td(b)]']);
    });

    test('empty rows and sections are dropped', () {
      final table = _data(
        _parse(
          '<table><thead></thead><tr></tr><tr><td>x</td></tr></table>',
        ).single,
      );
      expect(_shape(table), ['tr[td(x)]']);
    });

    test('a table still streaming in shows its rows so far', () {
      final node =
          _parse(
                '<table>\n<tr><th>A</th></tr>\n<tr><td>1</td></tr>\n<tr><td>2',
              ).single
              as MdCustomBlock;
      expect(node.closed, isFalse);
      expect(_shape(node.data as HtmlElementData), [
        'tr[th(A)]',
        'tr[td(1)]',
        'tr[td(2)]',
      ]);
    });
  });

  group('HTML lists', () {
    test('<ul> items, with a nested list and Markdown inside', () {
      final list =
          _parse(
                '<ul>\n'
                '  <li>One **bold**</li>\n'
                '  <li>Two\n'
                '    <ol start="3"><li>three</li><li>four</li></ol>\n'
                '  </li>\n'
                '</ul>',
              ).single
              as MdUnorderedList;
      expect(list.items, hasLength(2));
      expect(list.items.first.children.last, isA<MdBold>());
      final nested = list.items.last.children.last as MdOrderedList;
      expect(nested.start, 3);
      expect(nested.items.map((i) => i.number), [3, 4]);
    });

    test('a checkbox in an item makes a task list', () {
      final list =
          _parse(
                '<ul><li><input type="checkbox" checked> done</li>'
                '<li><input type="checkbox"> todo</li></ul>',
              ).single
              as MdUnorderedList;
      final first = list.items.first.children.single as MdCheckbox;
      final second = list.items.last.children.single as MdCheckbox;
      expect(first.checked, isTrue);
      expect(second.checked, isFalse);
      expect((second.children.single as MdText).text, 'todo');
    });

    test('a checkbox line is a checkbox block', () {
      final checkbox =
          _parse('Tasks:\n<input type="checkbox" checked> Ship it').last
              as MdCheckbox;
      expect(checkbox.checked, isTrue);
    });
  });

  group('splitting a stream', () {
    test('a block element with blank lines stays one segment', () {
      const source = 'Intro\n\n<pre>\na\n\nb\n</pre>\n\nAfter';
      expect(splitStreamSegments(source), [
        'Intro',
        '<pre>\na\n\nb\n</pre>',
        'After',
      ]);
      expect(settledSplitOffset(source), 'Intro\n\n'.length);
    });

    test("an app's block element is kept whole too", () {
      final html = MarkdownHtml.defaults.extend({
        'details': HtmlTagSyntax.blockElement,
      });
      const source = '<details>\na\n\nb\n</details>\n\nAfter';
      expect(splitStreamSegments(source, html: html), [
        '<details>\na\n\nb\n</details>',
        'After',
      ]);
      // By default `<details>` is a wrapper, and is split like text.
      expect(splitStreamSegments(source), hasLength(3));
    });
  });

  group('streaming hold', () {
    test('a tag the table does not know is not held', () {
      expect(
        inlineSafeLength('a <b>open', html: MarkdownHtml.none),
        'a <b>open'.length,
      );
      expect(inlineSafeLength('a <blink>2'), 'a <blink>2'.length);
    });

    test('the innermost unclosed tag is the one waited on', () {
      // A first <b> that was only mentioned does not hold the words after it.
      const source = 'The <b> tag makes <b>text bo';
      expect(inlineSafeLength(source), 'The <b> tag makes '.length);
      // Once the second pair closes, the first <b> is the only one open and
      // could still be closed later, so the bare scan holds from it again;
      // the view's high-water mark keeps what was already shown.
      const closed = 'The <b> tag makes <b>text bold.</b> more';
      expect(inlineSafeLength(closed), 'The '.length);
      expect(inlineSafeLength('<b>x</b> and <i>y'), '<b>x</b> and '.length);
    });

    test('inside raw content nothing else is waited on', () {
      const closed = 'a <code><b></code> rest';
      expect(inlineSafeLength(closed), closed.length);
      expect(inlineSafeLength('a <code><b>x'), 'a '.length);
    });

    test("an app's inline element is held until it closes", () {
      final html = MarkdownHtml.defaults.extend({
        'sup': HtmlTagSyntax.inlineElement,
      });
      expect(inlineSafeLength('a <sup>2', html: html), 'a '.length);
      expect(inlineSafeLength('a <su', html: html), 'a '.length);
    });
  });
}
