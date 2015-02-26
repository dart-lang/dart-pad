// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dart_pad.grind;

import 'dart:async';
import 'dart:io';

import 'package:grinder/grinder.dart';
import 'package:librato/librato.dart';

void main(List<String> args) {
  task('init', defaultInit);
  task('bower', bower, ['init']);
  task('build', build, ['init']);
  task('deploy', deploy, ['bower', 'build']);
  task('clean', defaultClean);

  startGrinder(args);
}

/// Run bower.
bower(GrinderContext context) {
  runProcess(context, 'bower', arguments: ['install']);
}

/// Build the `web/index.html` entrypoint.
build(GrinderContext context) {
  Pub.build(context, directories: ['web', 'test']);

  File mainFile = joinFile(BUILD_DIR, ['web', 'main.dart.js']);
  File mobileFile = joinFile(BUILD_DIR, ['web', 'mobile.dart.js']);
  File testFile = joinFile(BUILD_DIR, ['test', 'web.dart.js']);

  context.log('${mainFile.path} compiled to ${_printSize(mainFile)}');
  context.log('${mobileFile.path} compiled to ${_printSize(mobileFile)}');
  context.log('${testFile.path} compiled to ${_printSize(testFile)}');

  // Delete the build/web/packages directory.
  deleteEntity(getDir('build/web/packages'));

  // Reify the symlinks.
  // cp -R -L packages build/web/packages
  runProcess(context, 'cp',
      arguments: ['-R', '-L', 'packages', 'build/web/packages']);

  // Run vulcanize.
  File mobileHtmlFile = joinFile(BUILD_DIR, ['web', 'mobile.html']);
  context.log('${mobileHtmlFile.path} original: ${_printSize(mobileHtmlFile)}');
  runProcess(context,
      'vulcanize', // '--csp', '--inline',
      arguments: ['--strip', '--output', 'mobile.html', 'mobile.html'],
      workingDirectory: 'build/web');
  context.log('${mobileHtmlFile.path} vulcanize: ${_printSize(mobileHtmlFile)}');

  return _uploadCompiledStats(context,
      mainFile.lengthSync(), mobileFile.lengthSync());
}

/// Prepare the app for deployment.
void deploy(GrinderContext context) {
  context.log('execute: `appcfg.py update build/web`');
}

Future _uploadCompiledStats(GrinderContext context, num mainLength,
    int mobileLength) {
  Map env = Platform.environment;

  if (env.containsKey('LIBRATO_USER') && env.containsKey('TRAVIS_COMMIT')) {
    Librato librato = new Librato.fromEnvVars();
    context.log('Uploading stats to ${librato.baseUrl}');
    LibratoStat mainSize = new LibratoStat('main.dart.js', mainLength);
    LibratoStat mobileSize = new LibratoStat('mobileSize.dart.js', mobileLength);
    return librato.postStats([mainSize, mobileSize]).then((_) {
      String commit = env['TRAVIS_COMMIT'];
      LibratoLink link = new LibratoLink(
          'github',
          'https://github.com/dart-lang/dart-pad/commit/${commit}');
      LibratoAnnotation annotation = new LibratoAnnotation(
          commit,
          description: 'Commit ${commit}',
          links: [link]);
      return librato.createAnnotation('build_ui', annotation);
    });
  } else {
    return new Future.value();
  }
}

String _printSize(File file) => '${(file.lengthSync() + 1023) ~/ 1024}k';
