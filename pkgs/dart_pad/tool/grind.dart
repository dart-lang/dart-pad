// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// ignore_for_file: unreachable_from_main

import 'dart:convert';
import 'dart:io';

import 'package:dart_pad/services/common.dart';
import 'package:git/git.dart';
import 'package:grinder/grinder.dart';
import 'package:yaml/yaml.dart' as yaml;

final FilePath _buildDir = FilePath('build');

Map<String, String> get _env => Platform.environment;

Future<void> main(List<String> args) => grind(args);

@Task()
Future<void> testCli() async =>
    await TestRunner().testAsync(platformSelector: 'vm');

@Task('Serve locally on port 8000')
@Depends(build)
Future<void> serve() async {
  await Process.start(Platform.executable, ['bin/serve.dart'])
      .then((Process process) {
    process.stdout.transform(utf8.decoder).listen(stdout.write);
    process.stderr.transform(utf8.decoder).listen(stderr.write);
  });
}

@Task('Serve via local AppEngine on port 8080')
@Depends(build)
Future<void> serveLocalAppEngine() async {
  await Process.start(
    'dev_appserver.py',
    ['.'],
    workingDirectory: 'build',
  ).then((Process process) {
    process.stdout.transform(utf8.decoder).listen(stdout.write);
  });
}

@Task('Serve locally on port 8000 and use local server URLs')
@Depends(ConstTaskInvocation(
  'build',
  ConstTaskArgs('build', flags: {
    _debugFlag: true,
  }, options: {
    _serverUrlOption: 'http://127.0.0.1:8080/',
  }),
))
Future<void> serveLocalBackend() async {
  log('\nServing dart-pad on http://localhost:8000');

  await Process.start(Platform.executable, ['bin/serve.dart'])
      .then((Process process) {
    process.stdout.transform(utf8.decoder).listen(stdout.write);
  });
}

/// A grinder flag which directs build_runner to use the non-release mode, and
/// use DDC instead of dart2js.
const _debugFlag = 'debug';

/// A grinder option which specifies the URL of the back-end server.
const _serverUrlOption = 'server-url';

@Task('Build the `web/index.html` entrypoint')
void build() {
  final args = context.invocation.arguments;
  final compilerArgs = {
    if (args.hasOption(_serverUrlOption))
      serverUrlEnvironmentVar: args.getOption(_serverUrlOption),
  };
  PubApp.local('build_runner').run([
    'build',
    if (!args.hasFlag(_debugFlag)) '-r',
    if (compilerArgs.isNotEmpty)
      '--define=build_web_compilers:entrypoint='
          'dart2js_args=${_formatDart2jsArgs(compilerArgs)}',
    if (compilerArgs.isNotEmpty)
      '--define=build_web_compilers:ddc='
          'environment=${_formatDdcArgs(compilerArgs)}',
    '-o',
    'web:build',
    '--delete-conflicting-outputs',
  ]);

  final mainFile = _buildDir.join('scripts/playground.dart.js');
  log('$mainFile compiled to ${_printSize(mainFile)}');

  final testFile = _buildDir.join('test', 'web.dart.js');
  if (testFile.exists) {
    log('${testFile.path} compiled to ${_printSize(testFile)}');
  }

  final newEmbedDartFile = _buildDir.join('scripts/embed_dart.dart.js');
  log('$newEmbedDartFile compiled to ${_printSize(newEmbedDartFile)}');

  final newEmbedFlutterFile = _buildDir.join('scripts/embed_flutter.dart.js');
  log('$newEmbedFlutterFile compiled to ${_printSize(newEmbedFlutterFile)}');

  final newEmbedFlutterShowcaseFile =
      _buildDir.join('scripts/embed_flutter_showcase.dart.js');
  log('$newEmbedFlutterShowcaseFile compiled to ${_printSize(newEmbedFlutterShowcaseFile)}');

  final newEmbedHtmlFile = _buildDir.join('scripts/embed_html.dart.js');
  log('$newEmbedHtmlFile compiled to ${_printSize(newEmbedHtmlFile)}');

  final newEmbedInlineFile = _buildDir.join('scripts/embed_inline.dart.js');
  log('$newEmbedInlineFile compiled to ${_printSize(newEmbedInlineFile)}');

  // Remove .dart files.
  var count = 0;

  for (final entity in getDir('build/packages')
      .listSync(recursive: true, followLinks: false)) {
    if (entity is! File) continue;
    if (!entity.path.endsWith('.dart')) continue;
    count++;
    entity.deleteSync();
  }

  log('Removed $count Dart files');
}

/// Formats a map of argument key and values to be passed as `dart2js_args` for
/// webdev.
String _formatDart2jsArgs(Map<String, String?> args) {
  final values = args.entries.map((entry) => '"-D${entry.key}=${entry.value}"');
  return '[${values.join(',')}]';
}

/// Formats a map of argument key and values to be passed as DDC environment
/// variables.
String _formatDdcArgs(Map<String, String?> args) {
  final values = args.entries.map((entry) => '"${entry.key}":"${entry.value}"');
  return '{${values.join(',')}}';
}

@Task()
void coverage() {
  if (!_env.containsKey('COVERAGE_TOKEN')) {
    log("env var 'COVERAGE_TOKEN' not found");
    return;
  }

  final coveralls = PubApp.global('dart_coveralls');
  coveralls.run([
    'report',
    '--token',
    _env['COVERAGE_TOKEN']!,
    '--retry',
    '2',
    '--exclude-test-files',
    'test/all.dart'
  ]);
}

@DefaultTask()
@Depends(testCli, coverage, build)
void buildbot() {}

@Task('Prepare the app for deployment')
@Depends(buildbot)
Future<void> deploy() async {
  // Validate the deploy.

  // `dev` is served from dev.dart-pad.appspot.com
  // `prod` is served from prod.dart-pad.appspot.com and from dartpad.dartlang.org.

  final app = yaml.loadYaml(File('web/app.yaml').readAsStringSync()) as Map;

  // ignore: strict_raw_type
  final handlers = (app['handlers'] as List).cast<Map>();
  var isSecure = false;

  for (final m in handlers) {
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
void clean() => defaultClean();

String _printSize(FilePath file) =>
    '${(file.asFile.lengthSync() + 1023) ~/ 1024}k';

/// An implementation of [TaskArgs] which can be used as a const value in an
/// annotation.
class ConstTaskArgs implements TaskArgs {
  @override
  final String taskName;
  final Map<String, bool> _flags;
  final Map<String, String> _options;

  const ConstTaskArgs(
    this.taskName, {
    Map<String, bool> flags = const {},
    Map<String, String> options = const {},
  })  : _flags = flags,
        _options = options;

  @override
  bool hasFlag(String name) => _flags.containsKey(name);

  @override
  bool getFlag(String name) => _flags[name] ?? false;

  @override
  bool hasOption(String name) => _options.containsKey(name);

  @override
  String? getOption(String name) => _options[name];

  @override
  List<String> get arguments => throw UnimplementedError();
}

/// An implementation of [TaskInvocation] which can be used as a const value in
/// an annotation.
class ConstTaskInvocation implements TaskInvocation {
  @override
  final String name;
  final TaskArgs _arguments;

  const ConstTaskInvocation(this.name, this._arguments);

  @override
  TaskArgs get arguments => _arguments;
}
