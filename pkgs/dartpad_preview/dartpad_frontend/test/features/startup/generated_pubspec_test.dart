// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:typed_data';

import 'package:dartpad_frontend/features/startup/generated_pubspec.dart';
import 'package:dartpad_frontend/features/startup/project_loader.dart';
import 'package:test/test.dart';

void main() {
  test('generates sorted dependencies from actual package directives', () {
    final pubspec = generatePubspec([
      _file('lib/main.dart', '''
import 'package:path/path.dart';
import 'package:flutter/material.dart';
export 'package:collection/collection.dart';
import 'package:path/posix.dart';
// import 'package:commented/commented.dart';
final text = "import 'package:string_literal/string_literal.dart';";
'''),
    ]);

    expect(utf8.decode(pubspec.bytes), '''
name: app
publish_to: none

environment:
  sdk: ^3.12.0

dependencies:
  collection: any
  flutter:
    sdk: flutter
  path: any

flutter:
  uses-material-design: true
''');
  });

  test('omits dependencies when no package directives are present', () {
    final pubspec = generatePubspec([
      _file('lib/main.dart', "import 'dart:async';\nimport 'helper.dart';"),
      _file('README.md', "import 'package:not_dart/not_dart.dart';"),
    ]);

    expect(utf8.decode(pubspec.bytes), '''
name: app
publish_to: none

environment:
  sdk: ^3.12.0
''');
  });
}

ProjectFile _file(String path, String contents) => ProjectFile(
  path: path,
  bytes: Uint8List.fromList(utf8.encode(contents)),
);
