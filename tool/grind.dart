// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dartpad_ui.grind;

import 'dart:io';

import 'package:grinder/grinder.dart';

final Directory BUILD_DIR = new Directory('build');

void main(List<String> args) {
  task('init', init);
  task('build', build, ['init']);
  task('clean', clean);

  startGrinder(args);
}

/// Do any necessary build set up.
void init(GrinderContext context) {
  // Verify we're running in the project root.
  if (!getDir('lib').existsSync() || !getFile('pubspec.yaml').existsSync()) {
    context.fail('This script must be run from the project root.');
  }
}

/// Build the `web/dartpad.html` entrypoint.
void build(GrinderContext context) {
  Pub.build(context, directories: ['web']);

  File outFile = joinFile(BUILD_DIR, ['web', 'dartpad.dart.js']);
  context.log('${outFile.path} compiled to ${_printSize(outFile)}');

  // TODO: tar it up now? How to distribute?

}

/// Delete all generated artifacts.
void clean(GrinderContext context) {
  // Delete the build/ dir.
  deleteEntity(BUILD_DIR, context);
}

String _printSize(File file) => '${(file.lengthSync() + 1023) ~/ 1024}k';
