/// An inline directive written inside code stays the code the reader wrote.
///
/// Directives are masked out of the source before anything parses it, and
/// code is never expanded back — so `` `genui{x}` `` used to render the mask's
/// sentinel and Base64 payload instead of the text. Fences, block-quoted
/// fences and code spans are now left alone, while a backtick inside a
/// directive's own payload still does not start a code span.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

import '../utils/test_helpers.dart';

final _directives = [
  InlineDirective(
    open: 'genui{',
    close: '}',
    builder: (context, payload, style) => TextSpan(text: 'DIRECTIVE($payload)'),
  ),
];

Future<String> _render(WidgetTester tester, String markdown) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: GptMarkdown(markdown, inlineDirectives: _directives),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return getSerializedOutput(tester).replaceAll('\n', ' ');
}

/// The mask's Private Use Area sentinels, or its `index:Base64` payload.
final _leak = RegExp('[\u{E010}\u{E011}]|[0-9]:[A-Za-z0-9+/]+=');

void main() {
  testWidgets('a code span keeps its directive text', (tester) async {
    final output = await _render(tester, '`genui{x}` and genui{y}');
    expect(output, contains('TEXT("genui{x}")[highlight]'));
    expect(output, contains('DIRECTIVE(y)'));
    expect(output, isNot(matches(_leak)));
  });

  testWidgets('a fence keeps its directive text', (tester) async {
    final output = await _render(tester, '```\ngenui{x}\n```\n\ngenui{y}');
    expect(output, contains('CODE_BLOCK(lang="", "genui{x}")'));
    expect(output, contains('DIRECTIVE(y)'));
  });

  testWidgets('a fence in a quote keeps its directive text', (tester) async {
    final output = await _render(tester, '> ```\n> genui{x}\n> ```');
    expect(output, contains('CODE_BLOCK(lang="", "genui{x}")'));
    expect(output, isNot(matches(_leak)));
  });

  testWidgets('a backtick in a payload does not start code', (tester) async {
    final output = await _render(tester, 'genui{a`b} middle genui{c`d}');
    expect(output, contains('DIRECTIVE(a`b)'));
    expect(output, contains('DIRECTIVE(c`d)'));
  });

  testWidgets('a directive after unclosed backticks still masks', (
    tester,
  ) async {
    final output = await _render(tester, 'a stray ` then genui{x}');
    expect(output, contains('DIRECTIVE(x)'));
  });
}
