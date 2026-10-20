/// The CommonMark 0.31.2 specification's 652 examples, run through the
/// parser.
///
/// Every example has to pass, unless `known_failures.json` lists it with the
/// reason it does not. The list is a ratchet: an example on it that starts
/// passing fails the run too, so it is taken off the list and can never
/// silently regress again.
///
/// The parser produces a tree, not HTML, so `html_writer.dart` writes the
/// tree the way the reference renderer would, and both sides go through the
/// spec's own normalisation (ported in `normalize.dart`) before comparing.
///
/// After a change that fixes or deliberately breaks examples, regenerate the
/// list — reasons already written are kept, new entries are marked for a
/// reason to be filled in:
///
/// ```sh
/// UPDATE_COMMONMARK_BASELINE=1 flutter test test/commonmark_spec
/// ```
///
/// `spec.json` is the specification's example set (CC-BY-SA 4.0,
/// https://spec.commonmark.org/0.31.2/).
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/plusparse/plusparse.dart';

import 'html_writer.dart';
import 'normalize.dart';

const _dir = 'test/commonmark_spec';

void main() {
  final examples =
      (jsonDecode(File('$_dir/spec.json').readAsStringSync()) as List)
          .cast<Map<String, dynamic>>();
  final knownFile = File('$_dir/known_failures.json');
  final known = knownFile.existsSync()
      ? (jsonDecode(knownFile.readAsStringSync()) as Map<String, dynamic>)
            .cast<String, String>()
      : <String, String>{};
  final update = Platform.environment['UPDATE_COMMONMARK_BASELINE'] == '1';
  final failing = <String, String>{};
  var passed = 0;

  for (final example in examples) {
    final number = '${example['example']}';
    final section = example['section'] as String;
    final markdown = example['markdown'] as String;
    final expected = example['html'] as String;

    test('example $number ($section)', () {
      final actual = documentHtml(Plusparse.parse(markdown));
      final ok = normalizeHtml(actual) == normalizeHtml(expected);
      if (ok) {
        passed += 1;
      } else {
        failing[number] = known[number] ?? 'TODO: reason';
      }
      if (update) {
        return;
      }
      final reason = known[number];
      if (reason == null) {
        expect(
          normalizeHtml(actual),
          normalizeHtml(expected),
          reason: 'markdown: ${jsonEncode(markdown)}',
        );
      } else if (ok) {
        fail(
          'Example $number now passes. Take it off known_failures.json '
          '(it was listed as: $reason).',
        );
      }
    });
  }

  tearDownAll(() {
    final total = examples.length;
    // ignore: avoid_print
    print(
      'CommonMark 0.31.2: $passed/$total pass '
      '(${(100 * passed / total).toStringAsFixed(1)}%), '
      '${failing.length} known failures.',
    );
    if (update) {
      final sorted = Map.fromEntries(
        failing.entries.toList()
          ..sort((a, b) => int.parse(a.key).compareTo(int.parse(b.key))),
      );
      knownFile.writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(sorted)}\n',
      );
    }
  });
}
