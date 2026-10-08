// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dart_services/src/analyzer.dart';
import 'package:test/test.dart';

void main() {
  group('analyzer', () {
    group('getAllImportsFor', () {
      test('empty', () {
        expect(getAllImportsFor(''), isEmpty);
        expect(getAllImportsFor('   \n '), isEmpty);
      });

      test('bad source', () {
        final imports = getAllImportsFor('foo bar;\n baz\nimport mybad;\n');
        expect(imports, hasLength(1));
        expect(imports.single.uri.stringValue, equals(''));
      });

      test('one', () {
        const source = '''
library woot;
import 'dart:math';
import 'package:foo/foo.dart';
void main() { }
''';
        expect(
          getAllImportsFor(source).map((import) => import.uri.stringValue),
          unorderedEquals(['dart:math', 'package:foo/foo.dart']),
        );
      });

      test('two', () {
        const source = '''
library woot;
import 'dart:math';
 import 'package:foo/foo.dart';
import 'package:bar/bar.dart';
void main() { }
''';
        expect(
          getAllImportsFor(source).map((import) => import.uri.stringValue),
          unorderedEquals([
            'dart:math',
            'package:foo/foo.dart',
            'package:bar/bar.dart',
          ]),
        );
      });

      test('three', () {
        const source = '''
library woot;
import 'dart:math';
import 'package:foo/foo.dart';
import 'package:bar/bar.dart';import 'package:baz/baz.dart';
import 'mybazfile.dart';
void main() { }
''';
        expect(
          getAllImportsFor(source).map((import) => import.uri.stringValue),
          unorderedEquals([
            'dart:math',
            'package:foo/foo.dart',
            'package:bar/bar.dart',
            'package:baz/baz.dart',
            'mybazfile.dart',
          ]),
        );
      });
    });

    group('ImportDirectiveExtension', () {
      ImportDirective parseImport(String source) =>
          getAllImportsFor(source).single;

      test('validates dart: imports', () {
        expect(parseImport("import 'dart:core';").dartImport, isTrue);
        expect(parseImport("import 'dart:io';").dartImport, isTrue);
        expect(parseImport("import 'dart:ui';").dartImport, isTrue);
        expect(parseImport("import 'dart:core';").packageName, 'core');

        expect(parseImport("import 'dart:';").dartImport, isFalse);
        expect(parseImport("import 'dart:.';").dartImport, isFalse);
        expect(parseImport("import 'dart:..';").dartImport, isFalse);
        expect(parseImport("import 'dart:core/foo.dart';").dartImport, isFalse);
        expect(
          parseImport("import 'dart:core/../foo.dart';").dartImport,
          isFalse,
        );
        expect(parseImport("import 'dart:core?foo=bar';").dartImport, isFalse);
        expect(parseImport("import 'dart:core#frag';").dartImport, isFalse);
        expect(parseImport(r"import 'dart:core\foo';").dartImport, isFalse);
        expect(parseImport("import 'dart:core%2ffoo';").dartImport, isFalse);
        expect(
          parseImport(
            "import 'dart:core' if (dart.library.js_interop) 'foo.dart';",
          ).dartImport,
          isFalse,
        );
      });

      test('validates package: imports', () {
        expect(
          parseImport("import 'package:flutter/material.dart';").packageImport,
          isTrue,
        );
        expect(
          parseImport("import 'package:flutter/material.dart';").packageName,
          'flutter',
        );
        expect(
          parseImport("import 'package:foo/bar/baz.dart';").packageImport,
          isTrue,
        );

        expect(parseImport("import 'package:';").packageImport, isFalse);
        expect(
          parseImport("import 'package:flutter/';").packageImport,
          isFalse,
        );
        expect(
          parseImport("import 'package:/flutter/material.dart';").packageImport,
          isFalse,
        );
        expect(
          parseImport("import 'package:flutter//foo.dart';").packageImport,
          isFalse,
        );
        expect(
          parseImport("import 'package:flutter/./material.dart';")
              .packageImport,
          isFalse,
        );
        expect(
          parseImport("import 'package:flutter/../foo.dart';").packageImport,
          isFalse,
        );
        expect(
          parseImport("import 'package:flutter/%2e%2e/foo.dart';")
              .packageImport,
          isFalse,
        );
        expect(
          parseImport(r"import 'package:flutter\material.dart';").packageImport,
          isFalse,
        );
        expect(
          parseImport("import 'package:flutter/material.dart?foo=bar';")
              .packageImport,
          isFalse,
        );
        expect(
          parseImport("import 'package:flutter/material.dart#frag';")
              .packageImport,
          isFalse,
        );
        expect(
          parseImport(
            "import 'package:flutter/material.dart' "
            "if (dart.library.js_interop) 'foo.dart';",
          ).packageImport,
          isFalse,
        );
        expect(
          parseImport("import 'file:///foo.dart';").packageImport,
          isFalse,
        );
        expect(parseImport("import 'foo.dart';").packageImport, isFalse);
        expect(parseImport(r"import '$foo';").packageImport, isFalse);
        expect(parseImport(r"import '$foo';").packageName, isEmpty);
      });
    });

    group('sanitizeSourceForAnalysis', () {
      test('blanks unsupported directives while preserving offsets', () {
        const source = '''
library my_lib;
import 'dart:math';
import 'other.dart';
import 'package:flutter/../other.dart';
export 'foo.dart';
part 'bar.dart';
void main() {
  print(pi);
}
''';
        final sanitized = sanitizeSourceForAnalysis(source);
        expect(sanitized.length, source.length);
        expect(sanitized.split('\n').length, source.split('\n').length);
        expect(sanitized, contains('library my_lib;'));
        expect(sanitized, contains("import 'dart:math';"));
        expect(sanitized, isNot(contains('other.dart')));
        expect(sanitized, isNot(contains('foo.dart')));
        expect(sanitized, isNot(contains('bar.dart')));
        expect(
          sanitized.indexOf('void main()'),
          equals(source.indexOf('void main()')),
        );
      });
    });
  });
}
