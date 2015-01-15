// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dartpad_ui.grind;

import 'dart:io';

import 'package:grinder/grinder.dart';

final Directory BUILD_DIR = new Directory('build');

void main(List<String> args) {
  task('init', defaultInit);
  task('build', build, ['init']);
  task('deploy', deploy, ['build']);
  task('clean', defaultClean);

  startGrinder(args);
}

/// Build the `web/dartpad.html` entrypoint.
void build(GrinderContext context) {
  Pub.build(context, directories: ['web']);

  File outFile = joinFile(BUILD_DIR, ['web', 'dartpad.dart.js']);
  context.log('${outFile.path} compiled to ${_printSize(outFile)}');

  // Delete the build/web/packages directory.
  deleteEntity(getDir('build/web/packages'));

  // Reify the symlinks.
  // cp -R -L packages build/web/packages
  runProcess(context, 'cp',
      arguments: ['-R', '-L', 'packages', 'build/web/packages']);
}

/// Prepare the app for deployment.
void deploy(GrinderContext context) {
  context.log('execute: `appcfg.py update build/web`');
}

String _printSize(File file) => '${(file.lengthSync() + 1023) ~/ 1024}k';
