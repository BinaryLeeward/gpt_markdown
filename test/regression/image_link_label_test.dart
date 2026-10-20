/// An image as a link's label — `[![badge](src)](url)`, the shape of nearly
/// every README badge and clickable logo — renders the image, and tapping it
/// follows the link.
///
/// It used to render the image's source text, `![badge](src)`, as the link's
/// label. That fallback dated from when a link was drawn as a widget, and an
/// image placeholder nested inside one did not paint on iOS. Links are styled
/// text now; only the deprecated `linkBuilder` still draws them as widgets,
/// and it keeps the fallback.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

import '../utils/test_helpers.dart';

/// A 1×1 PNG, so no test touches the network.
const _png =
    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAA'
    'DUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';

Future<void> _pump(WidgetTester tester, Widget markdown) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: markdown)),
    ),
  );
  await tester.pumpAndSettle();
}

String _text(WidgetTester tester) =>
    getSerializedOutput(tester).replaceAll(_png, 'PNG');

/// A sized, solid stand-in for the image, so a tap has somewhere to land: a
/// 1×1 test image lays out at zero size before it decodes.
const _badgeKey = Key('badge');
Widget _badge(BuildContext context, String url, double? w, double? h) =>
    const SizedBox(
      key: _badgeKey,
      width: 40,
      height: 20,
      // Solid, so it takes the tap itself, the way a decoded image does.
      child: ColoredBox(color: Color(0xFF00AA00)),
    );

void main() {
  testWidgets('a badge link renders its image, not its source', (tester) async {
    await _pump(tester, const GptMarkdown('[![build]($_png)](https://ci.dev)'));
    expect(find.byType(Image), findsOneWidget);
    expect(_text(tester), contains('url="https://ci.dev"'));
    expect(_text(tester), isNot(contains('![build]')));
  });

  testWidgets('tapping the image follows the link, once', (tester) async {
    final links = <(String, String)>[];
    final images = <String>[];
    await _pump(
      tester,
      GptMarkdown(
        '[![build passing]($_png)](https://ci.dev)',
        onLinkTap: (url, title) => links.add((url, title)),
        onImageTap: images.add,
        imageBuilder: _badge,
      ),
    );
    await tester.tap(find.byKey(_badgeKey));
    expect(links, [('https://ci.dev', 'build passing')]);
    expect(images, isEmpty);
  });

  testWidgets('an image and text share one link', (tester) async {
    final links = <String>[];
    await _pump(
      tester,
      GptMarkdown(
        'See [![logo]($_png) the docs](https://docs.dev) here.',
        onLinkTap: (url, title) => links.add(url),
        imageBuilder: _badge,
      ),
    );
    expect(find.byKey(_badgeKey), findsOneWidget);
    expect(
      _text(tester),
      contains('LINK(" the docs", url="https://docs.dev")'),
    );
    await tester.tap(find.byKey(_badgeKey));
    expect(links, ['https://docs.dev']);
  });

  testWidgets('an image nested in bold inside a link follows the link', (
    tester,
  ) async {
    final links = <String>[];
    await _pump(
      tester,
      GptMarkdown(
        '[**![logo]($_png)**](https://x.dev)',
        onLinkTap: (url, title) => links.add(url),
        imageBuilder: _badge,
      ),
    );
    await tester.tap(find.byKey(_badgeKey));
    expect(links, ['https://x.dev']);
  });

  testWidgets('without onLinkTap the image keeps its own tap', (tester) async {
    final images = <String>[];
    await _pump(
      tester,
      GptMarkdown(
        '[![logo]($_png)](https://x.dev)',
        onImageTap: images.add,
        imageBuilder: _badge,
      ),
    );
    await tester.tap(find.byKey(_badgeKey));
    expect(images, [_png]);
  });

  testWidgets('a reference-style badge renders too', (tester) async {
    await _pump(
      tester,
      const GptMarkdown(
        '[![build][b]][ci]\n\n[b]: $_png\n[ci]: https://ci.dev',
      ),
    );
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('the deprecated linkBuilder keeps the source text', (
    tester,
  ) async {
    await _pump(
      tester,
      GptMarkdown(
        '[![logo]($_png)](https://x.dev)',
        // ignore: deprecated_member_use
        linkBuilder: (context, label, url, style) => Text.rich(label),
      ),
    );
    expect(find.byType(Image), findsNothing);
    expect(_text(tester), contains('![logo]'));
  });

  testWidgets('a badge link streams in without errors', (tester) async {
    const reply = 'Status: [![build]($_png)](https://ci.dev) and done.';
    for (var i = 1; i <= reply.length; i += 3) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GptMarkdown(
              reply.substring(0, i),
              animation: GptMarkdownAnimation.fade,
              isStreaming: true,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 30));
    }
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: GptMarkdown(reply))),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(Image), findsOneWidget);
  });
}
