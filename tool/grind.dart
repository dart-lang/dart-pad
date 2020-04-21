// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library services.grind;

import 'dart:async';
import 'dart:io';

import 'package:dart_services/src/flutter_web.dart';
import 'package:dart_services/src/sdk_manager.dart';
import 'package:grinder/grinder.dart';
import 'package:grinder/grinder_files.dart';
import 'package:grinder/src/run_utils.dart' show mergeWorkingDirectory;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

Future<void> main(List<String> args) async {
  await SdkManager.sdk.init();
  await SdkManager.flutterSdk.init();
  return grind(args);
}

@Task()
void analyze() {
  Pub.run('tuneup', arguments: ['check']);
}

@Task()
@Depends(buildStorageArtifacts)
Future test() => TestRunner().testAsync();

@DefaultTask()
@Depends(analyze, test)
void analyzeTest() => null;

@Task()
@Depends(buildStorageArtifacts)
Future<void> serve() async {
  await runWithLogging(Platform.executable,
      arguments: ['bin/server_dev.dart', '--port', '8082']);
}

final _dockerVersionMatcher = RegExp(r'^FROM google/dart-runtime:(.*)$');

@Task('Update the docker and SDK versions')
void updateDockerVersion() {
  final platformVersion = Platform.version.split(' ').first;
  final dockerImageLines = File('Dockerfile').readAsLinesSync().map((String s) {
    if (s.contains(_dockerVersionMatcher)) {
      return 'FROM google/dart-runtime:$platformVersion';
    }
    return s;
  }).toList();
  dockerImageLines.add('');

  File('Dockerfile').writeAsStringSync(dockerImageLines.join('\n'));
}

final List<String> compilationArtifacts = [
  'dart_sdk.js',
  'flutter_web.js',
];

@Task('validate that we have the correct compilation artifacts available in '
    'google storage')
void validateStorageArtifacts() async {
  final version = SdkManager.flutterSdk.versionFull;

  const urlBase = 'https://storage.googleapis.com/compilation_artifacts/';

  for (final artifact in compilationArtifacts) {
    await _validateExists('$urlBase$version/$artifact');
  }
}

Future _validateExists(String url) async {
  log('checking $url...');

  final response = await http.head(url);
  if (response.statusCode != 200) {
    fail(
      'compilation artifact not found: $url '
      '(${response.statusCode} ${response.reasonPhrase})',
    );
  }
}

@Task('build the sdk compilation artifacts for upload to google storage')
void buildStorageArtifacts() async {
  // build and copy dart_sdk.js, flutter_web.js, and flutter_web.dill
  final temp = Directory.systemTemp.createTempSync('flutter_web_sample');

  try {
    await _buildStorageArtifacts(temp);
  } finally {
    temp.deleteSync(recursive: true);
  }
}

void _buildStorageArtifacts(Directory dir) async {
  final flutterSdkPath =
      Directory(path.join(Directory.current.path, 'flutter'));
  final pubspec = FlutterWebManager.createPubspec(true);
  joinFile(dir, ['pubspec.yaml']).writeAsStringSync(pubspec);

  // run flutter pub get
  await runWithLogging(
    path.join(flutterSdkPath.path, 'bin/flutter'),
    arguments: ['pub', 'get'],
    workingDirectory: dir.path,
  );

  // locate the artifacts
  final flutterPackages = ['flutter', 'flutter_test'];

  final flutterLibraries = <String>[];
  final packageLines = joinFile(dir, ['.packages']).readAsLinesSync();
  for (var line in packageLines) {
    line = line.trim();
    if (line.startsWith('#') || line.isEmpty) {
      continue;
    }
    final index = line.indexOf(':');
    if (index == -1) {
      continue;
    }
    final packageName = line.substring(0, index);
    final url = line.substring(index + 1);
    if (flutterPackages.contains(packageName)) {
      // This is a package we're interested in - add all the public libraries to
      // the list.
      final libPath = Uri.parse(url).toFilePath();
      for (final entity in getDir(libPath).listSync()) {
        if (entity is File && entity.path.endsWith('.dart')) {
          flutterLibraries.add('package:$packageName/${fileName(entity)}');
        }
      }
    }
  }

  // Make sure flutter/bin/cache/flutter_web_sdk/flutter_web_sdk/kernel/flutter_ddc_sdk.dill
  // is installed.
  await runWithLogging(
    path.join(flutterSdkPath.path, 'bin/flutter'),
    arguments: ['precache', '--web'],
    workingDirectory: dir.path,
  );

  // Build the artifacts using DDC:
  // dart-sdk/bin/dartdevc -s kernel/flutter_ddc_sdk.dill
  //     --modules=amd package:flutter_web/animation.dart ...
  final compilerPath =
      path.join(flutterSdkPath.path, 'bin/cache/dart-sdk/bin/dartdevc');
  final dillPath = path.join(flutterSdkPath.path,
      'bin/cache/flutter_web_sdk/flutter_web_sdk/kernel/flutter_ddc_sdk.dill');

  final args = <String>[
    '-s',
    dillPath,
    '--modules=amd',
    '-o',
    'flutter_web.js',
    ...flutterLibraries
  ];

  await runWithLogging(
    compilerPath,
    arguments: args,
    workingDirectory: dir.path,
  );

  // Copy both to the project directory.
  final artifactsDir = getDir('artifacts');
  await artifactsDir.create();

  final sdkJsPath = path.join(flutterSdkPath.path,
      'bin/cache/flutter_web_sdk/flutter_web_sdk/kernel/amd/dart_sdk.js');

  copy(getFile(sdkJsPath), artifactsDir);
  copy(joinFile(dir, ['flutter_web.js']), artifactsDir);
  copy(joinFile(dir, ['flutter_web.dill']), artifactsDir);

  // Emit some good google storage upload instructions.
  final version = SdkManager.flutterSdk.versionFull;
  log('\nFrom the dart-services project root dir, run:');
  log('  gsutil -h "Cache-Control:public, max-age=86400" cp -z js '
      'artifacts/*.js gs://compilation_artifacts/$version/');
}

