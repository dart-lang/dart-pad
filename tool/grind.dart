// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library services.grind;

import 'dart:async';
import 'dart:convert' show jsonDecode, JsonEncoder;
import 'dart:io';

import 'package:dart_services/src/project.dart';
import 'package:dart_services/src/pub.dart';
import 'package:dart_services/src/sdk.dart';
import 'package:grinder/grinder.dart';
import 'package:grinder/src/run_utils.dart' show mergeWorkingDirectory;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

Future<void> main(List<String> args) async {
  return grind(args);
}

@Task('Make sure SDKs are appropriately initialized')
@Depends(setupFlutterSdk)
void sdkInit() {}

@Task()
@Depends(buildProjectTemplates)
void analyze() async {
  await runWithLogging('dart', arguments: ['analyze']);
}

@Task()
@Depends(buildStorageArtifacts)
Future<dynamic> test() =>
    runWithLogging(Platform.executable, arguments: ['test']);

@DefaultTask()
@Depends(analyze, test)
void analyzeTest() {}

@Task()
@Depends(buildStorageArtifacts)
Future<void> serve() async {
  await runWithLogging(Platform.executable,
      arguments: ['bin/server_dev.dart', '--port', '8082']);
}

@Task()
@Depends(buildStorageArtifacts)
Future<void> serveNullSafety() async {
  await runWithLogging(Platform.executable,
      arguments: ['bin/server_dev.dart', '--port', '8084', '--null-safety']);
}

const _dartImageName = 'google/dart';
final _dockerVersionMatcher = RegExp('^FROM $_dartImageName:(.*)\$');
const _dockerFileNames = [
  'cloud_run.Dockerfile',
  'cloud_run_null_safety.Dockerfile'
];

@Task('Update the docker and SDK versions')
void updateDockerVersion() {
  final platformVersion = Platform.version.split(' ').first;
  for (final _dockerFileName in _dockerFileNames) {
    final dockerFile = File(_dockerFileName);
    final dockerImageLines = dockerFile.readAsLinesSync().map((String s) {
      if (s.contains(_dockerVersionMatcher)) {
        return 'FROM $_dartImageName:$platformVersion';
      }
      return s;
    }).toList();
    dockerImageLines.add('');

    dockerFile.writeAsStringSync(dockerImageLines.join('\n'));
  }
}

final List<String> compilationArtifacts = [
  'dart_sdk.js',
  'flutter_web.js',
];

@Task('validate that we have the correct compilation artifacts available in '
    'google storage')
@Depends(sdkInit)
void validateStorageArtifacts() async {
  final version = Sdk.create().versionFull;

  const nullUnsafeUrlBase =
      'https://storage.googleapis.com/compilation_artifacts/';
  const nullSafeUrlBase = 'https://storage.googleapis.com/nnbd_artifacts/';

  for (final urlBase in [nullUnsafeUrlBase, nullSafeUrlBase]) {
    for (final artifact in compilationArtifacts) {
      await _validateExists(Uri.parse('$urlBase$version/$artifact'));
    }
  }
}

Future<void> _validateExists(Uri url) async {
  log('checking $url...');

  final response = await http.head(url);
  if (response.statusCode != 200) {
    fail(
      'compilation artifact not found: $url '
      '(${response.statusCode} ${response.reasonPhrase})',
    );
  }
}

