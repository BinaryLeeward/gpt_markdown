/// SVG images: a `.svg` URL or `data:image/svg+xml` renders as SVG, and a
/// network image that arrives as SVG without saying so in its URL — every
/// shields.io README badge — falls back to SVG instead of the broken-image
/// mark.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/custom_widgets/custom_error_image.dart';
import 'package:gpt_markdown/custom_widgets/svg_image.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

const _svg =
    '<svg xmlns="http://www.w3.org/2000/svg" width="40" height="20">'
    '<rect width="40" height="20" fill="#44c11f"/></svg>';

/// Requests made, by URL.
final _requests = <String, int>{};

/// What the fake network serves, by URL.
final _served = <String, ({String type, List<int> body})>{
  'https://badge.test/pub/v/x': (
    type: 'image/svg+xml',
    body: utf8.encode(_svg),
  ),
  'https://badge.test/logo.svg': (
    type: 'image/svg+xml',
    body: utf8.encode(_svg),
  ),
  'https://badge.test/once.svg': (
    type: 'image/svg+xml',
    body: utf8.encode(_svg),
  ),
  'https://badge.test/garbage': (
    type: 'application/octet-stream',
    body: utf8.encode('neither a bitmap nor an SVG'),
  ),
};

Future<void> _render(WidgetTester tester, String markdown) async {
  await HttpOverrides.runZoned(() async {
    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: GptMarkdown(markdown)),
          ),
        ),
      );
      // Real time, for the download and decode.
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await tester.pump();
      }
    });
  }, createHttpClient: (_) => _FakeClient());
  await tester.pump();
}

