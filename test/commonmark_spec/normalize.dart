/// A port of the CommonMark spec's `test/normalize.py`, so two renderings of
/// one example compare equal when they differ only in ways HTML ignores:
/// whitespace runs, whitespace around block tags, attribute order, `<br />`
/// against `<br>`, and character references against the characters they name.
///
/// Both sides of every comparison go through this same function, so where the
/// port departs from Python's `HTMLParser` in some corner of raw HTML it
/// departs for both, and the comparison stays fair.
library;

const _blockTags = {
  'article', 'header', 'aside', 'hgroup', 'blockquote', 'hr', 'iframe', //
  'body', 'li', 'map', 'button', 'object', 'canvas', 'ol', 'caption',
  'output', 'col', 'p', 'colgroup', 'pre', 'dd', 'progress', 'div',
  'section', 'dl', 'table', 'td', 'dt', 'tbody', 'embed', 'textarea',
  'fieldset', 'tfoot', 'figcaption', 'th', 'figure', 'thead', 'footer', 'tr',
  'form', 'ul', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'video', 'script',
  'style',
};

/// The references `normalize.py` turns back into characters. Python looks
/// them up in `html.entities.name2codepoint`; the spec's expected output only
/// ever writes these.
const _named = {'amp': '&', 'lt': '<', 'gt': '>', 'quot': '"'};

final _chunk = RegExp(r'<!\[CDATA\[[\s\S]*?\]\]>|<[^>]*>|[^<]+');
final _startTag = RegExp(r'^<([a-zA-Z][^\s/>]*)([\s\S]*?)(/?)>$');
final _endTag = RegExp(r'^</([a-zA-Z][^\s>]*)\s*>$');
final _attribute = RegExp(
  r'''([^\s=/>]+)(?:\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>]+)))?''',
);
final _reference = RegExp(
  r'&(?:#([xX][0-9a-fA-F]+|[0-9]+)|([a-zA-Z][a-zA-Z0-9]*));',
);
final _whitespace = RegExp(r'\s+');

String normalizeHtml(String html) =>
    (_Normalizer()..feed(html)).output.toString();

class _Normalizer {
  final output = StringBuffer();
  String _out = '';
  String last = 'starttag';
  String lastTag = '';
  bool inPre = false;

  void feed(String html) {
    for (final m in _chunk.allMatches(html)) {
      final chunk = m[0]!;
      if (chunk.startsWith('<![CDATA')) {
        _out += chunk;
      } else if (chunk.startsWith('<!--')) {
        _out += chunk;
        last = 'comment';
      } else if (chunk.startsWith('<!')) {
        _out += chunk;
        last = 'decl';
      } else if (chunk.startsWith('<?')) {
        _out += chunk;
        last = 'pi';
      } else if (_endTag.firstMatch(chunk) case final end?) {
        _endTagHandler(end[1]!.toLowerCase());
      } else if (_startTag.firstMatch(chunk) case final start?) {
        final tag = start[1]!.toLowerCase();
        final attrs = _attributes(start[2]!);
        _startTagHandler(tag, attrs);
        if (start[3]!.isNotEmpty) {
          lastTag = tag;
          last = 'endtag';
        }
      } else {
        _text(chunk);
      }
    }
    output.write(_out);
  }

  List<(String, String?)> _attributes(String source) {
    final attrs = <(String, String?)>[];
    for (final m in _attribute.allMatches(source)) {
      final value = m[2] ?? m[3] ?? m[4];
      attrs.add((m[1]!.toLowerCase(), value == null ? null : _unescape(value)));
    }
    attrs.sort((a, b) {
      final byName = a.$1.compareTo(b.$1);
      return byName != 0 ? byName : (a.$2 ?? '').compareTo(b.$2 ?? '');
    });
    return attrs;
  }

  /// Text between tags: plain data and character references, each handled
  /// the way `HTMLParser` hands them over.
  void _text(String text) {
    var i = 0;
    for (final m in _reference.allMatches(text)) {
      if (m.start > i) {
        _data(text.substring(i, m.start));
      }
      _ref(m);
      i = m.end;
    }
    if (i < text.length) {
      _data(text.substring(i));
    }
  }

  void _data(String data) {
    final afterTag = last == 'endtag' || last == 'starttag';
    final afterBlockTag = afterTag && _blockTags.contains(lastTag);
    if (afterTag && lastTag == 'br') {
      data = data.replaceFirst(RegExp(r'^\n+'), '');
    }
    if (!inPre) {
      data = data.replaceAll(_whitespace, ' ');
    }
    if (afterBlockTag && !inPre) {
      if (last == 'starttag') {
        data = data.trimLeft();
      } else if (last == 'endtag') {
        data = data.trim();
      }
    }
    _out += data;
    last = 'data';
  }

  void _ref(RegExpMatch m) {
    String? c;
    if (m[1] case final number?) {
      final code = number.startsWith('x') || number.startsWith('X')
          ? int.tryParse(number.substring(1), radix: 16)
          : int.tryParse(number);
      if (code != null && code <= 0x10FFFF) {
        c = String.fromCharCode(code);
      }
    } else {
      c = _named[m[2]!];
    }
    _out += switch (c) {
      '<' => '&lt;',
      '>' => '&gt;',
      '&' => '&amp;',
      '"' => '&quot;',
      null => m[0]!,
      _ => c,
    };
    last = 'ref';
  }

  void _startTagHandler(String tag, List<(String, String?)> attrs) {
    if (tag == 'pre') {
      inPre = true;
    }
    if (_blockTags.contains(tag)) {
      _out = _out.trimRight();
    }
    final b = StringBuffer('<$tag');
    for (final (name, value) in attrs) {
      b.write(' $name');
      if (value != null) {
        b.write('="${_escape(value)}"');
      }
    }
    b.write('>');
    _out += b.toString();
    lastTag = tag;
    last = 'starttag';
  }

  void _endTagHandler(String tag) {
    if (tag == 'pre') {
      inPre = false;
    } else if (_blockTags.contains(tag)) {
      _out = _out.trimRight();
    }
    _out += '</$tag>';
    lastTag = tag;
    last = 'endtag';
  }
}

String _unescape(String s) => s.replaceAllMapped(_reference, (m) {
  if (m[1] case final number?) {
    final code = number.startsWith('x') || number.startsWith('X')
        ? int.tryParse(number.substring(1), radix: 16)
        : int.tryParse(number);
    return code == null || code > 0x10FFFF ? m[0]! : String.fromCharCode(code);
  }
  return _named[m[2]!] ?? m[0]!;
});

String _escape(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#x27;');
