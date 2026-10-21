import 'package:material_ui/material_ui.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

import 'demo_theme.dart';
import 'html_tags_demo.dart';

/// Standalone gallery of every HTML tag the package understands out of the
/// box — the 68 in [MarkdownHtml.defaults], plus the table and list children
/// that only mean something inside their parent.
///
/// Each card has an editable source and its live rendering beside it; edit
/// the source and the output follows. Two switches show the same sources with
/// the app's own [demoHtmlTags], and with `html: false`.
///
/// Run it directly with:
/// ```
/// flutter run -t lib/html_gallery_demo.dart
/// ```
void main() => runApp(const HtmlGalleryApp());

/// One tag (or a family of tags sharing a rule) and a sample of it.
class HtmlTagSample {
  /// Creates a sample.
  const HtmlTagSample(this.tags, this.note, this.source);

  /// The tag names this sample covers.
  final List<String> tags;

  /// What the tag becomes.
  final String note;

  /// Markdown containing the tag.
  final String source;
}

/// A titled group of samples.
class HtmlTagGroup {
  /// Creates a group.
  const HtmlTagGroup(this.title, this.description, this.samples);

  /// Shown as the section heading.
  final String title;

  /// One line under the heading.
  final String description;

  /// The samples in this group.
  final List<HtmlTagSample> samples;
}

/// A small SVG as a `data:` URL, so the `<img>` sample needs no network.
const _svgDataUrl =
    'data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9'
    'zdmciIHdpZHRoPSIxMjAiIGhlaWdodD0iNDAiPjxyZWN0IHdpZHRoPSIxMjAiIGhlaWdodD0'
    'iNDAiIHJ4PSI4IiBmaWxsPSIjM2Y1MWI1Ii8+PHRleHQgeD0iNjAiIHk9IjI2IiBmb250LXN'
    'pemU9IjE2IiBmaWxsPSIjZmZmIiB0ZXh0LWFuY2hvcj0ibWlkZGxlIj5nYWxsZXJ5PC90ZXh'
    '0Pjwvc3ZnPg==';

/// What the editor shows in place of [_svgDataUrl], which would fill the
/// card. Rendering puts the real URL back.
const _svgPlaceholder = 'data:image/svg+xml;base64,…';

