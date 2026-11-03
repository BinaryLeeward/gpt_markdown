import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/plusparse/plusparse.dart';
import 'package:gpt_markdown/plusparse/inline_parser.dart' as inline;

MdDocument document(String source, MarkdownDialect dialect) =>
    Plusparse.parse(source, useDollarSignsForLatex: true, dialect: dialect);
List<MdNode> paragraph(String source, MarkdownDialect dialect) =>
    (document(source, dialect).children.single as MdParagraph).children;

void main() {
  const dialect = MarkdownDialect.commonmark;
  test(
    'default chat citations, bracket math and table escapes remain unchanged',
    () {
      final original = Plusparse.parse(
        r'[1] \(a\) \[b\] $ a $',
        useDollarSignsForLatex: true,
      );
      final nodes = (original.children.single as MdParagraph).children;
      expect(nodes.whereType<MdSourceTag>().single.id, '1');
      expect(nodes.whereType<MdInlineLatex>().map((n) => n.tex), ['a', 'a']);
      expect(nodes.whereType<MdBlockLatex>().single.tex, 'b');
      final table =
          document(
                '| A |\n|---|\n| `x\\|y` |',
                MarkdownDialect.chat,
              ).children.single
              as MdTable;
      expect(
        (table.rows.single.cells.single.content.single as MdInlineCode).text,
        r'x\|y',
      );
    },
  );
  test('numeric brackets use the ordinary link resolution path', () {
    expect(
      paragraph(
        'array[0] and list[1]',
        dialect,
      ).whereType<MdText>().map((n) => n.text).join(),
      'array[0] and list[1]',
    );
    for (final label in ['[text][1]', '[1]', '[1][]']) {
      final doc = document('[1]: http://x\n\n$label', dialect);
      final link =
          (doc.children.single as MdParagraph).children.single as MdLink;
      expect(link.url, 'http://x');
    }
  });
  for (final source in [
    r'\[1\]',
    r'array\[0\]',
    r'\[see note\]',
    r'\(a\)',
    r'\(see above\)',
  ]) {
    test('brackets escape in every inline entry: $source', () {
      final expected = source.replaceAll('\\', '');
      expect(
        paragraph(
          source,
          dialect,
        ).whereType<MdText>().map((n) => n.text).join(),
        expected,
      );
      expect(
        inline
            .parseInline(source, true, MarkdownDefinitions.empty, null, dialect)
            .whereType<MdText>()
            .map((n) => n.text)
            .join(),
        expected,
      );
    });
  }
  for (final source in [
    r'$HOME and $PATH',
    r'echo $A $B',
    r'${A} and ${B}',
    r'$(a) and $(b)',
    r'$5 and $10',
    r'100$ and 200$',
    r'$ x$',
    r'$x $',
    r'$x$2',
    r'$x$$',
    '\$x\ny\$',
    '\$x\ry\$',
    '\$\tx\$',
    '\$x\t\$',
    '\$\u00a0x\$',
    '\$x\u00a0\$',
    '\$\uFEFFx\$',
  ]) {
    test('strict single dollars stay literal: $source', () {
      expect(paragraph(source, dialect).whereType<MdInlineLatex>(), isEmpty);
    });
  }
  for (final (source, tex) in [
    (r'$x^2$', 'x^2'),
    (r'$E=mc^2$', 'E=mc^2'),
    (r'$a + b$', 'a + b'),
    (r'$a and b$', 'a and b'),
    (r'$a\$b$', r'a\$b'),
    (r'$a\\$', r'a\\'),
    (r'$$x^2$$', 'x^2'),
  ]) {
    test('strict dollars preserve valid formulas: $source', () {
      expect(
        paragraph(source, dialect).whereType<MdInlineLatex>().single.tex,
        tex,
      );
    });
  }
  test(
    'block scanning and definitions share the bracket dialect in containers',
    () {
      for (final prefix in ['', '> ', '- ']) {
        final inner = r'\[' + '\n\n[1]: http://x\n\n' + r'\]';
        final source = prefix == '- '
            ? '- ' +
                  inner
                      .split('\n')
                      .asMap()
                      .entries
                      .map((e) => e.key == 0 ? e.value : '  ${e.value}')
                      .join('\n') +
                  '\n\n[text][1]'
            : inner.split('\n').map((line) => '$prefix$line').join('\n') +
                  '\n\n[text][1]';
        final defs = MarkdownDefinitions.collect(source, dialect: dialect);
        expect(defs.link('1')?.url, 'http://x');
        expect(
          Plusparse.scanBlocks(
            source,
            dialect: dialect,
          ).any((b) => b.node is MdBlockLatex),
          isFalse,
        );
        expect(document(source, dialect).children.last, isA<MdParagraph>());
      }
      final source = '\\\n'; // A literal hard break remains supported.
      expect(
        inline.parseInline(
          source,
          true,
          MarkdownDefinitions.empty,
          null,
          dialect,
        ),
        contains(isA<MdLineBreak>()),
      );
    },
  );
  test(
    'dollar blocks keep definitions and headings opaque in parse and scan',
    () {
      const source = '\$\$\n# literal\n[1]: /hidden\n\nx^2\n\$\$\n\n# Real';
      final defs = MarkdownDefinitions.collect(
        source,
        dialect: dialect,
        useDollarSignsForLatex: true,
      );
      expect(defs.link('1'), isNull);
      final doc = document(source, dialect);
      expect(doc.children.first, isA<MdBlockLatex>());
      expect(doc.children.whereType<MdHeading>(), hasLength(1));
      expect(
        Plusparse.scanBlocks(
          source,
          dialect: dialect,
          useDollarSignsForLatex: true,
        ).map((b) => b.node.runtimeType),
        [MdBlockLatex, MdHeading],
      );
    },
  );
  test(
    'table code unescapes only pipe escapes, including headers and containers',
    () {
      for (final prefix in ['', '> ', '- ']) {
        final source = ['| `x\\|y` | B |', '|---|---|', '| ``a\\|b\\c`` | z |'];
        final text = prefix == '- '
            ? '- item\n\n${source.map((l) => '  $l').join('\n')}'
            : source.map((l) => '$prefix$l').join('\n');
        MdTable table(MdNode n) {
          if (n is MdTable) return n;
          if (n is MdBlockQuote) return table(n.children.single);
          return table((n as MdUnorderedList).items.single.children.last);
        }

        final parsed = table(document(text, dialect).children.single);
        expect(parsed.header.cells, hasLength(2));
        expect(
          (parsed.header.cells.first.content.single as MdInlineCode).text,
          'x|y',
        );
        expect(
          (parsed.rows.single.cells.first.content.single as MdInlineCode).text,
          r'a|b\c',
        );
      }
      expect(
        (paragraph(r'`x\|y`', dialect).single as MdInlineCode).text,
        r'x\|y',
      );
    },
  );
  test('tables use the same dollar boundaries as inline parsing', () {
    for (final (row, columns) in [
      (r'$A | $B', 2),
      (r'$a | b$ | end', 2),
      (r'$a | b$2 | end', 3),
      (r'\(a | b\) | end', 3),
      (r'$$a | b$$ | end', 2),
    ]) {
      final table =
          document(
                '| a | b | c |\n|---|---|---|\n| $row |',
                dialect,
              ).children.single
              as MdTable;
      expect(table.rows.single.cells, hasLength(columns));
    }
  });
  test(
    'links, footnotes, tasks, code and fences preserve their native nodes',
    () {
      final doc = document(
        '[text](url) note[^n]\n\n- [x] done\n\n`[1] \$x\$`\n\n```text\n[1] \$x\$\n```\n\n[^n]: body',
        dialect,
      );
      final first = doc.children.first as MdParagraph;
      expect(first.children.whereType<MdLink>().single.url, 'url');
      expect(first.children.whereType<MdFootnoteReference>().single.number, 1);
      expect(
        doc.children
            .whereType<MdUnorderedList>()
            .single
            .items
            .single
            .children
            .single,
        isA<MdCheckbox>(),
      );
      expect(doc.children.whereType<MdCodeBlock>().single.code, r'[1] $x$');
      expect(doc.children.whereType<MdFootnoteDefinitions>(), hasLength(1));
    },
  );
}
