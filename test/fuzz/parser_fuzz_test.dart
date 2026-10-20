/// Random Markdown — and every prefix of it, as a stream delivers it — must
/// never make the parser, the streaming helpers or the widget throw, and must
/// parse in bounded time.
///
/// Documents are built from fragments of every construct the package knows,
/// glued together at random, so unbalanced and half-written syntax is the
/// normal case. Seeds are fixed: a failure prints the seed and the document,
/// and reproduces exactly.
///
/// CI runs a small sample. For a long local run:
///
/// ```sh
/// FUZZ_SCALE=50 flutter test test/fuzz
/// ```
library;

import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:gpt_markdown/streaming/math_stream.dart';

/// How many times the CI sample to run.
final int _scale = int.tryParse(Platform.environment['FUZZ_SCALE'] ?? '') ?? 1;

const _fragments = <String>[
  // Text.
  'word', 'two words', ' ', '  ', '\t', 'é', '😀', 'العربية', '中文', '123',
  // Line structure.
  '\n', '\n', '\n\n', '\n    ', '\n  ', '\n>', '\n> ', '\n- ', '\n* ', '\n+ ',
  '\n1. ', '\n2) ', '\n14. ', '\n# ', '\n## ', '\n###### ', '\n---', '\n===',
  '\n***', '\n- [ ] ', '\n- [x] ', '\n(x) ', '\n[x] ',
  // Emphasis and code.
  '*', '**', '***', '_', '__', '~~', '~', '`', '``', '```', '\n```dart\n',
  '\n~~~\n', '\n````\n',
  // Links, images, references, footnotes, citations.
  '[', ']', '(', ')', '![', '](', '[link](https://x.y "t")', '[1]', '[^1]',
  '\n[1]: https://x.y', '\n[^1]: note', '\n[ref]: /url', '[ref]', '[ref][]',
  '<https://x.y>', '<a@b.c>', 'https://x.y/a_b', 'www.x.y',
  // Maths.
  r'\(', r'\)', r'\[', r'\]', r'$', r'$$', r'x^2', r'\frac{a}{b}', r'$5',
  // Escapes and entities.
  r'\*', r'\\', r'\', '&amp;', '&#169;', '&#x1F600;', '&', '&nbsp', ';',
  // Tables.
  '|', '\n| a | b |', '\n|---|:-:|', '\n| 1 | 2 |',
  // HTML.
  '<', '>', '</', '<b>', '</b>', '<br>', '<img src="x.png">', '<a href="x">',
  '</a>', '<div>', '</div>', '\n<div align="center">\n', '<span>', '</span>',
  '<sup>', '</sup>', '<mark>', '<kbd>', '<code>', '</code>', '\n<table>\n',
  '<tr>', '<td>', '<th>', '</td>', '</tr>', '\n</table>\n', '\n<ul>\n',
  '<li>', '</li>', '\n</ul>\n', '<ol start="3">', '</ol>',
  '<input type="checkbox" checked>', '\n<pre><code>', '</code></pre>\n',
  '<script>', '</script>', '<!--', '-->', '\n<details>\n', '<summary>',
  '</summary>', '\n</details>\n', '<blockquote>', '</blockquote>', '<h2>',
  '</h2>', '<x-custom a=1>', '</x-custom>', '<!-- c -->', 'a="',
  // Alerts and extensions.
  '\n> [!NOTE]\n> ', '\n:::note\n', '\n:::\n',
];

String _document(Random random, int maxFragments) {
  final buffer = StringBuffer();
  final count = random.nextInt(maxFragments) + 1;
  for (var i = 0; i < count; i++) {
    buffer.write(_fragments[random.nextInt(_fragments.length)]);
  }
  return buffer.toString();
}

final _customHtml = MarkdownHtml.defaults.extend({
  'details': HtmlTagSyntax.blockElement,
  'summary': HtmlTagSyntax.blockElement,
  'x-custom': HtmlTagSyntax.inlineElement,
  'b': null,
});

void main() {
  test('random documents parse, in bounded time', () {
    for (var seed = 0; seed < 600 * _scale; seed++) {
      final source = _document(Random(seed), 300);
      final watch = Stopwatch()..start();
      try {
        for (final html in [null, MarkdownHtml.none, _customHtml]) {
          Plusparse.parse(source, html: html);
          Plusparse.parse(source, useDollarSignsForLatex: true, html: html);
        }
        MarkdownDefinitions.collect(source);
      } catch (error, stack) {
        fail('seed $seed threw $error\n$stack\nsource: ${_quoted(source)}');
      }
      // Six parses of a few kilobytes. Generous: a quadratic path on a bad
      // input takes seconds, not milliseconds.
      expect(
        watch.elapsedMilliseconds,
        lessThan(1500),
        reason: 'seed $seed: ${_quoted(source)}',
      );
    }
  });

  test('every prefix of a stream is safe for the streaming helpers', () {
    for (var seed = 100000; seed < 100000 + 60 * _scale; seed++) {
      final source = _document(Random(seed), 80);
      for (var end = 0; end <= source.length; end++) {
        final prefix = source.substring(0, end);
        try {
          final safe = inlineSafeLength(prefix, holdMathDollars: seed.isEven);
          expect(safe, inInclusiveRange(0, prefix.length));
          final split = settledSplitOffset(prefix);
          expect(split, inInclusiveRange(0, prefix.length));
          splitStreamSegments(prefix);
          completeOpenMath(prefix, dollarsAreMath: seed.isEven);
          Plusparse.parse(prefix, useDollarSignsForLatex: seed.isEven);
        } catch (error, stack) {
          fail(
            'seed $seed, prefix $end threw $error\n$stack\n'
            'prefix: ${_quoted(prefix)}',
          );
        }
      }
    }
  });

  testWidgets('random replies stream through the widget without throwing', (
    tester,
  ) async {
    for (var seed = 200000; seed < 200000 + 12 * _scale; seed++) {
      final source = _document(Random(seed), 60);
      for (var end = 0; end <= source.length; end += 9) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: GptMarkdown(
                  source.substring(0, end),
                  isStreaming: true,
                  useDollarSignsForLatex: seed.isEven,
                  animation: seed.isEven
                      ? GptMarkdownAnimation.fade
                      : GptMarkdownAnimation.none,
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 16));
        final error = tester.takeException();
        expect(
          error,
          isNull,
          reason:
              'seed $seed, prefix $end: ${_quoted(source.substring(0, end))}',
        );
      }
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: GptMarkdown(source)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'seed $seed final');
    }
  });
}

String _quoted(String s) =>
    "'${s.replaceAll('\\', r'\\').replaceAll('\n', r'\n').replaceAll("'", r"\'")}'";
