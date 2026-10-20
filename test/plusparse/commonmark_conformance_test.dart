/// The CommonMark rules the parser gained to pass the specification's
/// examples (see test/commonmark_spec), one test per rule, written the way a
/// model's reply exercises them — and next to each, the package's own
/// leniencies, which must survive.
///
/// Output is the HTML the reference renderer would write for the tree
/// (test/commonmark_spec/html_writer.dart), whitespace-normalised.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/plusparse/definitions.dart';
import 'package:gpt_markdown/plusparse/plusparse.dart';

import '../commonmark_spec/html_writer.dart';
import '../commonmark_spec/normalize.dart';

String html(String markdown, {bool dollar = false}) => normalizeHtml(
  documentHtml(Plusparse.parse(markdown, useDollarSignsForLatex: dollar)),
);

void main() {
  group('stray maths delimiters', () {
    test('an unclosed \\[ is text, not the rest of the document', () {
      expect(
        html('Escape it as \\[foo]\n\n# Next'),
        '<p>Escape it as [foo]</p><h1>Next</h1>',
      );
      expect(
        html('\\[\nnot closed\n\n# Next'),
        '<p>[ not closed</p><h1>Next</h1>',
      );
    });

    test('closed block maths is still maths', () {
      expect(
        html('\\[\nx^2\n\\]\n\nafter'),
        '<math display="block">x^2</math><p>after</p>',
      );
    });

    test('escaped brackets around punctuation are not maths', () {
      expect(html(r'\(\) and \[\\\]'), r'<p>() and [\]</p>');
      expect(html(r'\( x \)'), '<p><math>x</math></p>');
    });
  });

  group('lists', () {
    test('a number other than 1 cannot interrupt a paragraph', () {
      expect(
        html(
          'The number of windows in my house is\n14. The number of doors is 6.',
        ),
        '<p>The number of windows in my house is 14. The number of doors is 6.</p>',
      );
      expect(
        html('Steps:\n1. one\n2. two'),
        '<p>Steps:</p><ol><li>one</li><li>two</li></ol>',
      );
    });

    test('changing the bullet or the delimiter starts a new list', () {
      expect(
        html('- a\n- b\n+ c'),
        '<ul><li>a</li><li>b</li></ul><ul><li>c</li></ul>',
      );
      expect(
        html('1. a\n2) b'),
        '<ol><li>a</li></ol><ol start="2"><li>b</li></ol>',
      );
    });

    test('a thematic break between bullets is a rule', () {
      expect(
        html('* Foo\n* * *\n* Bar'),
        '<ul><li>Foo</li></ul><hr><ul><li>Bar</li></ul>',
      );
      expect(html('- Foo\n- * * *'), '<ul><li>Foo</li><li><hr></li></ul>');
    });

    test('an item can hold any block on its first line', () {
      expect(
        html('- # Title\n- > quoted'),
        '<ul><li><h1>Title</h1></li><li><blockquote><p>quoted</p></blockquote></li></ul>',
      );
      expect(
        html('1. ```\n   code\n   ```\n2. next'),
        '<ol><li><pre><code>code\n</code></pre></li><li>next</li></ol>',
      );
      expect(html('- - nested'), '<ul><li><ul><li>nested</li></ul></li></ul>');
    });

    test('extra spaces after the marker are not part of the text', () {
      expect(html('1.  two spaces'), '<ol><li>two spaces</li></ol>');
    });

    test('empty items', () {
      expect(html('- a\n-\n- c'), '<ul><li>a</li><li></li><li>c</li></ul>');
      expect(html('-\n  foo'), '<ul><li>foo</li></ul>');
    });

    test('a line straight after an item continues it lazily', () {
      expect(html('- a\nb'), '<ul><li>a b</li></ul>');
    });

    test('siblings indented one to three spaces stay siblings', () {
      expect(
        html('- a\n - b\n  - c\n   - d'),
        '<ul><li>a</li><li>b</li><li>c</li><li>d</li></ul>',
      );
    });

    test('a numbered list restarting at 1 two spaces in nests (leniency)', () {
      expect(
        html('1. first\n  1. nested first\n  2. nested second\n2. second'),
        '<ol><li>first<ol><li>nested first</li><li>nested second</li></ol></li>'
        '<li>second</li></ol>',
      );
      // `  2.` alone is a sibling, as CommonMark has it.
      expect(
        html('1. a\n\n  2. b'),
        '<ol><li><p>a</p></li><li><p>b</p></li></ol>',
      );
    });

    test('a bullet two spaces under a numbered item nests (leniency)', () {
      expect(
        html('1. Step\n  - detail\n2. Next'),
        '<ol><li>Step<ul><li>detail</li></ul></li><li>Next</li></ol>',
      );
    });

    test('tight and loose lists are told apart', () {
      final tight = Plusparse.parse('- a\n- b').children.single;
      final loose = Plusparse.parse('- a\n\n- b').children.single;
      final looseInside = Plusparse.parse('- a\n\n  more\n- b').children.single;
      expect((tight as MdUnorderedList).loose, isFalse);
      expect((loose as MdUnorderedList).loose, isTrue);
      expect((looseInside as MdUnorderedList).loose, isTrue);
      final nestedLoose = Plusparse.parse('1. a\n   - b\n\n     c\n2. d');
      final outer = nestedLoose.children.single as MdOrderedList;
      expect(outer.loose, isFalse);
    });

    // A list may start indented four (leniently, as there are no indented
    // code blocks); its siblings, as far in, are items, not lazy text.
    test('a list indented four keeps its siblings', () {
      expect(
        html('Intro\n\n    * one\n    * two'),
        '<p>Intro</p><ul><li>one</li><li>two</li></ul>',
      );
    });

    test('an item ends at a blank line followed by unindented text', () {
      expect(html('- one\n\n two'), '<ul><li>one</li></ul><p>two</p>');
    });

    test('a list item number is limited to nine digits', () {
      expect(html('1234567890. not a list'), '<p>1234567890. not a list</p>');
    });
  });

  group('block quotes', () {
    test('a lazy line continues the quote only as paragraph text', () {
      expect(html('> foo\nbar'), '<blockquote><p>foo bar</p></blockquote>');
      expect(
        html('> - foo\n- bar'),
        '<blockquote><ul><li>foo</li></ul></blockquote><ul><li>bar</li></ul>',
      );
      expect(
        html('> ```\nfoo\n```'),
        '<blockquote><pre><code></code></pre></blockquote><p>foo</p><pre><code></code></pre>',
      );
    });

    test('a lazy === does not underline the quote into a heading', () {
      expect(
        html('> foo\nbar\n==='),
        '<blockquote><p>foo bar ===</p></blockquote>',
      );
    });

    test('--- after a quote is a rule', () {
      expect(html('> foo\n---'), '<blockquote><p>foo</p></blockquote><hr>');
    });

    test('a > line ends a quote, a blank > line does not', () {
      expect(
        html('> bar\n>\nbaz'),
        '<blockquote><p>bar</p></blockquote><p>baz</p>',
      );
    });
  });

  group('fences and headings', () {
    test("a fence's indentation is removed from its body", () {
      expect(
        html('  ```\n  aaa\naaa\n    aaa\n  ```'),
        '<pre><code>aaa\naaa\n  aaa\n</code></pre>',
      );
    });

    test('the info string decodes escapes and entities', () {
      expect(
        html('``` foo\\+bar\nx\n```'),
        '<pre><code class="language-foo+bar">x\n</code></pre>',
      );
      expect(
        html('``` f&ouml;\nx\n```'),
        '<pre><code class="language-fö">x\n</code></pre>',
      );
    });

    test('an unclosed fence does not gain a trailing empty line', () {
      expect(html('```\naaa\n'), '<pre><code>aaa\n</code></pre>');
    });

    test('a line indented four or more continues a paragraph', () {
      expect(html('Foo\n    # bar'), '<p>Foo # bar</p>');
      expect(html('Foo\n    ---'), '<p>Foo ---</p>');
    });

    test('# alone is an empty heading', () {
      expect(html('#\n## '), '<h1></h1><h2></h2>');
    });
  });

  group('link reference definitions', () {
    test('a definition may span lines', () {
      expect(
        html("[foo]:\n/url\n'title'\n\n[foo]"),
        '<p><a href="/url" title="title">foo</a></p>',
      );
      expect(html('[\nfoo\n]: /url\nbar'), '<p>bar</p>');
    });

    test('a title that does not end its line is not part of it', () {
      expect(
        html('[foo]: /url\n"title" ok\n\n[foo]'),
        '<p>&quot;title&quot; ok</p><p><a href="/url">foo</a></p>',
      );
    });

    test('definitions inside quotes and list items count', () {
      expect(
        html('[foo]\n\n> [foo]: /url'),
        '<p><a href="/url">foo</a></p><blockquote></blockquote>',
      );
      expect(
        html('- [a]: /a\n\n[a]'),
        '<ul><li></li></ul><p><a href="/a">a</a></p>',
      );
    });

    test('labels match with Unicode case folding', () {
      expect(html('[ẞ]\n\n[SS]: /url'), '<p><a href="/url">ẞ</a></p>');
    });

    // Public since 1.3.3 (importable from plusparse/definitions.dart): the
    // one-line form keeps its signature beside the multi-line one.
    test('linkDefinitionAt keeps its 1.3.3 signature', () {
      final ({String label, MdLinkDefinition definition})? one =
          linkDefinitionAt('[a]: /u "t"');
      expect(one!.label, 'a');
      expect(one.definition, const MdLinkDefinition(url: '/u', title: 't'));
      expect(linkDefinitionAt('[a]:'), isNull);
      expect(linkDefinitionIn(['[a]:', '/u'], 0)!.next, 2);
    });

    test('a definition cannot interrupt a paragraph', () {
      expect(
        html('Foo\n[bar]: /baz\n\n[bar]'),
        '<p>Foo [bar]: /baz</p><p>[bar]</p>',
      );
    });
  });

  group('links and images', () {
    test('links do not nest; the inner one wins', () {
      expect(
        html('[foo [bar](/uri)](/uri)'),
        '<p>[foo <a href="/uri">bar</a>](/uri)</p>',
      );
    });

    test('code spans and autolinks bind tighter than brackets', () {
      expect(html('[foo`](/uri)`'), '<p>[foo<code>](/uri)</code></p>');
    });

    test('emphasis does not cross a link boundary', () {
      expect(html('*[foo*](/uri)'), '<p>*<a href="/uri">foo*</a></p>');
    });

    test('an image alt text is plain text', () {
      expect(
        html('![foo *bar* `baz`](/url)'),
        '<p><img alt="foo bar baz" src="/url"></p>',
      );
    });

    test('an image inside a link stays an image', () {
      expect(
        html('[![alt](img.png)](https://x.com)'),
        '<p><a href="https://x.com"><img alt="alt" src="img.png"></a></p>',
      );
    });

    test('<destination> may hold spaces and parentheses', () {
      expect(html('[a](<b)c>)'), '<p><a href="b)c">a</a></p>');
      expect(
        html('[a](<my file.pdf>)'),
        '<p><a href="my%20file.pdf">a</a></p>',
      );
    });

    test('a destination with spaces is still a link (leniency)', () {
      expect(
        html('[doc](My File.pdf)'),
        '<p><a href="My%20File.pdf">doc</a></p>',
      );
    });

    test('but a defined reference wins over the leniency', () {
      expect(
        html('[foo](not a link)\n\n[foo]: /url1'),
        '<p><a href="/url1">foo</a>(not a link)</p>',
      );
    });

    test('an escaped bracket inside link text is literal', () {
      expect(
        html('[link \\[bar](/uri)'),
        '<p><a href="/uri">link [bar</a></p>',
      );
    });

    test('citations and footnotes keep their brackets', () {
      expect(html('See [1][2].'), '<p>See <cite>1</cite><cite>2</cite>.</p>');
      expect(
        html('Text[^n].\n\n[^n]: note'),
        '<p>Text<sup>n</sup>.</p><section class="footnotes"></section>',
      );
    });
  });

  group('autolinks', () {
    test('<scheme:…> and <email> are links', () {
      expect(
        html('<https://example.com/a?b=1>'),
        '<p><a href="https://example.com/a?b=1">https://example.com/a?b=1</a></p>',
      );
      expect(
        html('<me@example.com>'),
        '<p><a href="mailto:me@example.com">me@example.com</a></p>',
      );
    });

    test('backslash escapes do not work inside one', () {
      expect(
        html('<https://example.com?find=\\*>'),
        '<p><a href="https://example.com?find=%5C*">https://example.com?find=\\*</a></p>',
      );
    });

    test('a < that is not an autolink stays text', () {
      expect(
        html('a < b and <not a link>'),
        '<p>a &lt; b and &lt;not a link&gt;</p>',
      );
    });
  });

  group('emphasis', () {
    test('same-delimiter nesting', () {
      expect(html('*foo **bar***'), '<p><em>foo <strong>bar</strong></em></p>');
      expect(html('_foo _bar_ baz_'), '<p><em>foo <em>bar</em> baz</em></p>');
      expect(html('***foo** bar*'), '<p><em><strong>foo</strong> bar</em></p>');
      expect(
        html('**foo*bar*baz**'),
        '<p><strong>foo<em>bar</em>baz</strong></p>',
      );
    });

    test('the rule of three', () {
      expect(
        html('*foo**bar**baz*'),
        '<p><em>foo<strong>bar</strong>baz</em></p>',
      );
      expect(html('*foo**bar*'), '<p><em>foo**bar</em></p>');
    });

    test('a single * follows CommonMark exactly', () {
      expect(html('a*"foo"*'), '<p>a*&quot;foo&quot;*</p>');
      expect(html('2 * 3 * 4'), '<p>2 * 3 * 4</p>');
    });

    test('** before and after punctuation is bold (leniency)', () {
      expect(html('**Note:**text'), '<p><strong>Note:</strong>text</p>');
      expect(html('**粗体：**中文'), '<p><strong>粗体：</strong>中文</p>');
    });

    test('~~ strikethrough nests with emphasis', () {
      expect(html('~~a **b** c~~'), '<p><del>a <strong>b</strong> c</del></p>');
      expect(html('**a ~~b~~**'), '<p><strong>a <del>b</del></strong></p>');
    });
  });

  group('line breaks', () {
    test('two trailing spaces or a backslash make a hard break', () {
      final doc = Plusparse.parse('one  \ntwo\\\nthree');
      final children = (doc.children.single as MdParagraph).children;
      expect(children.whereType<MdLineBreak>(), hasLength(2));
      expect(children.whereType<MdText>().map((t) => t.text), [
        'one',
        'two',
        'three',
      ]);
    });

    test('a plain newline stays in the text', () {
      final doc = Plusparse.parse('one\ntwo');
      expect(
        ((doc.children.single as MdParagraph).children.single as MdText).text,
        'one\ntwo',
      );
    });
  });

  group('entities', () {
    test('every HTML5 named reference decodes', () {
      expect(
        html('&Dcaron; &HilbertSpace; &ClockwiseContourIntegral; &ngE;'),
        '<p>Ď ℋ ∲ ≧̸</p>',
      );
      expect(html('&notanentity;'), '<p>&amp;notanentity;</p>');
    });
  });

  group('HTML allowlist', () {
    test('inline formatting tags become formatting', () {
      expect(
        html(
          '<b>b</b> <strong>s</strong> <i>i</i> <em>e</em> <u>u</u> <s>x</s> <del>d</del>',
        ),
        '<p><strong>b</strong> <strong>s</strong> <em>i</em> <em>e</em> <u>u</u> <del>x</del> <del>d</del></p>',
      );
    });

    test('<code> and <kbd> are code; their content is not Markdown', () {
      expect(
        html('<code>a *b* &lt; c</code> and <kbd>Ctrl</kbd>'),
        '<p><code>a *b* &lt; c</code> and <code>Ctrl</code></p>',
      );
    });

    test('</br> is a line break too, and </img> nothing, as in browsers', () {
      expect(html('a<br></br>b'), '<p>a<br><br>b</p>');
      expect(
        html('a<img src="x.png"></img>b'),
        '<p>a<img alt="" src="x.png">b</p>',
      );
      // Not a known tag: text.
      expect(html('a</wbr>b'), '<p>a&lt;/wbr&gt;b</p>');
    });

    test('<br> is a line break, in a table cell too', () {
      expect(html('a<br>b<br/>c<BR />d'), '<p>a<br>b<br>c<br>d</p>');
      final table =
          Plusparse.parse('| a |\n|---|\n| x<br>y |').children.single
              as MdTable;
      expect(
        table.rows.single.cells.single.content.whereType<MdLineBreak>(),
        hasLength(1),
      );
    });

    test('<a href> is a link, <img src> an image', () {
      expect(
        html('<a href="https://x.com" title="T">the <em>site</em></a>'),
        '<p><a href="https://x.com" title="T">the <em>site</em></a></p>',
      );
      final image =
          (Plusparse.parse(
                        '<img src="a.png" alt="A" width="40" height="20">',
                      ).children.single
                      as MdParagraph)
                  .children
                  .single
              as MdImage;
      expect(image.url, 'a.png');
      expect(image.alt, 'A');
      expect(image.width, 40);
      expect(image.height, 20);
    });

    test('<span> and friends show their content', () {
      expect(
        html('a <span style="color:red">red</span> word'),
        '<p>a red word</p>',
      );
    });

    test('a tag outside the allowlist, or unclosed, stays text', () {
      expect(html('<blink>2</blink>'), '<p>&lt;blink&gt;2&lt;/blink&gt;</p>');
      expect(html('the <b> tag'), '<p>the &lt;b&gt; tag</p>');
      expect(html('use a <div> here'), '<p>use a &lt;div&gt; here</p>');
    });

    test('a closed <script> or <style> is hidden, an unclosed one is not', () {
      expect(html('a <script>x()</script> b'), '<p>a b</p>');
      expect(html('<style>\nbody {}\n</style>\n\n# T'), '<h1>T</h1>');
      expect(html('<style> is a tag'), '<p>&lt;style&gt; is a tag</p>');
    });

    test('wrapper tags on lines of their own are dropped', () {
      expect(
        html('<div align="center">\n\n**Title**\n\n</div>'),
        '<p><strong>Title</strong></p>',
      );
      expect(
        html('<details>\n<summary>More</summary>\n\nBody\n\n</details>'),
        '<p>More</p><p>Body</p>',
      );
      expect(
        html('<p align="center"><img src="a.png"></p>'),
        '<p><img alt="" src="a.png"></p>',
      );
    });

    test('<hr> on its own line is a rule', () {
      expect(html('<hr>\ntext'), '<hr><p>text</p>');
    });

    test('HTML inside a code span stays code', () {
      expect(html('`<b>x</b>`'), '<p><code>&lt;b&gt;x&lt;/b&gt;</code></p>');
    });
  });
}
