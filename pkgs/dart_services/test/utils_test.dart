// Copyright (c) 2021, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dart_services/src/utils.dart';
import 'package:test/test.dart';

void main() {
  void expectNormalizeFilePaths(String input, String output) {
    expect(normalizeFilePaths(input), equals(output));
  }

  test('normalizeFilePaths strips a temporary directory path', () {
    expectNormalizeFilePaths(
      'List is defined in /var/folders/4p/y54w9nqj0_n6ryqwn7lxqz6800m6cw/T/DartAnalysisWrapperintLAw/main.dart',
      'List is defined in main.dart',
    );
  });

  test('normalizeFilePaths replaces a SDK path with "dart:core"', () {
    expectNormalizeFilePaths(
      'List is defined in /path/dart/dart/sdk/lib/core/list.dart',
      'List is defined in dart:core/list.dart',
    );
  });

  test('normalizeFilePaths replaces a specific SDK path with "dart:core"', () {
    expectNormalizeFilePaths(
      "The argument type 'List<int> (where List is defined in /Users/username/sdk/dart/2.10.5/lib/core/list.dart)' can't be assigned to the parameter type 'List<int> (where List is defined in /var/folders/4p/tmp/T/DartAnalysisWrapperintLAw/main.dart)'.",
      "The argument type 'List<int> (where List is defined in dart:core/list.dart)' can't be assigned to the parameter type 'List<int> (where List is defined in main.dart)'.",
    );
  });

  test('normalizeFilePaths keeps a "package:" path intact', () {
    expectNormalizeFilePaths(
      "Unused import: 'package:flutter/material.dart'.",
      "Unused import: 'package:flutter/material.dart'.",
    );
  });

  test('normalizeFilePaths keeps a "dart:core" path intact', () {
    expectNormalizeFilePaths(
      'dart:core/foo.dart',
      'dart:core/foo.dart',
    );
  });

  test('normalizeFilePaths keeps a web URL intact', () {
    expectNormalizeFilePaths(
      'See http://dart.dev/go/non-promo-property',
      'See http://dart.dev/go/non-promo-property',
    );
  });

  test('normalizeFilePaths strips a Flutter SDK path', () {
    expectNormalizeFilePaths(
      "The argument type 'StatelessWidget (where StatelessWidget is defined in /Users/username/path/to/dart-services/project_templates/flutter_project/main.dart)' can't be assigned to the parameter type 'StatelessWidget (where StatelessWidget is defined in /Users/username/path/to/dart-services/flutter-sdk/packages/flutter/lib/src/widgets/framework.dart)'.",
      "The argument type 'StatelessWidget (where StatelessWidget is defined in main.dart)' can't be assigned to the parameter type 'StatelessWidget (where StatelessWidget is defined in package:flutter/framework.dart)'.",
    );
  });
}