/// Every built-in tag, grouped by what it becomes.
const htmlTagGroups = <HtmlTagGroup>[
  HtmlTagGroup('Formatting', 'Inline tags that map onto Markdown styles.', [
    HtmlTagSample(['b', 'strong'], 'bold',
        'Plain, <b>b</b> and <strong>strong</strong>.'),
    HtmlTagSample(
      ['i', 'em', 'cite', 'var'],
      'italic',
      '<i>i</i>, <em>em</em>, <cite>cite</cite> and <var>var</var>.',
    ),
    HtmlTagSample(
      ['s', 'del', 'strike'],
      'strikethrough',
      '<s>s</s>, <del>del</del> and <strike>strike</strike>.',
    ),
    HtmlTagSample(['u', 'ins'], 'underline', '<u>u</u> and <ins>ins</ins>.'),
    HtmlTagSample(
      ['code', 'kbd', 'samp', 'tt'],
      'inline code — the content is not Markdown',
      '<code>**not bold**</code>, press <kbd>Ctrl</kbd>+<kbd>C</kbd>, '
          '<samp>output</samp> and <tt>tt</tt>.',
    ),
    HtmlTagSample(
        ['sup'], 'superscript', 'E = mc<sup>2</sup>, the 1<sup>st</sup>.'),
    HtmlTagSample(['sub'], 'subscript', 'H<sub>2</sub>O and CO<sub>2</sub>.'),
    HtmlTagSample(
        ['mark'], 'highlight', 'Only <mark>this part</mark> matters.'),
  ]),
  HtmlTagGroup('Links, images and breaks', 'Inline tags with attributes.', [
    HtmlTagSample(
      ['a'],
      'a link, with its title',
      'Read the <a href="https://pub.dev/packages/gpt_markdown" '
          'title="pub.dev">package page</a>.',
    ),
    HtmlTagSample(
      ['img'],
      'an image — src, alt, width and height',
      '<img src="$_svgDataUrl" alt="gallery badge" width="120" height="40">',
    ),
    HtmlTagSample(
      ['svg'],
      'a drawing — sized by width, height and viewBox; '
          'fill="currentColor" takes the text colour',
      'A star <svg width="18" height="18" viewBox="0 0 24 24">'
          '<path fill="currentColor" d="M12 2l3 7h7l-5.5 4.5L18.5 21 12 '
          '16.5 5.5 21l2-7.5L2 9h7z"/></svg> inside a line, and a block:\n\n'
          '<svg width="160" height="80" viewBox="0 0 160 80">\n'
          '  <rect x="2" y="2" width="156" height="76" rx="12" '
          'fill="#3f51b5"/>\n'
          '  <circle cx="40" cy="40" r="22" fill="#ffc107"/>\n'
          '</svg>',
    ),
    HtmlTagSample(
      ['br'],
      'a line break, in a table cell too',
      'First line<br>second line\n\n| Cell |\n|---|\n| one<br>two |',
    ),
  ]),
  HtmlTagGroup('Blocks', 'Tags on lines of their own that become blocks.', [
    HtmlTagSample(
      ['h1', 'h2', 'h3', 'h4', 'h5', 'h6'],
      'headings',
      '<h1>Heading 1</h1>\n<h2>Heading 2</h2>\n<h3>Heading 3</h3>\n'
          '<h4>Heading 4</h4>\n<h5>Heading 5</h5>\n<h6>Heading 6</h6>',
    ),
    HtmlTagSample(['hr'], 'a horizontal rule', 'Above\n\n<hr>\n\nBelow'),
    HtmlTagSample(
      ['blockquote'],
      'a quote',
      '<blockquote>\nA quote with **Markdown** inside.\n</blockquote>',
    ),
    HtmlTagSample(
      ['pre'],
      'a code block',
      '<pre>\nfinal x = 1;\nprint(x * 2);\n</pre>',
    ),
    HtmlTagSample(
      ['table', 'thead', 'tbody', 'tfoot', 'tr', 'th', 'td'],
      'a table — rows in <thead>, or of <th> cells, are the header',
      '<table>\n'
          '<thead><tr><th>Tag</th><th>Becomes</th></tr></thead>\n'
          '<tbody>\n'
          '<tr><td>&lt;b&gt;</td><td><b>bold</b></td></tr>\n'
          '<tr><td>&lt;i&gt;</td><td><i>italic</i></td></tr>\n'
          '</tbody>\n'
          '<tfoot><tr><td>Total</td><td>2</td></tr></tfoot>\n'
          '</table>',
    ),
    HtmlTagSample(
      ['table', 'caption'],
      'merged cells — colspan and rowspan',
      '<table>\n'
          '<caption>Quarterly results</caption>\n'
          '<thead>\n'
          '<tr><th rowspan="2">Region</th>'
          '<th colspan="2" align="center">2025</th>'
          '<th colspan="2" align="center">2026</th></tr>\n'
          '<tr><th>Q1</th><th>Q2</th><th>Q1</th><th>Q2</th></tr>\n'
          '</thead>\n'
          '<tr><td rowspan="2">North</td><td>10</td><td>12</td>'
          '<td>14</td><td>18</td></tr>\n'
          '<tr><td colspan="4" align="center"><i>a note across four '
          'columns</i></td></tr>\n'
          '<tr><td>South</td><td>8</td><td>9</td><td>11</td><td>13</td></tr>\n'
          '</table>',
    ),
    HtmlTagSample(
      ['table'],
      'no <th> and no <thead>: no header row',
      '<table>\n<tr><td>a</td><td>b</td></tr>\n'
          '<tr><td>c</td><td>d</td></tr>\n</table>',
    ),
    HtmlTagSample(
      ['ul', 'li'],
      'a bulleted list',
      '<ul>\n<li>First</li>\n<li>Second with <b>bold</b></li>\n</ul>',
    ),
    HtmlTagSample(
      ['ol', 'li'],
      'a numbered list',
      '<ol>\n<li>One</li>\n<li>Two</li>\n<li>Three</li>\n</ol>',
    ),
    HtmlTagSample(
      ['input'],
      'a checkbox — type="checkbox", checked',
      '<input type="checkbox" checked> Done\n\n'
          '<input type="checkbox"> Not yet',
    ),
  ]),
  HtmlTagGroup(
    'Inline wrappers',
    'The tag is dropped; its content renders as Markdown.',
    [
      HtmlTagSample(
        ['span'],
        'its content',
        'A <span style="color: red">span</span> with **bold** after.',
      ),
      HtmlTagSample(
          ['small'], 'its content', 'Fine print: <small>small</small>.'),
      HtmlTagSample(['big'], 'its content', 'Shout: <big>big</big>.'),
      HtmlTagSample(
        ['font'],
        'its content',
        '<font color="blue" size="4">font</font> tag.',
      ),
      HtmlTagSample(
        ['abbr'],
        'its content',
        'The <abbr title="World Health Organization">WHO</abbr> says so.',
      ),
      HtmlTagSample(['q'], 'its content', 'She said <q>hello</q>.'),
    ],
  ),
  HtmlTagGroup(
    'Block wrappers',
    'On lines of their own the tag is dropped, so the Markdown inside renders.',
    [
      HtmlTagSample(
        ['div'],
        'its content',
        '<div align="center">\n\n**Centred** in a README, plain here.\n\n</div>',
      ),
      HtmlTagSample(
          ['p'], 'its content', '<p>\nA paragraph with *italic*.\n</p>'),
      HtmlTagSample(
          ['center'], 'its content', '<center>\nCentre me\n</center>'),
      HtmlTagSample(
        ['section', 'article', 'header', 'footer', 'main', 'aside', 'nav'],
        'their content',
        '<article>\n<header>\n\n## Article title\n\n</header>\n<section>\n'
            'Section text.\n</section>\n<aside>\nAside text.\n</aside>\n'
            '<nav>\n[Home](https://example.com)\n</nav>\n<main>\nMain text.\n'
            '</main>\n<footer>\nFooter text.\n</footer>\n</article>',
      ),
      HtmlTagSample(
        ['figure', 'figcaption'],
        'their content',
        '<figure>\n<img src="$_svgDataUrl" alt="figure" width="120" '
            'height="40">\n<figcaption>\nA caption.\n</figcaption>\n</figure>',
      ),
      HtmlTagSample(
        ['details', 'summary'],
        'their content, open — "Custom tags" makes it collapsible',
        '<details>\n<summary>Click to expand</summary>\n\n'
            'Hidden **details**.\n\n</details>',
      ),
      HtmlTagSample(
        ['html', 'body'],
        'their content',
        '<html>\n<body>\nA whole page, pasted.\n</body>\n</html>',
      ),
    ],
  ),
  HtmlTagGroup(
    'Hidden',
    'Closed, these show nothing; the text around them stays.',
    [
      HtmlTagSample(
        ['script'],
        'hidden',
        'Before\n\n<script>alert("hi")</script>\n\nAfter',
      ),
      HtmlTagSample(
        ['style'],
        'hidden',
        'Before\n\n<style>body { color: red; }</style>\n\nAfter',
      ),
      HtmlTagSample(
        ['iframe'],
        'hidden',
        'Before\n\n<iframe src="https://example.com"></iframe>\n\nAfter',
      ),
      HtmlTagSample(
        ['object', 'embed'],
        'hidden',
        'Before\n\n<object data="movie.swf"></object>\n\n'
            '<embed src="movie.swf">\n\nAfter',
      ),
      HtmlTagSample(
        ['noscript'],
        'hidden',
        'Before\n\n<noscript>Enable JavaScript</noscript>\n\nAfter',
      ),
      HtmlTagSample(
        ['template'],
        'hidden',
        'Before\n\n<template><p>Not shown</p></template>\n\nAfter',
      ),
      HtmlTagSample(
        ['head', 'title', 'meta', 'link'],
        'hidden',
        'Before\n\n<head>\n<title>Page</title>\n<meta charset="utf-8">\n'
            '<link rel="stylesheet" href="a.css">\n</head>\n\nAfter',
      ),
    ],
  ),
  HtmlTagGroup('Not understood', 'Anything else stays text, as written.', [
    HtmlTagSample(
      ['blink'],
      'text — not on the allowlist',
      'An unknown <blink>blink</blink> tag.',
    ),
    HtmlTagSample(['b'], 'text — never closed', 'The <b> tag makes text bold.'),
  ]),
];

