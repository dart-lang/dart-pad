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

    group('isSafeUri', () {
      test('accepts dart: and package: URIs', () {
        for (final uri in [
          'dart:core',
          'dart:io',
          'dart:ui_web',
          'package:flutter/material.dart',
          'package:foo/bar/baz.dart',
          'package:foo/src/a-b.g.dart',
        ]) {
          expect(isSafeUri(uri), isTrue, reason: uri);
        }
      });

      test('accepts incomplete URIs', () {
        for (final uri in ['dart:', 'package:', 'package:flutter/']) {
          expect(isSafeUri(uri), isTrue, reason: uri);
        }
      });

      test('rejects other URIs', () {
        for (final uri in [
          null,
          '',
          'foo.dart',
          '/foo.dart',
          'file:///foo.dart',
          'http://example.com/foo.dart',
          'dart:.',
          'dart:..',
          'dart:core/foo.dart',
          'dart:core?foo=bar',
          r'dart:core\foo',
          'dart:core%2ffoo',
          'package:/flutter/material.dart',
          'package:flutter//foo.dart',
          'package:flutter/./material.dart',
          'package:flutter/../foo.dart',
          'package:flutter/%2e%2e/foo.dart',
          r'package:flutter\material.dart',
          'package:flutter/material.dart?foo=bar',
          'package:flutter/material.dart#frag',
          'package:foo-bar/foo.dart',
          'PACKAGE:flutter/material.dart',
          ' package:flutter/material.dart',
        ]) {
          expect(isSafeUri(uri), isFalse, reason: uri);
        }
      });
    });

    group('isSafeDirective', () {
      Directive parseDirective(String source) =>
          getAllDirectivesFor(source).single;

      test('accepts library directives and dart:/package: imports', () {
        for (final source in [
          'library;',
          'library foo.bar;',
          "@JS('foo') library;",
          "import 'dart:async' deferred as async;",
          "import 'package:flutter/material.dart' show Widget;",
          "import 'package:fl' 'utter/material.dart';",
          "import 'package:http/http.dart' "
              "if (dart.library.js_interop) 'package:http/browser_client.dart';",
          "export 'package:flutter/material.dart';",
          "export 'dart:math';",
        ]) {
          expect(
            isSafeDirective(parseDirective(source)),
            isTrue,
            reason: source,
          );
        }
      });

      test('rejects other directives', () {
        for (final source in [
          "import 'foo.dart';",
          r"import '$foo';",
          "import 'package:flutter/../foo.dart';",
          "import 'dart:core' if (dart.library.js_interop) 'foo.dart';",
          "export 'foo.dart';",
          "part 'foo.dart';",
          "part of 'foo.dart';",
          'part of foo;',
        ]) {
          expect(
            isSafeDirective(parseDirective(source)),
            isFalse,
            reason: source,
          );
        }
      });

      test('getUnsafeDirectives returns unsafe directives in order', () {
        const source = '''
library;
import 'dart:io';
import 'package:unsupported/foo.dart';
import 'foo.dart';
export 'bar.dart';
part 'baz.dart';
void main() {}
''';
        expect(getUnsafeDirectives(source).map((d) => d.toSource()), [
          "import 'foo.dart';",
          "export 'bar.dart';",
          "part 'baz.dart';",
        ]);
      });
    });

    group('sanitizeSourceForAnalysis', () {
      test('keeps safe sources unchanged', () {
        const source = '''
/// @docImport 'package:flutter/material.dart';
library my_lib;
import 'dart:math';
import 'package:flutter/material.dart';
void main() {
  print(pi);
}
''';
        expect(sanitizeSourceForAnalysis(source), source);
      });

      test('blanks unsafe directives while preserving offsets', () {
        const source =
            'library my_lib;\r\n'
            "import 'dart:math';\r\n"
            "import 'other.dart';\n"
            "import 'package:flutter/../other.dart';\n"
            "export 'foo.dart';\n"
            "part 'bar.dart';\n"
            "import 'dart:core' if (dart.library.io) 'baz.dart';\n"
            '// 🎯\n'
            'void main() {\n'
            '  print(pi);\n'
            '}\n';
        final sanitized = sanitizeSourceForAnalysis(source);
        expect(sanitized.length, source.length);
        expect('\r'.allMatches(sanitized), hasLength(2));
        expect(
          '\n'.allMatches(sanitized),
          hasLength('\n'.allMatches(source).length),
        );
        expect(sanitized, startsWith("library my_lib;\r\nimport 'dart:math';"));
        for (final name in ['other.dart', 'foo.dart', 'bar.dart', 'baz.dart']) {
          expect(sanitized, isNot(contains(name)));
        }
        expect(sanitized.indexOf('void main()'), source.indexOf('void main()'));
        expect(sanitized, contains('// 🎯\n'));
      });

      test('blanks documentation imports with unsafe URIs', () {
        const source = '''
/// @docImport 'other.dart';
/// @docImport 'package:flutter/material.dart';
library;

/// See [Foo].
void main() {}
''';
        final sanitized = sanitizeSourceForAnalysis(source);
        expect(sanitized.length, source.length);
        expect('@docImport'.allMatches(sanitized), hasLength(1));
        expect(
          sanitized,
          contains("/// @docImport 'package:flutter/material.dart';"),
        );
        expect(sanitized, contains("///            'other.dart';"));
      });

      test('handles overlapping directive ranges', () {
        const source = 'part \n/// doc\nexport ';
        final sanitized = sanitizeSourceForAnalysis(source);
        expect(sanitized.length, source.length);
        expect(getUnsafeDirectives(sanitized), isEmpty);
      });

      test('result contains no unsafe directives when parsed again', () {
        for (final source in [
          'library export {;part of ',
          "import 'foo.dart' import 'dart:core';",
          "void main() {}\nimport 'foo.dart';",
        ]) {
          final sanitized = sanitizeSourceForAnalysis(source);
          expect(sanitized.length, source.length, reason: source);
          expect(getUnsafeDirectives(sanitized), isEmpty, reason: source);
          expect(sanitizeSourceForAnalysis(sanitized), sanitized);
        }
      });
    });
  });
}
