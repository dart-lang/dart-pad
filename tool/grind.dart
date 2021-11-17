// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// ignore_for_file: always_declare_return_types

library dart_pad.grind;

import 'dart:convert';
import 'dart:io';

import 'package:dart_pad/services/common.dart';
import 'package:git/git.dart';
import 'package:grinder/grinder.dart';
import 'package:yaml/yaml.dart' as yaml;

final FilePath _buildDir = FilePath('build');

Map<String, String> get _env => Platform.environment;

main(List<String> args) => grind(args);

@Task()
testCli() async => await TestRunner().testAsync(platformSelector: 'vm');

@Task('Serve locally on port 8000')
@Depends(build)
serve() async {
  await Process.start(Platform.executable, ['bin/serve.dart'])
      .then((Process process) {
    process.stdout.transform(utf8.decoder).listen(stdout.write);
    process.stderr.transform(utf8.decoder).listen(stderr.write);
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

@Task('Serve locally on port 8000 and use local server URLs')
@Depends(ConstTaskInvocation(
  'build',
  ConstTaskArgs('build', flags: {
    _debugFlag: true,
  }, options: {
    _nullSafetyServerUrlOption: 'http://127.0.0.1:8084/',
  }),
))
serveLocalBackend() async {
  log('\nServing dart-pad on http://localhost:8000');

  await Process.start(Platform.executable, ['bin/serve.dart'])
      .then((Process process) {
    process.stdout.transform(utf8.decoder).listen(stdout.write);
  });
}

@Task('Serve locally on port 8000 and use beta server URL for pre null-safe')
@Depends(ConstTaskInvocation(
  'build',
  ConstTaskArgs('build', options: {}),
))
serveBetaBackend() async {
  log('\nServing dart-pad on http://localhost:8000');

  await Process.start(Platform.executable, ['bin/serve.dart'])
      .then((Process process) {
    process.stdout.transform(utf8.decoder).listen(stdout.write);
  });
}

@Task('Serve locally on port 8000 and use dev server URL for pre null-safe')
@Depends(ConstTaskInvocation(
  'build',
  ConstTaskArgs('build', options: {}),
))
serveDevBackend() async {
  log('\nServing dart-pad on http://localhost:8000');

  await Process.start(Platform.executable, ['bin/serve.dart'])
      .then((Process process) {
    process.stdout.transform(utf8.decoder).listen(stdout.write);
  });
}

/// A grinder flag which directs build_runner to use the non-release mode, and
/// use DDC instead of dart2js.
const _debugFlag = 'debug';

/// A grinder option which specifies the URL of the null safety back-end
/// server.
const _nullSafetyServerUrlOption = 'null-safety-server-url';

@Task('Build the `web/index.html` entrypoint')
@Depends(generateProtos)
build() {
  final args = context.invocation.arguments;
  final compilerArgs = {
    if (args.hasOption(_nullSafetyServerUrlOption))
      nullSafetyServerUrlEnvironmentVar:
          args.getOption(_nullSafetyServerUrlOption),
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
coverage() {
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
@Depends(generateProtos, testCli, coverage, build)
void buildbot() {}

@Task('Prepare the app for deployment')
@Depends(buildbot)
deploy() async {
  // Validate the deploy.

  // `dev` is served from dev.dart-pad.appspot.com
  // `prod` is served from prod.dart-pad.appspot.com and from dartpad.dartlang.org.

  final app = yaml.loadYaml(File('web/app.yaml').readAsStringSync()) as Map;

  final handlers = app['handlers'];
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
  Process.runSync('dart', ['format', 'lib/src/protos']);
}

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
