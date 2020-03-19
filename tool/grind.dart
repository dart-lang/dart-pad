// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// ignore_for_file: always_declare_return_types

library dart_pad.grind;

import 'dart:convert';
import 'dart:io';

import 'package:git/git.dart';
import 'package:grinder/grinder.dart';
import 'package:yaml/yaml.dart' as yaml;

final FilePath _buildDir = FilePath('build');
final FilePath _pkgDir = FilePath('third_party/pkg');
final FilePath _routeDir = FilePath('third_party/pkg/route.dart');
final FilePath _haikunatorDir = FilePath('third_party/pkg/haikunatordart');

Map<String, String> get _env => Platform.environment;

main(List<String> args) => grind(args);

@Task('Copy the included route.dart/haikunator package in.')
updateThirdParty() {
  run('rm', arguments: ['-rf', _routeDir.path]);
  run('rm', arguments: ['-rf', _haikunatorDir.path]);
  Directory(_pkgDir.path).createSync(recursive: true);
  run('git', arguments: [
    'clone',
    '--branch',
    'dart2-route',
    '--depth=1',
    'git@github.com:jcollins-g/route.dart.git',
    _routeDir.path
  ]);
  run('git', arguments: [
    'clone',
    '--branch',
    'dart2-stable',
    '--depth=1',
    'git@github.com:jcollins-g/haikunatordart.git',
    _haikunatorDir.path
  ]);
  run('rm', workingDirectory: _routeDir.path, arguments: ['-rf', '.git']);
  run('rm', workingDirectory: _haikunatorDir.path, arguments: ['-rf', '.git']);
}

@Task()
analyze() {
  PubApp.local('tuneup')..run(['check']);
}

@Task()
testCli() async => await TestRunner().testAsync(platformSelector: 'vm');

// This task require a frame buffer to run.
@Task()
testWeb() async {
  await TestRunner().testAsync(platformSelector: 'chrome');
  log('Running route.dart tests...');
  run('pub', arguments: ['get'], workingDirectory: _routeDir.path);
  run('pub',
      arguments: ['run', 'test:test', '--platform=chrome'],
      workingDirectory: _routeDir.path);
}

@Task('Serve locally on port 8000')
@Depends(build)
serve() async {
  await Process.start(Platform.executable, ['bin/serve.dart'])
      .then((Process process) {
    process.stdout.transform(utf8.decoder).listen(stdout.write);
  });
}

@Task('Serve via local AppEngine on port 8080')
@Depends(build)
serveLocalAppEngine() async {
  await Process.start(
    'dev_appserver.py',
    ['.'],
    workingDirectory: 'build',
  ).then((Process process) {
    process.stdout.transform(utf8.decoder).listen(stdout.write);
  });
}

const String backendVariable = 'DARTPAD_BACKEND';

@Task(
    'Serve locally on port 8002 and use backend from $backendVariable environment variable')
@Depends(build)
serveCustomBackend() async {
  if (!Platform.environment.containsKey(backendVariable)) {
    print('$backendVariable can be specified (as [http|https]://host[:port]) '
        'to indicate the dart-services server to connect to');
  }

  final serverUrl =
      Platform.environment[backendVariable] ?? 'http://localhost:8002';

  // In all files *.dart.js in build/scripts/, replace
  // 'https://dart-services.appspot.com' with serverUrl.
  final files = <FileSystemEntity>[];
  files.addAll(_buildDir.join('scripts').asDirectory.listSync());
  for (var entity in files) {
    if (entity is! File) continue;
    if (!entity.path.endsWith('.dart.js')) continue;

    final file = entity as File;

    log('Rewriting server url to $serverUrl for ${file.path}');

    var fileContents = file.readAsStringSync();
    fileContents =
        fileContents.replaceAll('https://dart-services.appspot.com', serverUrl);
    file.writeAsStringSync(fileContents);
  }

  log('\nServing dart-pad on http://localhost:8000');

  await Process.start(Platform.executable, ['bin/serve.dart'])
      .then((Process process) {
    process.stdout.transform(utf8.decoder).listen(stdout.write);
  });
}

@Task('Build the `web/index.html` entrypoint')
build() {
  PubApp.local('build_runner').run(['build', '-r', '-o', 'web:build']);

  var mainFile = _buildDir.join('scripts/playground.dart.js');
  log('$mainFile compiled to ${_printSize(mainFile)}');

  var testFile = _buildDir.join('test', 'web.dart.js');
  if (testFile.exists) {
    log('${testFile.path} compiled to ${_printSize(testFile)}');
  }

  var newEmbedDartFile = _buildDir.join('scripts/embed_dart.dart.js');
  log('$newEmbedDartFile compiled to ${_printSize(newEmbedDartFile)}');

  var newEmbedFlutterFile = _buildDir.join('scripts/embed_flutter.dart.js');
  log('$newEmbedFlutterFile compiled to ${_printSize(newEmbedFlutterFile)}');

  var newEmbedHtmlFile = _buildDir.join('scripts/embed_html.dart.js');
  log('$newEmbedHtmlFile compiled to ${_printSize(newEmbedHtmlFile)}');

  var newEmbedInlineFile = _buildDir.join('scripts/embed_inline.dart.js');
  log('$newEmbedInlineFile compiled to ${_printSize(newEmbedInlineFile)}');

  // Remove .dart files.
  var count = 0;

  for (var entity in getDir('build/packages')
      .listSync(recursive: true, followLinks: false)) {
    if (entity is! File) continue;
    if (!entity.path.endsWith('.dart')) continue;
    count++;
    entity.deleteSync();
  }

  log('Removed $count Dart files');

  // Run vulcanize.
  // Imports vulcanized, not inlined for IE support
  vulcanize('index.html');
  vulcanize('embed-dart.html');
  vulcanize('embed-html.html');
  vulcanize('embed-flutter.html');
  vulcanize('embed-inline.html');
}

