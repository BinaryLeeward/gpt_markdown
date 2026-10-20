import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

/// `htmlTags` as an app would write it: tags of its own, and a built-in one
/// restyled. Defined once, at the top level — builders compare by identity,
/// and a new map re-renders the reply.
///
/// * `<details>` + `<summary>` — a real collapsible. Built in, it renders
///   open.
/// * `<badge color="green">` — an inline chip. Built in, it is text.
/// * `<callout type="tip">` — a card around the Markdown inside it.
/// * `<kbd>` — a key cap, instead of the built-in inline code.
final demoHtmlTags = <String, HtmlTag?>{
  // Kept as an element so the `<details>` builder can find it.
  'summary': const HtmlTag.block(),
  'details': HtmlTag.block((context, element) {
    final (:found, :rest) = element.take('summary');
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: element.attributes.containsKey('open'),
        title: found == null
            ? const Text('Details')
            : element.buildBlocks(found.children),
        childrenPadding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 12),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [element.buildBlocks(rest)],
      ),
    );
  }),
  'badge': HtmlTag.inline((context, element) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (element['color']) {
      'green' => Colors.green.shade600,
      'red' => scheme.error,
      _ => scheme.primary,
    };
    return WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          border: Border.all(color: color),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text.rich(
          TextSpan(children: element.children),
          style: element.style.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
            fontSize: (element.style.fontSize ?? 14) * 0.85,
          ),
        ),
      ),
    );
  }),
  'callout': HtmlTag.block((context, element) {
    final scheme = Theme.of(context).colorScheme;
    final (icon, color) = switch (element['type']) {
      'warning' => (Icons.warning_amber_rounded, scheme.error),
      _ => (Icons.lightbulb_outline_rounded, scheme.tertiary),
    };
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        // A start-side bar only: Flutter draws no corner radius on a border
        // whose sides differ.
        border: BorderDirectional(start: BorderSide(color: color, width: 4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(child: element.child),
        ],
      ),
    );
  }),
  'kbd': HtmlTag.inline((context, element) {
    final scheme = Theme.of(context).colorScheme;
    return WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          border: Border.all(color: scheme.outline),
          borderRadius: BorderRadius.circular(4),
          // The key's depth, under it.
          boxShadow: [
            BoxShadow(color: scheme.outline, offset: const Offset(0, 1.5)),
          ],
        ),
        child: Text(
          element.source,
          style: element.style.copyWith(
            fontFamily: 'monospace',
            fontSize: (element.style.fontSize ?? 14) * 0.85,
          ),
        ),
      ),
    );
  }, true),
};
