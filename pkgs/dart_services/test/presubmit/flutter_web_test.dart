// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:dart_services/src/project_templates.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

void main() {
  final projectTemplates = ProjectTemplates.instance;

  group('FlutterWebManager', () {
    test('initializes', () async {
      expect(await Directory(projectTemplates.flutterPath).exists(), isTrue);
      final file = File(
        path.join(
          projectTemplates.flutterPath,
          '.dart_tool',
          'package_config.json',
        ),
      );
      expect(await file.exists(), isTrue);
    });

    test('isFlutterWebImport', () {
      expect(isFlutterWebImport(''), isFalse);
      expect(isFlutterWebImport('dart:js_interop'), isFalse);
      expect(isFlutterWebImport('dart:ui'), isTrue);
      expect(isFlutterWebImport('package:flutter/'), isTrue);
    });

    test('isSupportedCoreLibrary allows dart:js_interop', () {
      expect(isSupportedCoreLibrary('js_interop'), isTrue);
    });

    test('isSupportedCoreLibrary allows dart:ui', () {
      expect(isSupportedCoreLibrary('ui'), isTrue);
    });

    test('isSupportedCoreLibrary does not allow VM-only imports', () {
      expect(isSupportedCoreLibrary('io'), isFalse);
    });

    test('isSupportedCoreLibrary allows deprecated web libraries for now', () {
      expect(isSupportedCoreLibrary('html'), isTrue);
    });

    test('isSupportedPackage allows package:flutter', () {
      expect(isSupportedPackage('flutter'), isTrue);
    });

    test('isSupportedPackage allows package:path', () {
      expect(isSupportedPackage('path'), isTrue);
    });

    test('isSupportedPackage does not allow package:unsupported', () {
      expect(isSupportedPackage('unsupported'), isFalse);
    });

    test('isSupportedPackage does not allow random local imports', () {
      expect(isSupportedPackage('foo.dart'), isFalse);
    });

    test('getUnsupportedImports allows supported dart and package imports', () {
      const source = '''
library foo;
import 'dart:async';
import 'dart:core';
import 'dart:js_interop';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
void main() {}
''';
      expect(getUnsupportedImports(source), isEmpty);
    });

    test(
      'getUnsupportedImports rejects unsupported imports and directives',
      () {
        expect(
          getUnsupportedImports("import 'file:///foo.dart';"),
          hasLength(1),
        );
        expect(getUnsupportedImports("import '/foo.dart';"), hasLength(1));
        expect(getUnsupportedImports("import 'foo.dart';"), hasLength(1));
        expect(
          getUnsupportedImports("import 'http://example.com/foo.dart';"),
          hasLength(1),
        );
        expect(getUnsupportedImports("import 'dart:io';"), hasLength(1));
        expect(
          getUnsupportedImports("import 'dart:core/../foo.dart';"),
          hasLength(1),
        );
        expect(
          getUnsupportedImports("import 'package:unsupported/foo.dart';"),
          hasLength(1),
        );
        expect(
          getUnsupportedImports("import 'package:flutter/../foo.dart';"),
          hasLength(1),
        );
        expect(
          getUnsupportedImports("import 'package:flutter//foo.dart';"),
          hasLength(1),
        );
        expect(
          getUnsupportedImports(
            "import 'dart:core' if (dart.library.js_interop) 'foo.dart';",
          ),
          hasLength(1),
        );
        expect(getUnsupportedImports("export 'dart:core';"), hasLength(1));
        expect(getUnsupportedImports("part 'foo.dart';"), hasLength(1));
        expect(getUnsupportedImports("part of 'foo.dart';"), hasLength(1));
      },
    );
  });

  group('flutter web project', () {
    test('packagesFilePath', () async {
      final packageConfig = File(
        path.join(
          projectTemplates.flutterPath,
          '.dart_tool',
          'package_config.json',
        ),
      );
      expect(await packageConfig.exists(), true);
      final encoded = await packageConfig.readAsString();
      final contents = jsonDecode(encoded) as Map<String, dynamic>;
      expect(contents['packages'], isNotEmpty);
      final packages = contents['packages'] as List<dynamic>;
      expect(
        packages.where((element) => (element as Map)['name'] == 'flutter'),
        isNotEmpty,
      );
    });

    test('summaryFilePath', () {
      final summaryFilePath = projectTemplates.summaryFilePath;
      expect(summaryFilePath, isNotEmpty);

      final file = File(summaryFilePath);
      expect(file.existsSync(), isTrue);
    });
  });
}
