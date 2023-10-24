// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// ignore_for_file: unreachable_from_main

import 'dart:async';
import 'dart:convert' show JsonEncoder;
import 'dart:io';

import 'package:dart_services/src/project.dart';
import 'package:dart_services/src/project_creator.dart';
import 'package:dart_services/src/pub.dart';
import 'package:dart_services/src/sdk.dart';
import 'package:dart_services/src/utils.dart';
import 'package:grinder/grinder.dart';
import 'package:http/http.dart' as http;
import 'package:package_config/package_config.dart';
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
  await _run('dart', arguments: ['analyze']);
}

@Task()
@Depends(buildStorageArtifacts)
Future<void> test() => _run(Platform.executable, arguments: ['test']);

@DefaultTask()
@Depends(analyze, test)
void analyzeTest() {}

@Task()
@Depends(buildStorageArtifacts)
Future<void> serve() async {
  await _run(Platform.executable, arguments: [
    path.join('bin', 'server.dart'),
    '--channel',
    _channel,
    '--port',
    '8080',
  ]);
}

const _dartImageName = 'dart';
final _dockerVersionMatcher = RegExp('^FROM $_dartImageName:(.*)\$');
const _dockerFileNames = [
  'cloud_run_beta.Dockerfile',
  'cloud_run_main.Dockerfile',
  'cloud_run_stable.Dockerfile',
];

/// Returns the Flutter channel provided in environment variables.
final String _channel = () {
  final channel = Platform.environment['FLUTTER_CHANNEL'];
  if (channel == null) {
    throw StateError('Must provide FLUTTER_CHANNEL');
  }
  return channel;
}();

/// Returns the appropriate SDK for the given Flutter channel.
///
/// The Flutter SDK directory must be already created by [sdkInit].
Sdk _getSdk() => Sdk.create(_channel);

