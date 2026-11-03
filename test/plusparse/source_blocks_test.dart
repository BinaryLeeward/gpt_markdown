import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/plusparse/plusparse.dart';

void main() {
  test('list and quote transformations preserve repeated source lines', () {
    const text =
        '- first\n  > ## Same\n  >\n  > ```\n  > sample\n  > ```\n\n'
        '- second\n  > ## Same\n\n## Same';
    final blocks = Plusparse.scanBlocks(text, html: MarkdownHtml.none);
    final headings = blocks.where((b) => b.node is MdHeading).toList()
      ..sort((a, b) => a.startLine.compareTo(b.startLine));
    expect(headings.map((b) => (b.startLine, b.endLine)), [
      (1, 2),
      (8, 9),
      (10, 11),
    ]);
    final code = blocks.singleWhere((b) => b.node is MdCodeBlock);
    expect((code.startLine, code.endLine), (3, 6));
    expect(code.firstLine, '```');
  });

  test('custom blocks and normalized input keep verified line ranges', () {
    final blocks = Plusparse.scanBlocks(
      '# \u0000\n\n:::note\n# hidden\n:::\n',
      blockRegistry: MarkdownBlockRegistry([
        const FencedBlockSyntax(type: 'note', opening: ':::note'),
      ]),
    );
    expect(blocks.map((b) => (b.startLine, b.endLine)), [(0, 1), (2, 5)]);
    expect(blocks.first.firstLine, '# �');
    expect(blocks.last.node, isA<MdCustomBlock>());
    expect(Plusparse.scanBlocks(''), isEmpty);
    expect(Plusparse.scanBlocks('\r\n\r'), isEmpty);
  });

  test(
    'HTML wrappers keep real lines and synthetic descendants stay omitted',
    () {
      for (final tag in ['div', 'blockquote']) {
        final blocks = Plusparse.scanBlocks(
          '<$tag>\n# inner\n</$tag>\n\n# End',
        );
        final inner = blocks.where((b) => b.firstLine == '# inner');
        if (tag == 'div') {
          expect(inner.single.startLine, 1);
        } else {
          expect(inner, isEmpty);
        }
        expect(blocks.last.startLine, 4);
        expect(blocks.last.node, isA<MdHeading>());
      }
    },
  );
  test('nested duplicate headings keep their original lines', () {
    const text = '# Same\n\n> ## Same\n>\n> - ### Same\n\n# Same';
    for (final eol in ['\n', '\r\n', '\r']) {
      final blocks = Plusparse.scanBlocks(
        text.replaceAll('\n', eol),
        html: MarkdownHtml.none,
      );
      final headings = blocks.where((b) => b.node is MdHeading).toList()
        ..sort((a, b) => a.startLine.compareTo(b.startLine));
      expect(headings.map((b) => (b.startLine, b.endLine)), [
        (0, 1),
        (2, 3),
        (4, 5),
        (6, 7),
      ]);
      expect(headings.map((b) => b.firstLine), [
        '# Same',
        '## Same',
        '### Same',
        '# Same',
      ]);
      expect(headings.map((b) => (b.node as MdHeading).level), [1, 2, 3, 1]);
    }
  });

  test('literal comments follow paragraph and container membership', () {
    for (final prefix in [
      '',
      'intro\n',
      '> intro\n',
      '> # Heading\n',
      '> ```\n> code\n',
      '- intro\n',
    ]) {
      for (final trailing in ['', ' tail']) {
        final text = '$prefix<!--\n```sh\n- flag\n```\n-->$trailing';
        final blocks = Plusparse.scanBlocks(text, html: MarkdownHtml.none);
        final flagLine = text.split('\n').indexOf('- flag');
        final code = blocks
            .where(
              (b) =>
                  b.node is MdCodeBlock &&
                  b.startLine <= flagLine &&
                  b.endLine > flagLine,
            )
            .toList();
        final visible =
            trailing.isNotEmpty ||
            prefix == 'intro\n' ||
            prefix == '> intro\n' ||
            prefix == '- intro\n';
        expect(code, visible ? hasLength(1) : isEmpty, reason: text);
        if (visible) {
          expect(code.single.fenced, isTrue);
          expect((code.single.node as MdCodeBlock).closed, isTrue);
        }
      }
    }
  });

  test(
    'unfinished fences, lazy lines, tabs and hidden boundaries stay located',
    () {
      const text = '> intro\ncontinued\n\n- item\n\n\t```\n\tcode';
      final blocks = Plusparse.scanBlocks(text, html: MarkdownHtml.none);
      final paragraph = blocks.firstWhere((b) => b.node is MdParagraph);
      expect((paragraph.startLine, paragraph.endLine), (0, 2));
      final code = blocks.singleWhere((b) => b.node is MdCodeBlock);
      expect((code.startLine, code.endLine), (5, 7));
      expect(code.firstLine.trimLeft(), '```');
      expect((code.node as MdCodeBlock).closed, isFalse);

      final hidden = Plusparse.scanBlocks(
        '<!--\n`hidden`\n-->\n\n[x]: target',
        html: MarkdownHtml.none,
      ).where((b) => b.node == null);
      expect(hidden.map((b) => (b.startLine, b.endLine)), [(0, 3), (4, 5)]);
    },
  );

  test('alert metadata follows the displayed body only', () {
    const text = '> [!NOTE]\n> <!--\n> ```\n> hidden\n> ```\n> -->\n> # End';
    final blocks = Plusparse.scanBlocks(text, html: MarkdownHtml.none);
    expect(blocks.where((b) => b.node is MdCodeBlock), isEmpty);
    final heading = blocks.singleWhere((b) => b.node is MdHeading);
    expect(
      (heading.startLine, heading.endLine, heading.firstLine),
      (6, 7, '# End'),
    );
  });

  test('footnote body coordinates use the same definition visibility', () {
    const body = '[^x]: note\n\n    ```\n    sample\n    ```';
    expect(
      Plusparse.scanBlocks(body).where((b) => b.node is MdCodeBlock),
      isEmpty,
    );
    final blocks = Plusparse.scanBlocks('ref[^x]\n\n$body');
    final code = blocks.singleWhere((b) => b.node is MdCodeBlock);
    expect((code.startLine, code.endLine), (4, 7));
    expect(code.firstLine, '```');
  });

  test(
    'block scan skips inline work without changing default inline parsing',
    () {
      const text = '# **Title**\n\n[a](target) and *text*\n';
      final blocks = Plusparse.scanBlocks(text);
      expect((blocks.first.node as MdHeading).children, isEmpty);
      expect((blocks.last.node as MdParagraph).children, isEmpty);
      final parsed = Plusparse.parse(text);
      expect(
        (parsed.children.first as MdHeading).children.single,
        isA<MdBold>(),
      );
    },
  );
}