@Task('build the project templates')
@Depends(sdkInit, updatePubDependencies)
void buildProjectTemplates() async {
  final templatesPath =
      Directory(path.join(Directory.current.path, 'project_templates'));
  final exists = await templatesPath.exists();
  if (exists) {
    await templatesPath.delete(recursive: true);
  }

  for (final nullSafety in [true, false]) {
    final dartProjectPath = Directory(path.join(templatesPath.path,
        nullSafety ? 'null-safe' : 'null-unsafe', 'dart_project'));
    final dartProjectDir = await dartProjectPath.create(recursive: true);
    final dependencies = _parsePubDependenciesFile(nullSafety: nullSafety)
      ..removeWhere((name, _) => !supportedNonFlutterPackages.contains(name));
    joinFile(dartProjectDir, ['pubspec.yaml']).writeAsStringSync(createPubspec(
        includeFlutterWeb: false,
        nullSafety: nullSafety,
        dependencies: dependencies));
    await _runDartPubGet(dartProjectDir);
    joinFile(dartProjectDir, ['analysis_options.yaml']).writeAsStringSync('''
include: package:lints/recommended.yaml
linter:
  rules:
    avoid_print: false
''');

    final flutterProjectPath = Directory(path.join(templatesPath.path,
        nullSafety ? 'null-safe' : 'null-unsafe', 'flutter_project'));
    final flutterProjectDir = await flutterProjectPath.create(recursive: true);
    final flutterPubspec = createPubspec(
        includeFlutterWeb: true,
        nullSafety: nullSafety,
        dependencies: _parsePubDependenciesFile(nullSafety: nullSafety));
    joinFile(flutterProjectDir, ['pubspec.yaml'])
        .writeAsStringSync(flutterPubspec);
    await _runFlutterPubGet(flutterProjectDir);
    joinFile(flutterProjectDir, ['analysis_options.yaml']).writeAsStringSync('''
include: package:flutter_lints/flutter.yaml
linter:
  rules:
    avoid_print: false
    use_key_in_widget_constructors: false
''');
  }
}

Future<void> _runDartPubGet(Directory dir) async {
  log('running dart pub get (${dir.path})');

  await runWithLogging(
    path.join(Sdk.sdkPath, 'bin', 'dart'),
    arguments: ['pub', 'get'],
    workingDirectory: dir.path,
  );
}

Future<void> _runFlutterPubGet(Directory dir) async {
  log('running flutter pub get (${dir.path})');

  await runWithLogging(
    path.join(Sdk.flutterBinPath, 'flutter'),
    arguments: ['pub', 'get'],
    workingDirectory: dir.path,
  );
}

@Task('build the sdk compilation artifacts for upload to google storage')
@Depends(sdkInit, buildProjectTemplates)
void buildStorageArtifacts() async {
  delete(getDir('artifacts'));
  final instructions = <String>[];

  for (final nullSafe in [false, true]) {
    // build and copy dart_sdk.js, flutter_web.js, and flutter_web.dill
    final temp = Directory.systemTemp.createTempSync('flutter_web_sample');

    try {
      instructions.add(await _buildStorageArtifacts(temp, nullSafe));
    } finally {
      temp.deleteSync(recursive: true);
    }
  }
  log('\nFrom the dart-services project root dir, run:');
  for (final instruction in instructions) {
    log(instruction);
  }
}

