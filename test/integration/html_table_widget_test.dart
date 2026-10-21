/// HTML tables through the real widget: cells spanning columns and rows,
/// header rows only where the HTML has them, `<tfoot>` last, a caption, and
/// the same sizing rules as a pipe table.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:material_ui/material_ui.dart';

Widget _app(Widget child, {ThemeData? theme}) => MaterialApp(
  theme: theme,
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

/// The rect of the text [text], rendered in its own cell.
Rect _rect(WidgetTester tester, String text) =>
    tester.getRect(find.text(text, findRichText: true));

/// The grid's render object.
Finder get _grid => find.byWidgetPredicate(
  (w) => w.runtimeType.toString() == '_HtmlTableLayout',
);

void main() {
  testWidgets('a cell spanning two columns covers both', (tester) async {
    await tester.pumpWidget(
      _app(
        const GptMarkdown(
          '<table>\n'
          '<tr><td colspan="2" align="center">wide</td></tr>\n'
          '<tr><td>a</td><td>b</td></tr>\n'
          '<tr><td>c</td><td>d</td><td>e</td></tr>\n'
          '</table>',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final a = _rect(tester, 'a');
    final b = _rect(tester, 'b');
    final c = _rect(tester, 'c');
    final d = _rect(tester, 'd');
    final e = _rect(tester, 'e');
    // b and d share the second column, e is alone in the third.
    expect(b.left, moreOrLessEquals(d.left));
    expect(a.left, moreOrLessEquals(c.left));
    expect(e.left, greaterThan(d.right));
    // Centred across the first two columns, not the first alone.
    final wide = _rect(tester, 'wide');
    final secondColumnEnd = e.left - 8; // e's cell padding
    expect(
      wide.center.dx,
      moreOrLessEquals((a.left - 8 + secondColumnEnd) / 2, epsilon: 1),
    );
  });

  testWidgets('a cell spanning two rows pushes the next row along', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const GptMarkdown(
          '<table>\n'
          '<tr><td rowspan="2">tall</td><td>x</td></tr>\n'
          '<tr><td>y</td></tr>\n'
          '<tr><td>z</td><td>w</td></tr>\n'
          '</table>',
        ),
      ),
    );
    await tester.pumpAndSettle();
    final tall = _rect(tester, 'tall');
    final x = _rect(tester, 'x');
    final y = _rect(tester, 'y');
    final z = _rect(tester, 'z');
    // y sits under x, in the second column, not under tall.
    expect(y.left, moreOrLessEquals(x.left));
    expect(z.left, moreOrLessEquals(tall.left));
    // tall is centred across the two rows it covers.
    expect(tall.center.dy, moreOrLessEquals((x.center.dy + y.center.dy) / 2));
  });

  testWidgets('a wide spanning cell widens the columns under it', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const GptMarkdown(
          '<table>\n'
          '<tr><td colspan="2">a long heading over two short columns</td></tr>\n'
          '<tr><td>1</td><td>2</td></tr>\n'
          '</table>',
        ),
      ),
    );
    await tester.pumpAndSettle();
    final heading = _rect(tester, 'a long heading over two short columns');
    final grid = tester.getRect(_grid);
    expect(grid.width, greaterThanOrEqualTo(heading.width + 16));
    // Still one line: the columns grew instead of the heading wrapping.
    expect(heading.height, lessThan(30));
  });

  testWidgets('only rows the HTML marks as header get the header fill', (
    tester,
  ) async {
    final theme = ThemeData(colorSchemeSeed: Colors.indigo);
    final header = theme.colorScheme.surfaceContainerHighest;

    await tester.pumpWidget(
      _app(
        theme: theme,
        const GptMarkdown(
          '<table><tr><td>a</td></tr><tr><td>b</td></tr></table>',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(_grid, isNot(paints..rect(color: header)));

    await tester.pumpWidget(
      _app(
        theme: theme,
        const GptMarkdown(
          '<table><thead><tr><td>h</td></tr></thead>'
          '<tr><td>b</td></tr></table>',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(_grid, paints..rect(color: header));

    await tester.pumpWidget(
      _app(
        theme: theme,
        const GptMarkdown(
          '<table><tr><th>h</th></tr><tr><td>b</td></tr></table>',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(_grid, paints..rect(color: header));
  });

  testWidgets('<tfoot> goes last and <caption> on top', (tester) async {
    await tester.pumpWidget(
      _app(
        const GptMarkdown(
          '<table>\n'
          '<caption>The caption</caption>\n'
          '<tfoot><tr><td>foot</td></tr></tfoot>\n'
          '<tbody><tr><td>body</td></tr></tbody>\n'
          '<thead><tr><th>head</th></tr></thead>\n'
          '</table>',
        ),
      ),
    );
    await tester.pumpAndSettle();
    final caption = _rect(tester, 'The caption');
    final head = _rect(tester, 'head');
    final body = _rect(tester, 'body');
    final foot = _rect(tester, 'foot');
    expect(caption.bottom, lessThanOrEqualTo(head.top));
    expect(head.bottom, lessThanOrEqualTo(body.top));
    expect(body.bottom, lessThanOrEqualTo(foot.top));
  });

  testWidgets('right to left, the first column is on the right', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const GptMarkdown(
          '<table><tr><td colspan="2">wide</td><td>end</td></tr>'
          '<tr><td>one</td><td>two</td><td>three</td></tr></table>',
          textDirection: TextDirection.rtl,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final one = _rect(tester, 'one');
    final two = _rect(tester, 'two');
    final three = _rect(tester, 'three');
    final end = _rect(tester, 'end');
    expect(one.left, greaterThan(two.right));
    expect(two.left, greaterThan(three.right));
    expect(end.right, lessThanOrEqualTo(three.right + 1));
  });

  testWidgets('tableBuilder still gets the rows, header flags from the HTML', (
    tester,
  ) async {
    List<CustomTableRow>? rows;
    await tester.pumpWidget(
      _app(
        GptMarkdown(
          '<table><tr><td colspan="2">a</td></tr>'
          '<tr><td>b</td><td>c</td></tr></table>',
          tableBuilder: (context, tableRows, style, config) {
            rows = tableRows;
            return const SizedBox();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(rows, hasLength(2));
    expect(rows!.every((r) => !r.isHeader), isTrue);
    expect(rows!.first.fields.map((f) => f.data), ['a', '']);
    expect(rows!.last.fields.map((f) => f.data), ['b', 'c']);
  });

  testWidgets('works inside IntrinsicWidth and wraps in a narrow space', (
    tester,
  ) async {
    const source =
        '<table><tr><td colspan="2">a heading that is rather long</td></tr>'
        '<tr><td rowspan="2">left</td><td>right one</td></tr>'
        '<tr><td>right two</td></tr></table>';
    await tester.pumpWidget(
      _app(const IntrinsicWidth(child: GptMarkdown(source))),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      _app(
        const SizedBox(
          width: 120,
          child: GptMarkdown(
            source,
            styleSheet: GptMarkdownStyleSheet(
              table: TableStyle(overflow: TableOverflow.wrap),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(tester.getRect(_grid).width, lessThanOrEqualTo(120));
  });

  testWidgets('spans past the edge are clipped, absurd spans capped', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const GptMarkdown(
          '<table><tbody><tr><td rowspan="9">a</td><td>b</td></tr></tbody>'
          '<tfoot><tr><td colspan="100000">c</td></tr></tfoot></table>',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    // The rowspan stops at the end of <tbody>, so c starts a row of its own.
    expect(_rect(tester, 'c').top, greaterThan(_rect(tester, 'a').bottom));
  });

  testWidgets('a table streaming in renders the rows it has', (tester) async {
    await tester.pumpWidget(
      _app(const GptMarkdown('<table>\n<tr><td>1</td></tr>\n<tr><td>2')),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('2', findRichText: true), findsOneWidget);
  });
}
