// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:typed_data';

import 'package:dartpad_frontend/features/startup/generated_pubspec.dart';
import 'package:dartpad_frontend/features/startup/project_loader.dart';
import 'package:test/test.dart';

void main() {
  for (final (version, constraint) in [
    ('3.14.2', '^3.14.2-0'),
    ('3.14.0 (build 3.14.0-201.0.dev)', '^3.14.0-0'),
    ('3.14.0-edge', '^3.14.0-0'),
    ('3.15.0-42.1.beta', '^3.15.0-0'),
  ]) {
    test('derives the SDK constraint from $version', () {
      expect(generatedSdkConstraint(version), constraint);
    });
  }

  test('rejects SDK metadata without a valid version instead of using a fixed fallback', () {
    for (final version in ['', 'unknown', '3.14', '3.14.0invalid']) {
      expect(() => generatedSdkConstraint(version), throwsFormatException);
    }
  });

  test('generates sorted dependencies from actual package directives', () {
    final pubspec = generatePubspec(
      inferPackageDependencies([
        _file('lib/main.dart', '''
import 'package:path/path.dart';
import 'package:flutter/material.dart';
export 'package:collection/collection.dart';
import 'package:path/posix.dart';
import 'package:_/src/helper.dart';
// import 'package:commented/commented.dart';
final text = "import 'package:string_literal/string_literal.dart';";
'''),
      ]),
      sdkConstraint: '^3.14.0-0',
    );

    expect(utf8.decode(pubspec.bytes), '''
name: _
publish_to: none

environment:
  sdk: ^3.14.0-0

dependencies:
  collection: any
  flutter:
    sdk: flutter
  path: any

flutter:
  uses-material-design: true
''');
  });

  test('extracts dependencies from conditional imports and exports', () {
    final pubspec = generatePubspec(
      inferPackageDependencies([
        _file('lib/main.dart', '''
import 'package:http/browser_client.dart'
    if (dart.library.io) 'package:http_io/io_client.dart';
'''),
      ]),
      sdkConstraint: '^3.14.0-0',
    );

    expect(utf8.decode(pubspec.bytes), '''
name: _
publish_to: none

environment:
  sdk: ^3.14.0-0

dependencies:
  http: any
  http_io: any
''');
  });

  test('extracts directives even when files contain syntax errors', () {
    final pubspec = generatePubspec(
      inferPackageDependencies([
        _file('lib/main.dart', '''
import 'package:args/args.dart';

void broken( {
  final x =
'''),
      ]),
      sdkConstraint: '^3.14.0-0',
    );

    expect(utf8.decode(pubspec.bytes), '''
name: _
publish_to: none

environment:
  sdk: ^3.14.0-0

dependencies:
  args: any
''');
  });

  test('omits dependencies when no package directives are present', () {
    final pubspec = generatePubspec(
      inferPackageDependencies([
        _file('lib/main.dart', "import 'dart:async';\nimport 'helper.dart';"),
        _file('README.md', "import 'package:not_dart/not_dart.dart';"),
      ]),
      sdkConstraint: '^3.14.0-0',
    );

    expect(utf8.decode(pubspec.bytes), '''
name: _
publish_to: none

environment:
  sdk: ^3.14.0-0
''');
  });
}

ProjectFile _file(String path, String contents) => ProjectFile(
  path: path,
  bytes: Uint8List.fromList(utf8.encode(contents)),
);
