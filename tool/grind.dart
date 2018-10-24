// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// ignore_for_file: always_declare_return_types

library dart_pad.grind;

import 'dart:io';

import 'package:git/git.dart';
import 'package:grinder/grinder.dart';
import 'package:yaml/yaml.dart' as yaml;

final FilePath _buildDir = new FilePath('build');
final FilePath _webDir = new FilePath('web');
final FilePath _pkgDir = new FilePath('third_party/pkg');
final FilePath _routeDir = new FilePath('third_party/pkg/route.dart');
final FilePath _haikunatorDir = new FilePath('third_party/pkg/haikunatordart');

Map get _env => Platform.environment;

main(List<String> args) => grind(args);

@Task('Copy the included route.dart/haikunator package in.')
updateThirdParty() {
  run('rm', arguments: ['-rf', _routeDir.path]);
  run('rm', arguments: ['-rf', _haikunatorDir.path]);
  new Directory(_pkgDir.path).createSync(recursive: true);
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
  new PubApp.local('tuneup')..run(['check']);
}

@Task()
testCli() async => await new TestRunner().testAsync(platformSelector: 'vm');

// This task require a frame buffer to run.
@Task()
testWeb() async {
  await new TestRunner().testAsync(platformSelector: 'chrome');
  log('Running route.dart tests...');
  run('pub', arguments: ['get'], workingDirectory: _routeDir.path);
  run('pub',
      arguments: ['run', 'test:test', '--platform=chrome'],
      workingDirectory: _routeDir.path);
}

@Task('Run bower')
bower() => run('bower', arguments: ['install', '--force-latest']);

@Task('Serve locally on port 8000')
@Depends(build)
serve() {
  run('pub', arguments: ['run', 'dhttpd', '-p', '8000', '--path=build/web']);
}

const String backendVariable = 'DARTPAD_BACKEND';
@Task(
    'Serve locally on port 8000 and use backend from ${backendVariable} environment variable')
@Depends(build)
serveCustomBackend() {
  if (!Platform.environment.containsKey(backendVariable)) {
    throw GrinderException(
        '${backendVariable} must be specified as [http|https]://host[:port]');
  }
  run('sed', arguments: [
    '-i',
    's,https://dart-services.appspot.com,${Platform.environment[backendVariable]},g',
    'build/web/scripts/main.dart.js',
    'build/web/scripts/embed.dart.js'
  ]);
  run('pub', arguments: ['run', 'dhttpd', '-p', '8000', '--path=build/web']);
}

@Task('Build the `web/index.html` entrypoint')
build() {
  // Copy our third party python code into web/.
  new FilePath('third_party/mdetect/mdetect.py').copy(_webDir);

  // Copy the codemirror script into web/scripts.
  new FilePath(_getCodeMirrorScriptPath()).copy(_webDir.join('scripts'));

  // copy web/ resources
  copyDirectory(webDir, joinDir(buildDir, ['web']));

  // copy lib/ resources
  copyDirectory(libDir, joinDir(buildDir, ['web', 'packages', 'dart_pad']));

  // copy other package resources
  copyPackageResources('codemirror', joinDir(buildDir, ['web']));

  // Compile main scripts.
  // Debugging: minify: false, extraArgs: ['--enable-asserts']
  Dart2js.compile(joinFile(webDir, ['scripts', 'main.dart']),
      outDir: joinDir(buildDir, ['web', 'scripts']), minify: true);
  Dart2js.compile(joinFile(webDir, ['scripts', 'embed.dart']),
      outDir: joinDir(buildDir, ['web', 'scripts']), minify: true);

  FilePath mainFile = _buildDir.join('web', 'scripts/main.dart.js');
  log('${mainFile} compiled to ${_printSize(mainFile)}');

  FilePath testFile = _buildDir.join('test', 'web.dart.js');
  if (testFile.exists)
    log('${testFile.path} compiled to ${_printSize(testFile)}');

  FilePath embedFile = _buildDir.join('web', 'scripts/embed.dart.js');
  log('${mainFile} compiled to ${_printSize(embedFile)}');

  // Remove .dart files.
  int count = 0;

  for (FileSystemEntity entity in getDir('build/web/packages')
      .listSync(recursive: true, followLinks: false)) {
    if (entity is! File) continue;
    if (!entity.path.endsWith('.dart')) continue;
    count++;
    entity.deleteSync();
  }

  log('Removed $count Dart files');

  // Run vulcanize.
  // Imports vulcanized, not inlined for IE support
  vulcanizeNoExclusion('scripts/imports.html');
  vulcanize('index.html');
  vulcanize('embed-dart.html');
  vulcanize('embed-html.html');
  vulcanize('embed-inline.html');
}

