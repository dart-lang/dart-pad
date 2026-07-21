// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dartpad_preview_shared/dartpad_preview_shared.dart';
import 'package:test/test.dart';

void main() {
  group('DiagnosticSeverity', () {
    test('exposes the LSP value and presentation metadata for every severity', () {
      final expected = {
        DiagnosticSeverity.error: (1, 'Error', 'error', 'E'),
        DiagnosticSeverity.warning: (2, 'Warning', 'warning', 'W'),
        DiagnosticSeverity.info: (3, 'Info', 'info', 'I'),
        DiagnosticSeverity.hint: (4, 'Hint', 'hint', 'H'),
      };

      for (final MapEntry(key: severity, value: metadata) in expected.entries) {
        expect(DiagnosticSeverity.fromLsp(metadata.$1), severity);
        expect(severity.lspValue, metadata.$1);
        expect(severity.label, metadata.$2);
        expect(severity.cssClass, metadata.$3);
        expect(severity.icon, metadata.$4);
      }
    });

    test('defaults unknown and absent LSP values to error', () {
      for (final value in <int?>[null, 0, 99]) {
        expect(DiagnosticSeverity.fromLsp(value), DiagnosticSeverity.error);
      }
    });
  });

  group('sortedDiagnosticEntries', () {
    Diagnostic diagnostic(
      String message, {
      DiagnosticSeverity severity = DiagnosticSeverity.error,
      int line = 0,
      int character = 0,
    }) => Diagnostic(
      severity: severity,
      line: line,
      character: character,
      message: message,
    );

    test('returns an empty list when there are no diagnostics', () {
      expect(sortedDiagnosticEntries({}), isEmpty);
      expect(
        sortedDiagnosticEntries({'main.dart': [], 'util.dart': []}),
        isEmpty,
      );
    });

    test('sorts by severity, file, line, and character while preserving entries', () {
      final diagnostics = {
        'z.dart': [
          diagnostic('warning', severity: DiagnosticSeverity.warning),
          diagnostic('z-error'),
        ],
        'a.dart': [
          diagnostic('later-line', line: 2),
          diagnostic('later-character', line: 1, character: 9),
          diagnostic('first', line: 1, character: 1),
        ],
      };

      final result = sortedDiagnosticEntries(diagnostics);

      expect(
        result.map((entry) => '${entry.fileName}:${entry.diagnostic.message}'),
        [
          'a.dart:first',
          'a.dart:later-character',
          'a.dart:later-line',
          'z.dart:z-error',
          'z.dart:warning',
        ],
      );
      expect(result.first.diagnostic, same(diagnostics['a.dart']![2]));
    });
  });
}
