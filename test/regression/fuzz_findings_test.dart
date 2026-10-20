/// Bugs the fuzz test (test/fuzz) found, pinned one by one.
library;

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

Widget _app(Widget child) => MaterialApp(
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  // A delimiter row on the second line, after a leading newline: the rule
  // looking for the line above it asked `lastIndexOf` for index -1.
  test('a table delimiter row after a leading newline does not throw', () {
    expect(inlineSafeLength('\n|---|:-:|\n'), greaterThanOrEqualTo(0));
    expect(inlineSafeLength('\n| a |\n'), greaterThanOrEqualTo(0));
  });

  // The fade reveal cuts text at character counts in UTF-16 units, and could
  // cut an emoji in half — which the text engine refuses to lay out, so the
  // paragraph threw mid-stream.
  testWidgets('the fade reveal never splits an emoji', (tester) async {
    const reply = 'Ship it 😀🚀 now 👍🏽 — 家族 👨‍👩‍👧 done.';
    for (var end = 0; end <= reply.length; end++) {
      // Only whole code points arrive, as from a real stream.
      if (end > 0 &&
          end < reply.length &&
          (reply.codeUnitAt(end - 1) & 0xFC00) == 0xD800) {
        continue;
      }
      await tester.pumpWidget(
        _app(
          GptMarkdown(
            reply.substring(0, end),
            isStreaming: true,
            animation: GptMarkdownAnimation.fade,
          ),
        ),
      );
      for (var frame = 0; frame < 3; frame++) {
        await tester.pump(const Duration(milliseconds: 7));
        expect(tester.takeException(), isNull, reason: 'at $end');
      }
    }
  });

  // A host that types a reply out with `substring` cuts an emoji in half.
  testWidgets('half an emoji at the end is held back, not thrown on', (
    tester,
  ) async {
    const reply = 'Ship it 😀';
    await tester.pumpWidget(
      _app(GptMarkdown(reply.substring(0, reply.length - 1))),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('Ship it'), findsOneWidget);
  });

  testWidgets('a lone surrogate inside the text becomes U+FFFD', (
    tester,
  ) async {
    final broken = 'a ${String.fromCharCode(0xD83D)} b';
    await tester.pumpWidget(_app(GptMarkdown(broken)));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('a � b'), findsOneWidget);
  });
}