void main() {
  group('isSvgUrl', () {
    test('a .svg path, with or without a query', () {
      expect(isSvgUrl('https://x.dev/a/logo.svg'), isTrue);
      expect(isSvgUrl('https://x.dev/logo.SVG?v=2#top'), isTrue);
      expect(isSvgUrl('data:image/svg+xml;base64,PHN2Zy8+'), isTrue);
      expect(isSvgUrl('https://x.dev/logo.png'), isFalse);
      expect(isSvgUrl('https://x.dev/svg/logo.png?type=.svg'), isFalse);
      expect(isSvgUrl('data:image/png;base64,AAAA'), isFalse);
    });
  });

  // shields.io draws badge text at font-size 110 inside scale(.1). The SVG
  // compiler under flutter_svg scales the position and not the size, so the
  // text came out ten times too large, clipped to the badge.
  group('normalizeSvgText', () {
    const badge =
        '<svg xmlns="http://www.w3.org/2000/svg" width="76" height="20">'
        '<rect width="76" height="20" fill="#555"/>'
        '<g fill="#fff" font-size="110">'
        '<g transform="scale(.1)">'
        '<g aria-hidden="true"><text x="165" y="150" textLength="210">pub</text></g>'
        '<text x="165" y="140" textLength="210">pub</text>'
        '</g></g></svg>';

    test('folds a text-only scale into the text', () {
      final out = utf8.decode(normalizeSvgText(utf8.encode(badge)));
      expect(out, isNot(contains('transform')));
      expect(out, contains('x="16.5" y="14" textLength="21" font-size="11"'));
      expect(out, contains('x="16.5" y="15" textLength="21" font-size="11"'));
      // The shapes outside it are untouched.
      expect(out, contains('<rect width="76" height="20" fill="#555"/>'));
    });

    test('leaves a scaled group holding shapes as written', () {
      const shapes =
          '<svg xmlns="http://www.w3.org/2000/svg">'
          '<g transform="scale(2)"><rect width="5" height="5"/>'
          '<text x="1" y="2" font-size="3">a</text></g></svg>';
      final bytes = utf8.encode(shapes);
      expect(normalizeSvgText(bytes), same(bytes));
    });

    test('leaves an SVG without text, or not XML, as written', () {
      final logo = utf8.encode(
        '<svg xmlns="http://www.w3.org/2000/svg"><g transform="scale(2)">'
        '<path d="M0 0h5"/></g></svg>',
      );
      expect(normalizeSvgText(logo), same(logo));
      final broken = utf8.encode('<svg><g transform="scale(2)"><text>');
      expect(normalizeSvgText(broken), same(broken));
    });

    // A badge's `logo=` icon is an SVG inside an <image>, which the compiler
    // drops: it decodes only bitmaps there.
    String withLogo(String href) =>
        '<svg xmlns="http://www.w3.org/2000/svg" width="40" height="20">'
        '<image x="5" y="3" width="14" height="14" href="$href"/></svg>';
    const logo =
        '<svg fill="white" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">'
        '<title>X</title><defs><clipPath id="c"><rect width="24" height="24"/>'
        '</clipPath></defs><path clip-path="url(#c)" d="M0 0h24v24H0z"/></svg>';

    test('inlines an embedded SVG image, placed by its viewBox', () {
      for (final href in [
        'data:image/svg+xml;base64,${base64Encode(utf8.encode(logo))}',
        'data:image/svg+xml;utf8,${Uri.encodeComponent(logo)}',
      ]) {
        final out = utf8.decode(normalizeSvgText(utf8.encode(withLogo(href))));
        expect(out, isNot(contains('<image')));
        // 24 units into 14: scale 14/24, at the image's corner.
        expect(
          out,
          contains('<g transform="translate(5 3) scale(0.5833)" fill="white">'),
        );
        expect(out, contains('d="M0 0h24v24H0z"'));
        expect(out, isNot(contains('<title>X</title>')));
        // Its ids are prefixed, and their references with them.
        final id = RegExp(r'id="([^"]+)"').firstMatch(out)![1]!;
        expect(id, endsWith('-c'));
        expect(out, contains('clip-path="url(#$id)"'));
      }
    });

    test('a non-square viewBox is centred in the image box', () {
      const wide =
          '<svg viewBox="0 0 20 10" xmlns="http://www.w3.org/2000/svg"><path d="M0 0h1"/></svg>';
      final out = utf8.decode(
        normalizeSvgText(
          utf8.encode(
            withLogo('data:image/svg+xml;utf8,${Uri.encodeComponent(wide)}'),
          ),
        ),
      );
      // 20x10 into 14x14: scale 0.7, 7 high, so 3.5 down from the top.
      expect(out, contains('translate(5 6.5) scale(0.7)'));
    });

    test('a bitmap <image> is left to the compiler', () {
      final bytes = utf8.encode(withLogo('data:image/png;base64,iVBORw0KGgo='));
      expect(normalizeSvgText(bytes), same(bytes));
    });

    test('rewrites once per byte list', () {
      final bytes = utf8.encode(badge);
      expect(normalizeSvgText(bytes), same(normalizeSvgText(bytes)));
    });
  });

  testWidgets('a data:image/svg+xml image renders as SVG', (tester) async {
    final url = 'data:image/svg+xml;base64,${base64Encode(utf8.encode(_svg))}';
    await _render(tester, '![logo]($url)');
    expect(find.byType(SvgPicture), findsOneWidget);
    expect(find.byType(CustomImageError), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a .svg URL renders as SVG', (tester) async {
    await _render(tester, '![logo](https://badge.test/logo.svg)');
    expect(find.byType(SvgPicture), findsOneWidget);
    expect(find.byType(CustomImageError), findsNothing);
  });

  testWidgets('an SVG whose URL does not say so falls back to SVG', (
    tester,
  ) async {
    await _render(
      tester,
      '<a href="https://pub.dev"><img src="https://badge.test/pub/v/x" '
      'alt="Pub Version"></a>',
    );
    expect(find.byType(SvgPicture), findsOneWidget);
    expect(find.byType(CustomImageError), findsNothing);
  });

  testWidgets('an image that is neither shows the broken-image mark', (
    tester,
  ) async {
    await _render(tester, '![x](https://badge.test/garbage)');
    expect(find.byType(CustomImageError), findsOneWidget);
  });

  testWidgets('a missing .svg shows the broken-image mark', (tester) async {
    await _render(tester, '![x](https://badge.test/missing.svg)');
    expect(find.byType(SvgPicture), findsNothing);
    expect(find.byType(CustomImageError), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('rebuilding does not download an SVG again', (tester) async {
    _requests.clear();
    const markdown = '![logo](https://badge.test/once.svg) and more';
    await _render(tester, markdown);
    await _render(tester, '$markdown text');
    await _render(tester, '$markdown text, streaming in');
    expect(find.byType(SvgPicture), findsOneWidget);
    expect(_requests['https://badge.test/once.svg'], 1);
  });

  testWidgets('a failed download is not retried as SVG', (tester) async {
    await _render(tester, '![x](https://badge.test/missing.png)');
    expect(find.byType(SvgPicture), findsNothing);
    expect(find.byType(CustomImageError), findsOneWidget);
  });
}

// ---------------------------------------------------------------------------
// A network that serves [_served], and 404 for everything else. Enough of
// `dart:io`'s client for `NetworkImage` and `package:http`.
// ---------------------------------------------------------------------------

class _FakeClient implements HttpClient {
  @override
  bool autoUncompress = true;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _FakeRequest(url);

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async =>
      _FakeRequest(url);

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeRequest implements HttpClientRequest {
  _FakeRequest(this.uri);

  @override
  final Uri uri;

  @override
  bool followRedirects = true;

  @override
  int maxRedirects = 5;

  @override
  int contentLength = -1;

  @override
  bool persistentConnection = true;

  @override
  final HttpHeaders headers = _FakeHeaders({});

  @override
  Future<void> addStream(Stream<List<int>> stream) => stream.drain<void>();

  @override
  Future<HttpClientResponse> close() async {
    _requests.update(uri.toString(), (n) => n + 1, ifAbsent: () => 1);
    final served = _served[uri.toString()];
    return served == null
        ? _FakeResponse(404, 'text/plain', const [])
        : _FakeResponse(200, served.type, served.body);
  }

  @override
  Future<HttpClientResponse> get done => close();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeResponse extends Stream<List<int>> implements HttpClientResponse {
  _FakeResponse(this.statusCode, String type, this._body)
    : headers = _FakeHeaders({
        'content-type': [type],
        'content-length': ['${_body.length}'],
      });

  final List<int> _body;

  @override
  final int statusCode;

  @override
  final HttpHeaders headers;

  @override
  int get contentLength => _body.length;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  bool get isRedirect => false;

  @override
  bool get persistentConnection => false;

  @override
  String get reasonPhrase => statusCode == 200 ? 'OK' : 'Not Found';

  @override
  List<RedirectInfo> get redirects => const [];

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream<List<int>>.fromIterable([_body]).listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHeaders implements HttpHeaders {
  _FakeHeaders(this._values);

  final Map<String, List<String>> _values;

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    _values[name.toLowerCase()] = ['$value'];
  }

  @override
  String? value(String name) => _values[name.toLowerCase()]?.first;

  @override
  List<String>? operator [](String name) => _values[name.toLowerCase()];

  @override
  void forEach(void Function(String name, List<String> values) action) =>
      _values.forEach(action);

  @override
  ContentType? get contentType {
    final type = value('content-type');
    return type == null ? null : ContentType.parse(type);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