@Task('Delete, re-download, and reinitialize the Flutter submodule.')
void setupFlutterSubmodule() async {
  final flutterDir = Directory('flutter');

  // Remove all files currently in the submodule. This is done to clear any
  // internal state the Flutter/Dart SDKs may have created on their own.
  flutterDir.listSync().forEach((e) => e.deleteSync(recursive: true));

  // Pull clean files into the submodule, based on whatever commit it's set to.
  await runWithLogging(
    'git',
    arguments: ['submodule', 'update'],
  );

  // Set up the submodule's copy of the Flutter SDK the way dart-services needs
  // it.
  await runWithLogging(
    path.join(flutterDir.path, 'bin/flutter'),
    arguments: ['doctor'],
  );

  await runWithLogging(
    path.join(flutterDir.path, 'bin/flutter'),
    arguments: ['config', '--enable-web'],
  );

  await runWithLogging(
    path.join(flutterDir.path, 'bin/flutter'),
    arguments: [
      'precache',
      '--web',
      '--no-android',
      '--no-ios',
      '--no-linux',
      '--no-windows',
      '--no-macos',
      '--no-fuchsia',
    ],
  );
}

@Task()
void fuzz() {
  log('warning: fuzz testing is a noop, see #301');
}

@Task('Update generated files and run all checks prior to deployment')
@Depends(setupFlutterSubmodule, updateDockerVersion, generateProtos, analyze,
    test, fuzz, validateStorageArtifacts)
void deploy() {
  log('Run: gcloud app deploy --project=dart-services --no-promote');
}

@Task()
@Depends(generateProtos, analyze, fuzz, buildStorageArtifacts)
void buildbot() => null;

@Task('Generate Protobuf classes')
void generateProtos() async {
  await runWithLogging(
    'protoc',
    arguments: ['--dart_out=lib/src', 'protos/dart_services.proto'],
  );

  // reformat generated classes so travis dartfmt test doesn't fail
  await runWithLogging(
    'dartfmt',
    arguments: ['--fix', '-w', 'lib/src/protos'],
  );

  // generate common_server_proto.g.dart
  Pub.run('build_runner', arguments: ['build', '--delete-conflicting-outputs']);
}

class RunWithLoggingException implements Exception {
  const RunWithLoggingException(this.executable, this.exitCode);
  final String executable;
  final int exitCode;
}

Future<void> runWithLogging(String executable,
    {List<String> arguments = const [],
    RunOptions runOptions,
    String workingDirectory}) async {
  runOptions = mergeWorkingDirectory(workingDirectory, runOptions);
  log("${executable} ${arguments.join(' ')}");
  runOptions ??= RunOptions();

  final proc = await Process.start(executable, arguments,
      workingDirectory: runOptions.workingDirectory,
      environment: runOptions.environment,
      includeParentEnvironment: runOptions.includeParentEnvironment,
      runInShell: runOptions.runInShell);

  proc.stdout.listen((out) => log(runOptions.stdoutEncoding.decode(out)));
  proc.stderr.listen((err) => log(runOptions.stdoutEncoding.decode(err)));
  final exitCode = await proc.exitCode;

  if (exitCode != 0) {
    throw RunWithLoggingException(executable, exitCode);
  }
}