void copyPackageResources(String packageName, Directory destDir) {
  var text = File('.packages').readAsStringSync();
  for (var line in text.split('\n')) {
    line = line.trim();
    if (line.isEmpty) {
      continue;
    }
    var index = line.indexOf(':');
    var name = line.substring(0, index);
    var location = line.substring(index + 1);
    if (name == packageName) {
      if (location.startsWith('file:')) {
        var uri = Uri.parse(location);

        copyDirectory(Directory.fromUri(uri),
            joinDir(destDir, ['packages', packageName]));
      } else {
        copyDirectory(
            Directory(location), joinDir(destDir, ['packages', packageName]));
      }
      return;
    }
  }

  fail('package $packageName not found in .packages file');
}

// Run vulcanize
vulcanize(String filepath) {
  var htmlFile = _buildDir.join(filepath);
  log('${htmlFile.path} original: ${_printSize(htmlFile)}');
  var result = Process.runSync(
      'vulcanize',
      [
        '--strip-comments',
        '--inline-css',
        '--inline-scripts',
        '--exclude',
        ' scripts/embed_dart.dart.js',
        '--exclude',
        ' scripts/embed_flutter.dart.js',
        '--exclude',
        ' scripts/embed_html.dart.js',
        '--exclude',
        ' scripts/embed_inline.dart.js',
        '--exclude',
        'scripts/playground.dart.js',
        '--exclude',
        'scripts/codemirror.js',
        filepath,
      ],
      workingDirectory: _buildDir.path);
  if (result.exitCode != 0) {
    fail('error running vulcanize: ${result.exitCode}\n${result.stderr}');
  }
  htmlFile.asFile.writeAsStringSync(result.stdout as String);

  log('${htmlFile.path} vulcanize: ${_printSize(htmlFile)}');
}

//Run vulcanize with no exclusions
vulcanizeNoExclusion(String filepath) {
  var htmlFile = _buildDir.join(filepath);
  log('${htmlFile.path} original: ${_printSize(htmlFile)}');
  var result = Process.runSync('vulcanize',
      ['--strip-comments', '--inline-css', '--inline-scripts', filepath],
      workingDirectory: _buildDir.path);
  if (result.exitCode != 0) {
    fail('error running vulcanize: ${result.exitCode}\n${result.stderr}');
  }
  htmlFile.asFile.writeAsStringSync(result.stdout as String);

  log('${htmlFile.path} vulcanize: ${_printSize(htmlFile)}');
}

@Task()
coverage() {
  if (!_env.containsKey('COVERAGE_TOKEN')) {
    log("env var 'COVERAGE_TOKEN' not found");
    return;
  }

  var coveralls = PubApp.global('dart_coveralls');
  coveralls.run([
    'report',
    '--token',
    _env['COVERAGE_TOKEN'],
    '--retry',
    '2',
    '--exclude-test-files',
    'test/all.dart'
  ]);
}

@DefaultTask()
@Depends(analyze, testCli, testWeb, coverage, build)
void buildbot() => null;

@Task('Prepare the app for deployment')
@Depends(buildbot)
deploy() async {
  // Validate the deploy.

  // `dev` is served from dev.dart-pad.appspot.com
  // `prod` is served from prod.dart-pad.appspot.com and from dartpad.dartlang.org.

  var app = yaml.loadYaml(File('web/app.yaml').readAsStringSync()) as Map;

  var handlers = app['handlers'];
  var isSecure = false;

  for (var m in handlers) {
    if (m['url'] == '.*') {
      isSecure = m['secure'] == 'always';
    }
  }

  final dir = await GitDir.fromExisting('.');
  final branchRef = await dir.currentBranch();
  final branch = branchRef.branchName;

  log('branch: $branch');

  if (branch == 'prod') {
    if (!isSecure) {
      fail('The prod branch must have `secure: always`.');
    }
  }

  log('\nexecute: `gcloud app deploy build/app.yaml --project=dart-pad --no-promote`');
}

@Task()
clean() => defaultClean();

String _printSize(FilePath file) =>
    '${(file.asFile.lengthSync() + 1023) ~/ 1024}k';

@Task('Generate Protobuf classes')
void generateProtos() {
  final result = Process.runSync(
    'protoc',
    ['--dart_out=lib/src', 'protos/dart_services.proto'],
  );
  print(result.stdout);
  if (result.exitCode != 0) {
    throw 'Error generating the Protobuf classes\n${result.stderr}';
  }

  // generate common_server_proto.g.dart
  Pub.run('build_runner', arguments: ['build', '--delete-conflicting-outputs']);
}
