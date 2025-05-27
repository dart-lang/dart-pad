// Copyright (c) 2021, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dart_services/src/utils.dart';
import 'package:test/test.dart';

void main() {
  void expectNormalizeImports(String input, String output) {
    expect(normalizeImports(input), equals(output));
  }

  group('expectNormalizeImports', () {
    test('strips a temporary directory path', () {
      expectNormalizeImports(
        'List is defined in /var/folders/4p/y54w9nqj0_n6ryqwn7lxqz6800m6cw/T/DartAnalysisWrapperintLAw/main.dart',
        'List is defined in main.dart',
      );
    });

    test('replaces a SDK path with "dart:core"', () {
      expectNormalizeImports(
        'List is defined in /path/dart/dart/sdk/lib/core/list.dart',
        'List is defined in dart:core/list.dart',
      );
    });

    test('replaces a specific SDK path with "dart:core"', () {
      expectNormalizeImports(
        "The argument type 'List<int> (where List is defined in /Users/username/sdk/dart/2.10.5/lib/core/list.dart)' can't be assigned to the parameter type 'List<int> (where List is defined in /var/folders/4p/tmp/T/DartAnalysisWrapperintLAw/main.dart)'.",
        "The argument type 'List<int> (where List is defined in dart:core/list.dart)' can't be assigned to the parameter type 'List<int> (where List is defined in main.dart)'.",
      );
    });

    test('keeps a "package:" path intact', () {
      expectNormalizeImports(
        "Unused import: 'package:flutter/material.dart'.",
        "Unused import: 'package:flutter/material.dart'.",
      );
    });

    test('keeps a "dart:core" path intact', () {
      expectNormalizeImports('dart:core/foo.dart', 'dart:core/foo.dart');
    });

    test('keeps a web URL intact', () {
      expectNormalizeImports(
        'See http://dart.dev/go/non-promo-property',
        'See http://dart.dev/go/non-promo-property',
      );
    });

    test('strips a Flutter SDK path', () {
      expectNormalizeImports(
        "The argument type 'StatelessWidget (where StatelessWidget is defined in /Users/username/path/to/dart-services/project_templates/flutter_project/main.dart)' can't be assigned to the parameter type 'StatelessWidget (where StatelessWidget is defined in /Users/username/path/to/dart-services/flutter-sdk/packages/flutter/lib/src/widgets/framework.dart)'.",
        "The argument type 'StatelessWidget (where StatelessWidget is defined in main.dart)' can't be assigned to the parameter type 'StatelessWidget (where StatelessWidget is defined in package:flutter/framework.dart)'.",
      );
    });
  });

  group('normalizeAbsolutePath', () {
    test('removes ".." from the path', () {
      expect(normalizeAbsolutePath('/path/to/../file.dart'), '/path/file.dart');
      expect(normalizeAbsolutePath('/path/../to/file.dart'), '/to/file.dart');
      expect(normalizeAbsolutePath('/path/to/../../file.dart'), '/file.dart');
      expect(
        normalizeAbsolutePath('/path/../../to/file.dart'),
        '/../to/file.dart',
      );
      expect(
        normalizeAbsolutePath('/path/../to/../../file.dart'),
        '/../file.dart',
      );
      expect(
        normalizeAbsolutePath('/path/../../to/../file.dart'),
        '/../file.dart',
      );
      expect(
        normalizeAbsolutePath('/../path/../to/file.dart'),
        '/../to/file.dart',
      );
    });
  });

  group('Lines', () {
    test('empty string', () {
      final lines = Lines('');
      expect(lines.lineForOffset(0), 1);
      expect(lines.lineForOffset(1), 1);
      expect(lines.columnForOffset(0), 1);
      expect(lines.columnForOffset(1), 1);
    });

    test('lineForOffset', () {
      final lines = Lines('one\ntwo\nthree');
      expect(lines.lineForOffset(0), 1);
      expect(lines.lineForOffset(1), 1);
      expect(lines.lineForOffset(2), 1);
      expect(lines.lineForOffset(3), 1);
      expect(lines.lineForOffset(4), 2);
      expect(lines.lineForOffset(5), 2);
      expect(lines.lineForOffset(6), 2);
      expect(lines.lineForOffset(7), 2);
      expect(lines.lineForOffset(8), 3);
      expect(lines.lineForOffset(9), 3);
      expect(lines.lineForOffset(10), 3);
      expect(lines.lineForOffset(11), 3);
      expect(lines.lineForOffset(12), 3);
      expect(lines.lineForOffset(13), 3);

      expect(lines.lineForOffset(14), 3);
    });

    test('columnForOffset', () {
      final lines = Lines('one\ntwo\nthree');
      expect(lines.columnForOffset(0), 1);
      expect(lines.columnForOffset(1), 2);
      expect(lines.columnForOffset(2), 3);
      expect(lines.columnForOffset(3), 4);
    });
  });
}