void copyPackageResources(String packageName, Directory destDir) {
  String text = new File('.packages').readAsStringSync();
  for (String line in text.split('\n')) {
    line = line.trim();
    if (line.isEmpty) {
      continue;
    }
    int index = line.indexOf(':');
    String name = line.substring(0, index);
    String location = line.substring(index + 1);
    if (name == packageName) {
      if (location.startsWith('file:')) {
        Uri uri = Uri.parse(location);

        copyDirectory(new Directory.fromUri(uri),
            joinDir(destDir, ['packages', packageName]));
      } else {
        copyDirectory(new Directory(location),
            joinDir(destDir, ['pacakges', packageName]));
      }
      return;
    }
  }

  fail('package $packageName not found in .packages file');
}

/// Return the path for `packages/codemirror/codemirror.js`.
String _getCodeMirrorScriptPath() {
  Map<String, String> packageToUri = {};
  for (String line in new File('.packages').readAsLinesSync()) {
    int index = line.indexOf(':');
    packageToUri[line.substring(0, index)] = line.substring(index + 1);
  }
  String packagePath = Uri.parse(packageToUri['codemirror']).path;
  return '${packagePath}codemirror.js';
}

// Run vulcanize
vulcanize(String filepath) {
  FilePath htmlFile = _buildDir.join('web', filepath);
  log('${htmlFile.path} original: ${_printSize(htmlFile)}');
  ProcessResult result = Process.runSync(
      'vulcanize',
      [
        '--strip-comments',
        '--inline-css',
        '--inline-scripts',
        '--exclude',
        'scripts/embed.dart.js',
        '--exclude',
        'scripts/main.dart.js',
        '--exclude',
        'scripts/codemirror.js',
        '--exclude',
        'scripts/embed_components.html',
        filepath
      ],
      workingDirectory: 'build/web');
  if (result.exitCode != 0) {
    fail('error running vulcanize: ${result.exitCode}\n${result.stderr}');
  }
  htmlFile.asFile.writeAsStringSync(result.stdout);

  log('${htmlFile.path} vulcanize: ${_printSize(htmlFile)}');
}

//Run vulcanize with no exclusions
vulcanizeNoExclusion(String filepath) {
  FilePath htmlFile = _buildDir.join('web', filepath);
  log('${htmlFile.path} original: ${_printSize(htmlFile)}');
  ProcessResult result = Process.runSync('vulcanize',
      ['--strip-comments', '--inline-css', '--inline-scripts', filepath],
      workingDirectory: 'build/web');
  if (result.exitCode != 0) {
    fail('error running vulcanize: ${result.exitCode}\n${result.stderr}');
  }
  htmlFile.asFile.writeAsStringSync(result.stdout);

  log('${htmlFile.path} vulcanize: ${_printSize(htmlFile)}');
}

@Task()
coverage() {
  if (!_env.containsKey('COVERAGE_TOKEN')) {
    log("env var 'COVERAGE_TOKEN' not found");
    return;
  }

  PubApp coveralls = new PubApp.global('dart_coveralls');
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
deploy() {
  // Validate the deploy.

  // `dev` is served from dev.dart-pad.appspot.com
  // `prod` is served from prod.dart-pad.appspot.com and from dartpad.dartlang.org.

  Map app = yaml.loadYaml(new File('web/app.yaml').readAsStringSync());

  List handlers = app['handlers'];
  bool isSecure = false;

  for (Map m in handlers) {
    if (m['url'] == '.*') {
      isSecure = m['secure'] == 'always';
    }
  }

  return GitDir.fromExisting('.').then((GitDir dir) {
    return dir.getCurrentBranch();
  }).then((BranchReference branchRef) {
    final String branch = branchRef.branchName;

    log('branch: ${branch}');

    if (branch == 'prod') {
      if (!isSecure) {
        fail('The prod branch must have `secure: always`.');
      }
    }

    log('\nexecute: `gcloud app deploy build/web/app.yaml --project=dart-pad --no-promote`');
  });
}

@Task()
clean() => defaultClean();

String _printSize(FilePath file) =>
    '${(file.asFile.lengthSync() + 1023) ~/ 1024}k';