Future<String> _buildStorageArtifacts(Directory dir, bool nullSafety) async {
  final pubspec = createPubspec(
      includeFlutterWeb: true,
      nullSafety: nullSafety,
      dependencies: _parsePubDependenciesFile(nullSafety: nullSafety));
  joinFile(dir, ['pubspec.yaml']).writeAsStringSync(pubspec);

  // run flutter pub get
  await runWithLogging(
    path.join(Sdk.flutterSdkPath, 'bin', 'flutter'),
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

  // Make sure flutter-sdk/bin/cache/flutter_web_sdk/flutter_web_sdk/kernel/flutter_ddc_sdk.dill
  // is installed.
  await runWithLogging(
    path.join(Sdk.flutterSdkPath, 'bin', 'flutter'),
    arguments: ['precache', '--web'],
    workingDirectory: dir.path,
  );

  // Build the artifacts using DDC:
  // dart-sdk/bin/dartdevc -s kernel/flutter_ddc_sdk.dill
  //     --modules=amd package:flutter/animation.dart ...
  final compilerPath = path.join(
      Sdk.flutterSdkPath, 'bin', 'cache', 'dart-sdk', 'bin', 'dartdevc');
  final dillPath = path.join(
    Sdk.flutterSdkPath,
    'bin',
    'cache',
    'flutter_web_sdk',
    'flutter_web_sdk',
    'kernel',
    nullSafety ? 'flutter_ddc_sdk_sound.dill' : 'flutter_ddc_sdk.dill',
  );

  final args = <String>[
    '-s',
    dillPath,
    if (nullSafety) ...[
      '--sound-null-safety',
      '--enable-experiment=non-nullable'
    ],
    '--modules=amd',
    '--source-map',
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
  final artifactsDir =
      getDir(path.join('artifacts', nullSafety ? 'null-safe' : 'null-unsafe'));
  artifactsDir.createSync(recursive: true);

  final sdkJsPath = path.join(
      Sdk.flutterSdkPath,
      nullSafety
          ? 'bin/cache/flutter_web_sdk/flutter_web_sdk/kernel/amd-canvaskit-html-sound/dart_sdk.js'
          : 'bin/cache/flutter_web_sdk/flutter_web_sdk/kernel/amd-canvaskit-html/dart_sdk.js');

  copy(getFile(sdkJsPath), artifactsDir);
  copy(getFile('$sdkJsPath.map'), artifactsDir);
  copy(joinFile(dir, ['flutter_web.js']), artifactsDir);
  copy(joinFile(dir, ['flutter_web.js.map']), artifactsDir);
  copy(joinFile(dir, ['flutter_web.dill']), artifactsDir);

  // Emit some good google storage upload instructions.
  final version = Sdk.create().versionFull;
  return ('  gsutil -h "Cache-Control: public, max-age=604800, immutable" cp -z js ${artifactsDir.path}/*.js*'
      ' gs://${nullSafety ? 'nnbd_artifacts' : 'compilation_artifacts'}/$version/');
}

@Task('Reinitialize the Flutter submodule.')
void setupFlutterSdk() async {
  final info = DownloadingSdkManager.getSdkConfigInfo();
  print('Flutter SDK configuration: $info\n');

  // Download the SDK into ./futter-sdk/
  await DownloadingSdkManager().createFromConfigFile();

  // Set up the  Flutter SDK the way dart-services needs it.

  final flutterBinFlutter = path.join(Sdk.flutterSdkPath, 'bin', 'flutter');
  await runWithLogging(
    flutterBinFlutter,
    arguments: ['doctor'],
  );

  await runWithLogging(
    flutterBinFlutter,
    arguments: ['config', '--enable-web'],
  );

  await runWithLogging(
    flutterBinFlutter,
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
@Depends(sdkInit, updateDockerVersion, generateProtos, updatePubDependencies,
    analyze, test, validateStorageArtifacts)
void deploy() {
  log('Deploy via Google Cloud Console');
}

@Task()
@Depends(generateProtos, analyze, fuzz, buildStorageArtifacts)
void buildbot() {}

@Task('Generate Protobuf classes')
void generateProtos() async {
  await runWithLogging(
    'protoc',
    arguments: ['--dart_out=lib/src', 'protos/dart_services.proto'],
    onErrorMessage:
        'Error running "protoc"; make sure the Protocol Buffer compiler is '
        'installed (see README.md)',
  );

  // reformat generated classes so travis dart format test doesn't fail
  await runWithLogging(
    'dart',
    arguments: ['format', '--fix', 'lib/src/protos'],
  );

  // And reformat again, for $REASONS
  await runWithLogging(
    'dart',
    arguments: ['format', '--fix', 'lib/src/protos'],
  );

  // generate common_server_proto.g.dart
  Pub.run('build_runner', arguments: ['build', '--delete-conflicting-outputs']);
}

Future<void> runWithLogging(String executable,
    {List<String> arguments = const [],
    RunOptions? runOptions,
    String? workingDirectory,
    String? onErrorMessage}) async {
  runOptions = mergeWorkingDirectory(workingDirectory, runOptions);
  log("$executable ${arguments.join(' ')}");

  Process proc;
  try {
    proc = await Process.start(executable, arguments,
        workingDirectory: runOptions.workingDirectory,
        environment: runOptions.environment,
        includeParentEnvironment: runOptions.includeParentEnvironment,
        runInShell: runOptions.runInShell);
  } catch (e) {
    if (onErrorMessage != null) {
      print(onErrorMessage);
    }
    rethrow;
  }

  proc.stdout.listen((out) => log(runOptions!.stdoutEncoding.decode(out)));
  proc.stderr.listen((err) => log(runOptions!.stdoutEncoding.decode(err)));
  final exitCode = await proc.exitCode;

  if (exitCode != 0) {
    fail('Unable to exec $executable, failed with code $exitCode');
  }
}

const String _samplePackageName = 'dartpad_sample';

String createPubspec({
  required bool includeFlutterWeb,
  required bool nullSafety,
  Map<String, String> dependencies = const {},
}) {
  var content = '''
name: $_samplePackageName
environment:
  sdk: '>=${nullSafety ? '2.13.0' : '2.10.0'} <3.0.0'
dependencies:
''';

  if (includeFlutterWeb) {
    content += '''
  flutter:
    sdk: flutter
  flutter_test:
    sdk: flutter
''';
  }
  dependencies.forEach((name, version) {
    content += '  $name: $version\n';
  });

  return content;
}

@Task('Update pubspec dependency versions')
@Depends(sdkInit)
void updatePubDependencies() async {
  for (final nullSafety in [false, true]) {
    updateDependenciesFile(nullSafety: nullSafety);
  }
}

/// Updates the "dependencies file".
///
/// The new set of dependency packages, and their version numbers, is determined
/// by resolving versions of direct and indirect dependencies of a Flutter web
/// app with Firebase plugins in a scratch pub package.
///
/// See [_pubDependenciesFile] for the location of the dependencies files.
void updateDependenciesFile({
  required bool nullSafety,
}) async {
  final tempDir = Directory.systemTemp.createTempSync('pubspec-scratch');
  final pubspec = createPubspec(
    includeFlutterWeb: true,
    nullSafety: nullSafety,
    dependencies: {
      // pkg:lints and pkg:flutter_lints
      'lints': 'any',
      'flutter_lints': 'any',
      // These are all of the web-enabled plugins found at
      // https://firebase.flutter.dev/.
      'cloud_functions': 'any',
      'cloud_firestore': 'any',
      'firebase_analytics': 'any',
      'firebase_auth': 'any',
      'firebase_core': 'any',
      'firebase_messaging': 'any',
      'firebase_storage': 'any',
      'pedantic': 'any',
    },
  );
  joinFile(tempDir, ['pubspec.yaml']).writeAsStringSync(pubspec);
  await _runFlutterPubGet(tempDir);
  final packageVersions = packageVersionsFromPubspecLock(tempDir);

  _pubDependenciesFile(nullSafety: nullSafety)
      .writeAsStringSync(_jsonEncoder.convert(packageVersions));
}

/// An encoder which indents nested elements by two spaces.
const JsonEncoder _jsonEncoder = JsonEncoder.withIndent('  ');

/// Returns the File containing the pub dependencies and their version numbers.
///
/// The null safe file is at `tool/pub_dependencies_null-safe.json`. The null
/// unsafe file is at `tool/pub_dependencies_null-unsafe.json`.
File _pubDependenciesFile({required bool nullSafety}) {
  final versionsFileName =
      'pub_dependencies_${nullSafety ? 'null-safe' : 'null-unsafe'}.json';
  return File(path.join(Directory.current.path, 'tool', versionsFileName));
}

/// Parses [_pubDependenciesFile] as a JSON Map of Strings.
Map<String, String> _parsePubDependenciesFile({required bool nullSafety}) {
  final packageVersions = jsonDecode(
      _pubDependenciesFile(nullSafety: nullSafety).readAsStringSync()) as Map;
  return packageVersions.cast<String, String>();
}
