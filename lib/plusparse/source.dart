import 'ast.dart';

/// Read-only line coordinates produced by the block parser.
///
/// [startLine] is inclusive and [endLine] exclusive, both zero-based in the
/// original document. Container prefixes and line endings do not change the
/// line numbers. [firstLine] is the container-relative parser input, not a
/// replacement for original source. Inline children may be empty in a scan.
///
/// A null [node] marks hidden source (comments or definitions). Container and
/// child ranges may overlap. Descendants created from synthetic HTML content
/// are omitted when their original line coordinates cannot be verified.
class MdBlockSource {
  const MdBlockSource({
    required this.node,
    required this.startLine,
    required this.endLine,
    required this.firstLine,
    this.fenced = false,
  });

  final MdNode? node;
  final int startLine;
  final int endLine;
  final String firstLine;
  final bool fenced;
}
