/// The streaming helpers agree with the parser about the CommonMark syntax
/// it gained: `_` emphasis, N-backtick code spans, `~~~` and long fences,
/// setext underlines, reference definitions, HTML comments and Pandoc-style
/// `$` maths.
///
/// Each helper makes a guess about text that has not finished arriving. A
/// guess that disagrees with the parser shows text in one form and restyles
/// it a moment later, which is the artefact the helpers exist to prevent.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:gpt_markdown/streaming/math_stream.dart';

void main() {
  group('inlineSafeLength', () {
    test('holds an open _ or __ emphasis', () {
      expect(inlineSafeLength('say _hello'), 'say '.length);
      expect(inlineSafeLength('say __hello'), 'say '.length);
      expect(inlineSafeLength('say _hello_ there'), 'say _hello_ there'.length);
    });

    test('never holds an underscore inside a word', () {
      const source = 'call snake_case_name now';
      expect(inlineSafeLength(source), source.length);
    });

    test('a double-backtick span closes only on a double backtick', () {
      expect(inlineSafeLength('run `` a`b'), 'run '.length);
      const closed = 'run `` a`b `` done';
      expect(inlineSafeLength(closed), closed.length);
    });

    test('holds a possible setext underline still arriving', () {
      expect(inlineSafeLength('Title\n-'), 'Title\n'.length);
      expect(inlineSafeLength('Title\n=='), 'Title\n'.length);
      const settled = 'Title\n---\n';
      expect(inlineSafeLength(settled), settled.length);
    });

    test('holds a reference definition line until it ends', () {
      expect(inlineSafeLength('text\n\n[1]: https://exa'), 'text\n\n'.length);
      const done = 'text\n\n[1]: https://example.com\n';
      expect(inlineSafeLength(done), done.length);
    });

    test('a lone table pipe after a leading newline does not throw', () {
      expect(inlineSafeLength('\n|'), greaterThanOrEqualTo(0));
    });

    test('holds a line that is only a list marker so far', () {
      expect(inlineSafeLength('1. one\n2'), '1. one\n'.length);
      expect(inlineSafeLength('1. one\n2.'), '1. one\n'.length);
      expect(inlineSafeLength('- one\n*'), '- one\n'.length);
    });

    test('never shows a list marker whose content is held', () {
      // The open code span holds `curr`; the `2. ` before it waits too.
      expect(inlineSafeLength('1. one\n2. `curr'), '1. one\n'.length);
      expect(inlineSafeLength('- a\n- [ ] `x'), '- a\n'.length);
    });

    test('holds a bare [label] line that may become a definition', () {
      expect(inlineSafeLength('text\n\n[1]'), 'text\n\n'.length);
      const citation = 'text\n\n[1] the source';
      expect(inlineSafeLength(citation), citation.length);
    });

    test('a list marker that starts a segment is held too', () {
      // A list after a blank line begins a new segment, so its first marker
      // has no line above it.
      expect(inlineSafeLength('1'), 0);
      expect(inlineSafeLength(r'1. \[ x'), 0);
    });

    test('a finished first table line waits for its delimiter row', () {
      expect(inlineSafeLength('Intro.\n| a | b |\n'), 'Intro.\n'.length);
      // A row under an existing table is final.
      const rows = '| a | b |\n|---|---|\n| 1 | 2 |\n';
      expect(inlineSafeLength(rows), rows.length);
    });

    test('a body row starting under a delimiter row holds only itself', () {
      const source = '| a | b |\n|---|---|\n| ';
      expect(inlineSafeLength(source), '| a | b |\n|---|---|\n'.length);
    });

    test('a delimiter row still arriving holds its header', () {
      expect(inlineSafeLength('| a | b |\n|--'), 0);
    });

    test('a hold at the very start does not throw', () {
      expect(inlineSafeLength('`open'), 0);
    });

    test('holds an HTML comment until it closes', () {
      expect(inlineSafeLength('a <!-- b'), 'a '.length);
      expect(inlineSafeLength('a <!'), 'a '.length);
      const done = 'a <!-- b --> c';
      expect(inlineSafeLength(done), done.length);
    });

    test('holds a tag or an autolink until its > arrives', () {
      expect(inlineSafeLength('see <b'), 'see '.length);
      expect(inlineSafeLength('see <a href="https://x'), 'see '.length);
      expect(inlineSafeLength('go to <https://exa'), 'go to '.length);
      expect(inlineSafeLength('mail <me@exa'), 'mail '.length);
      // Not a tag the parser knows: prose.
      const prose = 'if a <y then';
      expect(inlineSafeLength(prose), prose.length);
      const spaced = 'a < b';
      expect(inlineSafeLength(spaced), spaced.length);
    });

    test('holds an allowlisted tag until it closes', () {
      expect(inlineSafeLength('a <b>bold'), 'a '.length);
      expect(inlineSafeLength('a <script>x('), 'a '.length);
      const done = 'a <b>bold</b> done';
      expect(inlineSafeLength(done), done.length);
      const unknown = 'a <blink>2';
      expect(inlineSafeLength(unknown), unknown.length);
    });

    test('holds a [label]: whose destination is on the next line', () {
      expect(inlineSafeLength('text\n\n[foo]:\n/ur'), 'text\n\n'.length);
    });

    test(r'a price waiting for a partner is not held', () {
      for (final prices in [
        r'from $5 to',
        r'from $5 and $10 to',
        r'costs 5$ and',
        r'$2 sin',
      ]) {
        expect(inlineSafeLength(prices, holdMathDollars: true), prices.length);
      }
    });

    test(r'a $ before a space waits for its partner', () {
      expect(
        inlineSafeLength(r'so $ sin', holdMathDollars: true),
        'so '.length,
      );
      const closed = r'so $ sin $ and';
      expect(inlineSafeLength(closed, holdMathDollars: true), closed.length);
    });

    test(r'an open $x is held, a closed $x$ is not', () {
      expect(inlineSafeLength(r'so $x', holdMathDollars: true), 'so '.length);
      const closed = r'so $x$ and more';
      expect(inlineSafeLength(closed, holdMathDollars: true), closed.length);
    });

    test(r'a $ does not pair across a line break', () {
      const source = 'cost \$x\nand \$y\$ here';
      // `$x` never closed on its line, so it is prose; `$y$` is closed.
      expect(inlineSafeLength(source, holdMathDollars: true), source.length);
    });
  });

  group('completeOpenMath', () {
    test(r'a price or a $ before whitespace is not drawn open', () {
      expect(completeOpenMath(r'pay $ 5', dollarsAreMath: true), isNull);
      expect(completeOpenMath(r'pay $5', dollarsAreMath: true), isNull);
      expect(completeOpenMath(r'pay 5$ or', dollarsAreMath: true), isNull);
    });

    test(r'an open $x on the last line completes', () {
      final open = completeOpenMath(r'so $x^2', dollarsAreMath: true);
      expect(open, isNotNull);
      expect(open!.start, 3);
      expect(open.completed, r'\(x^2 \)');
    });

    test(r'an unclosed $ on an earlier line is prose', () {
      expect(completeOpenMath('so \$x\nnext', dollarsAreMath: true), isNull);
    });

    test(r'a closed $x$ is not reopened', () {
      expect(completeOpenMath(r'$x$ and', dollarsAreMath: true), isNull);
    });

    test('a double-backtick span hides its maths', () {
      expect(completeOpenMath(r'`` \(x `` and', dollarsAreMath: false), isNull);
      expect(completeOpenMath(r'`` open \(x', dollarsAreMath: false), isNull);
    });
  });

  group('settledSplitOffset', () {
    test('a tilde fence with blank lines is not split inside', () {
      const source = 'Intro.\n\n~~~\na\n\nb\n~~~\n\nTail.';
      final offset = settledSplitOffset(source);
      expect(offset, 'Intro.\n\n'.length);
    });

    test('a long fence is not closed by a shorter one', () {
      const source = 'Intro.\n\n````\n```\n\nx\n';
      expect(settledSplitOffset(source), 0);
    });

    test('a comment with blank lines is not split inside', () {
      const source = 'Intro.\n\n<!--\na\n\nb\n';
      expect(settledSplitOffset(source), 0);
    });
  });
}
