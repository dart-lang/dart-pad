// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dartpad_ui.grind;

import 'dart:io';

import 'package:ghpages_generator/ghpages_generator.dart' as ghpages;
import 'package:grinder/grinder.dart';

final Directory BUILD_DIR = new Directory('build');

void main(List<String> args) {
  task('init', defaultInit);
  task('build', build, ['init']);
  task('gh-pages', copyGhPages, ['build']);
  task('clean', defaultClean);

  startGrinder(args);
}

/// Build the `web/dartpad.html` entrypoint.
void build(GrinderContext context) {
  Pub.build(context, directories: ['web']);

  File outFile = joinFile(BUILD_DIR, ['web', 'dartpad.dart.js']);
  context.log('${outFile.path} compiled to ${_printSize(outFile)}');

  // TODO: tar it up now? How to distribute?

}

/// Generate a new version of gh-pages.
void copyGhPages(GrinderContext context) {
  context.log('Copying build/web to the `gh-pages` branch');
  new ghpages.Generator(rootDir: getDir('.').absolute.path)
      ..templateDir = getDir('build/web').absolute.path
      ..generate();
}

String _printSize(File file) => '${(file.lengthSync() + 1023) ~/ 1024}k';