/// The demo app shell.
class HtmlGalleryApp extends StatelessWidget {
  /// Creates the demo app.
  const HtmlGalleryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return DemoApp(
      title: 'gpt_markdown — HTML tags',
      pageBuilder: (toggleTheme) => HtmlGalleryPage(onToggleTheme: toggleTheme),
    );
  }
}

/// Every sample as a card, with a filter and two switches.
class HtmlGalleryPage extends StatefulWidget {
  /// Creates the demo page.
  const HtmlGalleryPage({super.key, this.onToggleTheme});

  /// Flips the app between light and dark.
  final VoidCallback? onToggleTheme;

  @override
  State<HtmlGalleryPage> createState() => _HtmlGalleryPageState();
}

class _HtmlGalleryPageState extends State<HtmlGalleryPage> {
  String _query = '';
  bool _customTags = false;
  bool _html = true;

  /// Edited sources, kept while a card is filtered out of the list.
  final Map<HtmlTagSample, String> _edits = {};

  bool _matches(HtmlTagSample sample) {
    final q = _query.trim().toLowerCase().replaceAll(RegExp('[<>/]'), '');
    return q.isEmpty || sample.tags.any((t) => t.contains(q));
  }

  @override
  Widget build(BuildContext context) {
    final groups = [
      for (final group in htmlTagGroups)
        (group: group, samples: group.samples.where(_matches).toList()),
    ].where((g) => g.samples.isNotEmpty).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('HTML tags (${MarkdownHtml.defaults.names.length})'),
        actions: [
          if (widget.onToggleTheme != null)
            DemoThemeButton(onToggle: widget.onToggleTheme!),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Wrap(
              spacing: 16,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 260,
                  child: TextField(
                    decoration: const InputDecoration(
                      isDense: true,
                      prefixIcon: Icon(Icons.search_rounded),
                      hintText: 'Filter by tag, e.g. table',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
                _Toggle(
                  label: 'Custom tags',
                  value: _customTags,
                  onChanged: (v) => setState(() => _customTags = v),
                ),
                _Toggle(
                  label: 'HTML on',
                  value: _html,
                  onChanged: (v) => setState(() => _html = v),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final g in groups) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 4),
                    child: Text(
                      g.group.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      g.group.description,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  for (final sample in g.samples)
                    _SampleCard(
                      key: ObjectKey(sample),
                      sample: sample,
                      edited: _edits[sample],
                      onEdited: (text) => text == null
                          ? _edits.remove(sample)
                          : _edits[sample] = text,
                      htmlTags: _customTags ? demoHtmlTags : null,
                      html: _html,
                    ),
                ],
                if (groups.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: Text('No tag matches.')),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Switch(value: value, onChanged: onChanged),
          const SizedBox(width: 4),
          Text(label),
        ],
      );
}

class _SampleCard extends StatefulWidget {
  const _SampleCard({
    super.key,
    required this.sample,
    required this.edited,
    required this.onEdited,
    required this.htmlTags,
    required this.html,
  });

  final HtmlTagSample sample;

  /// The source as last edited, or null for the sample's own.
  final String? edited;

  /// Reports an edit, or null once the source is back to the sample's own.
  final ValueChanged<String?> onEdited;

  final Map<String, HtmlTag?>? htmlTags;
  final bool html;

  @override
  State<_SampleCard> createState() => _SampleCardState();
}

class _SampleCardState extends State<_SampleCard> {
  late final String _original = widget.sample.source.replaceAll(
    _svgDataUrl,
    _svgPlaceholder,
  );
  late final TextEditingController _controller = TextEditingController(
    text: widget.edited ?? _original,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _changed(String text) {
    widget.onEdited(text == _original ? null : text);
    setState(() {});
  }

  void _reset() {
    _controller.text = _original;
    _changed(_original);
  }

  @override
  Widget build(BuildContext context) {
    final sample = widget.sample;
    final scheme = Theme.of(context).colorScheme;
    final edited = _controller.text != _original;
    final source = TextField(
      controller: _controller,
      maxLines: null,
      minLines: 2,
      onChanged: _changed,
      style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        contentPadding: const EdgeInsets.all(12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
    );
    final rendered = GptMarkdown(
      _controller.text.replaceAll(_svgPlaceholder, _svgDataUrl),
      htmlTags: widget.htmlTags,
      html: widget.html,
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final tag in sample.tags)
                  Chip(
                    label: Text('<$tag>'),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                Text('→ ${sample.note}'),
                if (edited)
                  TextButton.icon(
                    icon: const Icon(Icons.restart_alt_rounded, size: 18),
                    label: const Text('Reset'),
                    onPressed: _reset,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth >= 700) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: source),
                      const SizedBox(width: 16),
                      Expanded(child: rendered),
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [source, const SizedBox(height: 10), rendered],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
