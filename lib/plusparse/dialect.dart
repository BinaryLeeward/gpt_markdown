/// Syntax choices for chat replies and general Markdown documents.
/// Dollar math still requires `useDollarSignsForLatex`.
enum MarkdownDialect {
  /// Original chat syntax, including numeric citations and backslash math.
  chat,

  /// Numeric reference links, escaped brackets, strict single-dollar math,
  /// delimiter-only dollar blocks and GFM escaped pipes in table code spans.
  commonmark,
}
