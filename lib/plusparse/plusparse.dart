/// plusparse — a fast, hand-written Markdown + LaTeX parser, fully rewritten
/// in pure Dart and built into gpt_markdown (originally a Rust
/// flutter_rust_bridge plugin).
///
/// Single-pass, regex-free, and error-tolerant: it never throws on malformed
/// or partial (streaming) input, which makes it suitable for re-parsing
/// streaming LLM output on every token. No initialisation or native library
/// loading is needed — parsing is synchronous pure Dart.
///
/// Usage:
/// ```dart
/// final MdDocument doc = Plusparse.parse('# Hello **world**');
/// ```
library;

import 'ast.dart';
import 'block_parser.dart';
import 'block_syntax.dart';
import 'definitions.dart';
import 'dialect.dart';
import 'html_tags.dart';
import 'source.dart';
export 'block_syntax.dart';

export 'ast.dart';
export 'dialect.dart';
export 'source.dart';
export 'definitions.dart' show MarkdownDefinitions, MdLinkDefinition;
export 'html_tags.dart'
    show
        HtmlTagKind,
        HtmlTagSyntax,
        MarkdownHtml,
        HtmlElementData,
        htmlElementType;
export 'stream_splitter.dart';

/// Public entry point for the plusparse Markdown parser.
class Plusparse {
  Plusparse._();

  /// Reads block ranges using the same grammar as [parse], without building
  /// inline formatting. Results are metadata, never source rewrite ranges.
  /// Custom syntax controls its own work; a caller needing a cheap scan should
  /// register boundary-only variants for expensive custom blocks.
  static List<MdBlockSource> scanBlocks(
    String markdown, {
    bool useDollarSignsForLatex = false,
    MarkdownBlockRegistry? blockRegistry,
    MarkdownDefinitions? definitions,
    MarkdownHtml? html,
    MarkdownDialect dialect = MarkdownDialect.chat,
  }) => scanSourceBlocks(
    markdown,
    useDollarSignsForLatex,
    blockRegistry,
    definitions,
    html,
    dialect,
  );

  /// Parses [markdown] into a structured [MdDocument] tree.
  ///
  /// Synchronous and fast — suitable for re-parsing streaming LLM output.
  /// Set [useDollarSignsForLatex] to also treat `$ … $` / `$$ … $$` as LaTeX
  /// in addition to the chat dialect’s `\( … \)` / `\[ … \]` forms (mirrors
  /// gpt_markdown's option).
  ///
  /// Link reference and footnote definitions are collected from [markdown]
  /// itself. When parsing a document in pieces, collect them once from the
  /// whole of it with [MarkdownDefinitions.collect] and pass them as
  /// [definitions], so a reference in one piece finds a definition in another.
  ///
  /// [dialect] defaults to the original chat syntax.
  /// [MarkdownDialect.commonmark] uses numeric reference links and escaped
  /// brackets, stricter single-dollar math and GFM table code escapes.
  ///
  /// [html] decides which HTML tags are understood and what each becomes;
  /// [MarkdownHtml.defaults] when null, and [MarkdownHtml.none] for no HTML
  /// at all.
  static MdDocument parse(
    String markdown, {
    bool useDollarSignsForLatex = false,
    MarkdownBlockRegistry? blockRegistry,
    MarkdownDefinitions? definitions,
    MarkdownHtml? html,
    MarkdownDialect dialect = MarkdownDialect.chat,
  }) {
    return parseDocument(
      markdown,
      useDollarSignsForLatex,
      blockRegistry,
      definitions,
      html,
      dialect,
    );
  }
}
