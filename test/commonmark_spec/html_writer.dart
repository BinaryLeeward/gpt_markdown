/// Writes a plusparse tree as the HTML the CommonMark reference renderer
/// produces, so the spec's expected output can be compared against it.
///
/// Only the spec's own constructs need to read exactly. The package's
/// extensions — maths, tables, citations, footnotes, task items — print as
/// tags the spec never expects, so an example that wrongly produces one
/// fails instead of passing by accident.
library;

import 'dart:convert';

import 'package:gpt_markdown/plusparse/plusparse.dart';

String documentHtml(MdDocument doc) {
  final html = _blocks(doc.children, tight: false);
  return html.isEmpty ? '' : '$html\n';
}

String _escape(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

final _hexPair = RegExp(r'^[0-9A-Fa-f]{2}$');

/// commonmark.js's URL encoding: reserved and unreserved characters and
/// existing `%XX` escapes are kept, everything else is percent-encoded.
String _url(String url) {
  final out = StringBuffer();
  final bytes = utf8.encode(url);
  const safe = r";/?:@&=+$,-_.!~*'()#";
  for (var i = 0; i < bytes.length; i++) {
    final b = bytes[i];
    final c = String.fromCharCode(b);
    final alnum =
        (b >= 0x30 && b <= 0x39) ||
        (b >= 0x41 && b <= 0x5A) ||
        (b >= 0x61 && b <= 0x7A);
    if (b == 0x25 &&
        i + 2 < bytes.length &&
        _hexPair.hasMatch(String.fromCharCodes(bytes.sublist(i + 1, i + 3)))) {
      out.write('%');
      continue;
    }
    if (b < 0x80 && (alnum || safe.contains(c))) {
      out.write(c);
    } else {
      out.write('%${b.toRadixString(16).toUpperCase().padLeft(2, '0')}');
    }
  }
  return _escape(out.toString());
}

String _inlines(List<MdNode> nodes) => nodes.map(_inline).join();

String _inline(MdNode n) => switch (n) {
  MdText(:final text) => _escape(text),
  MdBold(:final children) => '<strong>${_inlines(children)}</strong>',
  MdItalic(:final children) => '<em>${_inlines(children)}</em>',
  MdStrike(:final children) => '<del>${_inlines(children)}</del>',
  MdUnderline(:final children) => '<u>${_inlines(children)}</u>',
  MdSuperscript(:final children) => '<sup>${_inlines(children)}</sup>',
  MdSubscript(:final children) => '<sub>${_inlines(children)}</sub>',
  MdHighlight(:final children) => '<mark>${_inlines(children)}</mark>',
  MdInlineCode(:final text) => '<code>${_escape(text)}</code>',
  MdInlineLatex(:final tex) => '<math>${_escape(tex)}</math>',
  MdLink(:final children, :final url, :final title) =>
    '<a href="${_url(url)}"'
        '${title == null ? '' : ' title="${_escape(title)}"'}>'
        '${_inlines(children)}</a>',
  MdImage(:final url, :final alt, :final title) =>
    '<img src="${_url(url)}" alt="${_escape(alt)}"'
        '${title == null ? '' : ' title="${_escape(title)}"'} />',
  MdSourceTag(:final id) => '<cite>$id</cite>',
  MdFootnoteReference(:final label) => '<sup>$label</sup>',
  MdLineBreak() => '<br />\n',
  MdCustomBlock(:final HtmlElementData data) when !data.block => _inlines(
    data.children,
  ),
  _ => _block(n, tight: false),
};

bool _isBlock(MdNode n) => switch (n) {
  MdText() ||
  MdBold() ||
  MdItalic() ||
  MdStrike() ||
  MdUnderline() ||
  MdSuperscript() ||
  MdSubscript() ||
  MdHighlight() ||
  MdInlineCode() ||
  MdInlineLatex() ||
  MdLink() ||
  MdImage() ||
  MdSourceTag() ||
  MdFootnoteReference() ||
  MdLineBreak() => false,
  MdCustomBlock(:final HtmlElementData data) => data.block,
  _ => true,
};

String _blocks(List<MdNode> nodes, {required bool tight}) =>
    nodes.map((n) => _block(n, tight: tight)).join('\n');

String _item(MdListItem item, {required bool tight}) {
  // An item's first line is parsed inline; what is nested under it, as
  // blocks.
  final inlines = <MdNode>[];
  var k = 0;
  while (k < item.children.length && !_isBlock(item.children[k])) {
    inlines.add(item.children[k]);
    k += 1;
  }
  final blocks = item.children.sublist(k);
  final parts = <String>[
    if (inlines.isNotEmpty)
      tight ? _inlines(inlines) : '<p>${_inlines(inlines)}</p>',
    for (final b in blocks) _block(b, tight: tight),
  ];
  if (parts.isEmpty) {
    return '<li></li>';
  }
  if (blocks.isEmpty && tight) {
    return '<li>${parts.single}</li>';
  }
  return '<li>${tight && inlines.isNotEmpty ? '' : '\n'}'
      '${parts.join('\n')}\n</li>';
}

String _block(MdNode n, {required bool tight}) => switch (n) {
  MdParagraph(:final children) =>
    tight ? _inlines(children) : '<p>${_inlines(children)}</p>',
  MdHeading(:final level, :final children) =>
    '<h$level>${_inlines(children)}</h$level>',
  MdCodeBlock(:final language, :final code) => () {
    final lang = language.trim().split(RegExp(r'\s+')).first;
    final body = code.isEmpty ? '' : '${_escape(code)}\n';
    final attr = lang.isEmpty ? '' : ' class="language-${_escape(lang)}"';
    return '<pre><code$attr>$body</code></pre>';
  }(),
  MdBlockQuote(:final children) =>
    '<blockquote>\n${_blocks(children, tight: false)}\n</blockquote>',
  MdUnorderedList(:final items, :final loose) =>
    '<ul>\n${items.map((i) => _item(i, tight: !loose)).join('\n')}\n</ul>',
  MdOrderedList(:final start, :final items, :final loose) =>
    '<ol${start == 1 ? '' : ' start="$start"'}>\n'
        '${items.map((i) => _item(i, tight: !loose)).join('\n')}\n</ol>',
  MdHorizontalRule() => '<hr />',
  MdBlockLatex(:final tex) => '<math display="block">${_escape(tex)}</math>',
  MdCheckbox(:final checked, :final children) =>
    '<input checked="$checked">${_inlines(children)}',
  MdRadio(:final selected, :final children) =>
    '<input radio="$selected">${_inlines(children)}',
  MdTable() => '<table></table>',
  MdFootnoteDefinitions() => '<section class="footnotes"></section>',
  MdCustomBlock(:final HtmlElementData data) => _blocks(
    data.children,
    tight: tight,
  ),
  MdCustomBlock(:final type) => '<custom type="$type"></custom>',
  _ => _inline(n),
};