@Task('Update the docker and SDK versions')
void updateDockerVersion() {
  final platformVersion = Platform.version.split(' ').first;
  for (final dockerFileName in _dockerFileNames) {
    final dockerFile = File(dockerFileName);
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
  final sdk = _getSdk();
  print('validate-storage-artifacts version: ${sdk.version}');
  final version = sdk.versionFull;

  const urlBase = 'https://storage.googleapis.com/nnbd_artifacts/';

  for (final artifact in compilationArtifacts) {
    await _validateExists(Uri.parse('$urlBase$version/$artifact'));
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

/// Builds the three project templates:
///
/// * the Dart project template,
/// * the Flutter project template,
/// * the Firebase project template.
@Task('build the project templates')
@Depends(sdkInit)
void buildProjectTemplates() async {
  final templatesPath = path.join(Directory.current.path, 'project_templates');
  final templatesDirectory = Directory(templatesPath);
  if (await templatesDirectory.exists()) {
    log('Removing ${templatesDirectory.path}');
    await templatesDirectory.delete(recursive: true);
  }

  final sdk = _getSdk();
  final projectCreator = ProjectCreator(
    sdk,
    templatesPath,
    dartLanguageVersion: readDartLanguageVersion(_channel),
    dependenciesFile: _pubDependenciesFile(channel: _channel),
    log: log,
  );
  await projectCreator.buildDartProjectTemplate();
  await projectCreator.buildFlutterProjectTemplate(
      firebaseStyle: FirebaseStyle.none);
  await projectCreator.buildFlutterProjectTemplate(
      firebaseStyle: FirebaseStyle.flutterFire);
}

@Task('build the sdk compilation artifacts for upload to google storage')
@Depends(sdkInit, updatePubDependencies)
void buildStorageArtifacts() async {
  final sdk = _getSdk();
  delete(getDir('artifacts'));
  final instructions = <String>[];

  // build and copy dart_sdk.js, flutter_web.js, and flutter_web.dill
  final temp = Directory.systemTemp.createTempSync('flutter_web_sample');

  try {
    instructions
        .add(await _buildStorageArtifacts(temp, sdk, channel: _channel));
  } finally {
    temp.deleteSync(recursive: true);
  }

  log('\nFrom the dart-services project root dir, run:');
  for (final instruction in instructions) {
    log(instruction);
  }
}

Future<String> _buildStorageArtifacts(Directory dir, Sdk sdk,
    {required String channel}) async {
  final dependenciesFile = _pubDependenciesFile(channel: channel);
  final pubspec = createPubspec(
    includeFlutterWeb: true,
    dartLanguageVersion: readDartLanguageVersion(_channel),
    dependencies: parsePubDependenciesFile(dependenciesFile: dependenciesFile),
  );
  joinFile(dir, ['pubspec.yaml']).writeAsStringSync(pubspec);

  // Make sure the tooling knows this is a Flutter Web project
  final indexHtmlFile = File(path.join(dir.path, 'web', 'index.html'))
    ..parent.createSync();
  indexHtmlFile.writeAsStringSync('''
<!DOCTYPE html>
<html>
<head>
  <base href="/">

  <meta charset="UTF-8">
  <meta content="IE=Edge" http-equiv="X-UA-Compatible">

  <script src="main.dart.js" defer></script>
</head>

<body>
</body>
</html>
''');

  await runFlutterPackagesGet(sdk.flutterToolPath, dir.path, log: log);

  // Working around Flutter 3.3's deprecation of generated_plugin_registrant.dart
  // Context: https://github.com/flutter/flutter/pull/106921

  final pluginRegistrant = File(path.join(
      dir.path, '.dart_tool', 'dartpad', 'web_plugin_registrant.dart'));
  if (pluginRegistrant.existsSync()) {
    Directory(path.join(dir.path, 'lib')).createSync();
    pluginRegistrant.copySync(
        path.join(dir.path, 'lib', 'generated_plugin_registrant.dart'));
  }

  // locate the artifacts
  final flutterPackages = ['flutter', 'flutter_test'];

  final flutterLibraries = <String>[];
  final config = await findPackageConfig(dir);
  if (config == null) {
    throw FileSystemException('package config not found', dir.toString());
  }
  for (final package in config.packages) {
    if (flutterPackages.contains(package.name)) {
      // This is a package we're interested in - add all the public libraries to
      // the list.
      final libPath = package.packageUriRoot.toFilePath();
      for (final entity in getDir(libPath).listSync()) {
        if (entity is File && entity.path.endsWith('.dart')) {
          flutterLibraries.add('package:${package.name}/${fileName(entity)}');
        }
      }
    }
  }

  // Make sure
  // flutter-sdks/<channel>/bin/cache/flutter_web_sdk/kernel/flutter_ddc_sdk.dill
  // is installed.
  await _run(
    sdk.flutterToolPath,
    arguments: ['precache', '--web'],
    workingDirectory: dir.path,
  );

  // Build the artifacts using DDC:
  // dart-sdk/bin/dartdevc -s kernel/flutter_ddc_sdk.dill
  //     --modules=amd package:flutter/animation.dart ...
  final compilerPath = path.join(sdk.dartSdkPath, 'bin', 'dart');
  final dillPath = path.join(
    sdk.flutterWebSdkPath,
    'flutter_ddc_sdk_sound.dill',
  );

  final args = <String>[
    path.join(sdk.dartSdkPath, 'bin', 'snapshots', 'dartdevc.dart.snapshot'),
    '-s',
    dillPath,
    '--modules=amd',
    '--source-map',
    '-o',
    'flutter_web.js',
    ...flutterLibraries
  ];

  await _run(
    compilerPath,
    arguments: args,
    workingDirectory: dir.path,
  );

  // Copy both to the project directory.
  final artifactsDir = getDir(path.join('artifacts'));
  artifactsDir.createSync(recursive: true);

  final sdkJsPath =
      path.join(sdk.flutterWebSdkPath, 'amd-canvaskit-html-sound/dart_sdk.js');

  copy(getFile(sdkJsPath), artifactsDir);
  copy(getFile('$sdkJsPath.map'), artifactsDir);
  copy(joinFile(dir, ['flutter_web.js']), artifactsDir);
  copy(joinFile(dir, ['flutter_web.js.map']), artifactsDir);
  copy(joinFile(dir, ['flutter_web.dill']), artifactsDir);

  // Emit some good Google Storage upload instructions.
  final version = sdk.versionFull;
  return '  gsutil -h "Cache-Control: public, max-age=604800, immutable" '
      'cp -z js ${artifactsDir.path}/*.js* '
      'gs://nnbd_artifacts/$version/';
}

@Task('Reinitialize the Flutter submodule.')
void setupFlutterSdk() async {
  print('setup-flutter-sdk channel: $_channel');

  // Download the SDK into ./flutter-sdks/
  final sdkManager = DownloadingSdkManager(_channel);
  print('Flutter version: ${sdkManager.flutterVersion}');
  final flutterSdkPath = await sdkManager.createFromConfigFile();

  // Set up the Flutter SDK the way dart-services needs it.
  final flutterBinFlutter = path.join(flutterSdkPath, 'bin', 'flutter');
  await _run(
    flutterBinFlutter,
    arguments: ['doctor'],
  );

  await _run(
    flutterBinFlutter,
    arguments: ['config', '--enable-web'],
  );

  await _run(
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

@Task('Update generated files and run all checks prior to deployment')
@Depends(sdkInit, updateDockerVersion, generateProtos, analyze, test,
    validateStorageArtifacts)
void deploy() {
  log('Deploy via Google Cloud Console');
}

@Task()
@Depends(analyze, buildStorageArtifacts)
void buildbot() {}

@Task('Generate Protobuf classes')
void generateProtos() async {
  try {
    await _run(
      'protoc',
      arguments: ['--dart_out=lib/src', 'protos/dart_services.proto'],
    );
  } catch (e) {
    print('Error running "protoc"; make sure the Protocol Buffer compiler is '
        'installed (see README.md)');
  }

  // reformat generated classes so CI checks don't fail
  await _run(
    'dart',
    arguments: ['format', '--fix', 'lib/src/protos'],
  );

  // And reformat again, for $REASONS
  await _run(
    'dart',
    arguments: ['format', '--fix', 'lib/src/protos'],
  );

  // TODO: We'd like to remove this copy operation; that will require work in
  // the cloud build configuration.
  copy(getDir('../dartpad_shared/lib'), getDir('lib/src/shared'));
}

Future<void> _run(
  String executable, {
  List<String> arguments = const [],
  String? workingDirectory,
  Map<String, String> environment = const {},
}) async {
  final process = await runWithLogging(executable,
      arguments: arguments,
      workingDirectory: workingDirectory,
      environment: environment,
      log: log);
  final exitCode = await process.exitCode;
  if (exitCode != 0) {
    fail('Unable to exec $executable, failed with code $exitCode');
  }
}

@Task('Update pubspec dependency versions')
@Depends(sdkInit, buildProjectTemplates)
void updatePubDependencies() async {
  final sdk = _getSdk();
  await _updateDependenciesFile(
      flutterToolPath: sdk.flutterToolPath, channel: _channel, sdk: sdk);
}

/// Updates the "dependencies file".
///
/// The new set of dependency packages, and their version numbers, is determined
/// by resolving versions of direct and indirect dependencies of a Flutter web
/// app with Firebase plugins in a scratch pub package.
///
/// See [_pubDependenciesFile] for the location of the dependencies files.
Future<void> _updateDependenciesFile({
  required String flutterToolPath,
  required String channel,
  required Sdk sdk,
}) async {
  final tempDir = Directory.systemTemp.createTempSync('pubspec-scratch');

  final dependencies = <String, String>{
    'lints': 'any',
    'flutter_lints': 'any',
    for (final package in firebasePackages) package: 'any',
    for (final package in supportedFlutterPackages()) package: 'any',
    for (final package in supportedBasicDartPackages()) package: 'any',
  };

  // Overwrite with important constraints.
  for (final entry in overrideVersionConstraints().entries) {
    if (dependencies.containsKey(entry.key)) {
      dependencies[entry.key] = entry.value;
    }
  }

  final pubspec = createPubspec(
    includeFlutterWeb: true,
    dartLanguageVersion: readDartLanguageVersion(_channel),
    dependencies: dependencies,
  );
  joinFile(tempDir, ['pubspec.yaml']).writeAsStringSync(pubspec);
  await runFlutterPackagesGet(flutterToolPath, tempDir.path, log: log);
  final packageVersions = packageVersionsFromPubspecLock(tempDir.path);

  _pubDependenciesFile(channel: channel).writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(packageVersions),
  );
}

/// Returns the File containing the pub dependencies and their version numbers.
///
/// The file is at `tool/dependencies/pub_dependencies_{channel}.json`, for
/// the Flutter channels: stable, beta, main.
File _pubDependenciesFile({required String channel}) {
  return File(
    path.join(
      Directory.current.path,
      'tool',
      'dependencies',
      'pub_dependencies_$channel.json',
    ),
  );
}
