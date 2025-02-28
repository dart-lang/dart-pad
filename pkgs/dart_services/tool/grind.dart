// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// ignore_for_file: unreachable_from_main

import 'dart:async';
import 'dart:convert' show JsonEncoder;
import 'dart:io';

import 'package:dart_services/src/project_creator.dart';
import 'package:dart_services/src/project_templates.dart';
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

final List<String> compilationArtifacts = ['dart_sdk.js', 'flutter_web.js'];

final List<String> compilationArtifactsNew = [
  'dart_sdk_new.js',
  'flutter_web_new.js',
  'ddc_module_loader.js',
];

@Task(
  'validate that we have the correct compilation artifacts available in '
  'google storage',
)
void validateStorageArtifacts() async {
  final args = context.invocation.arguments;
  final sdk = Sdk.fromLocalFlutter();
  final version = sdk.dartVersion;
  final bucket = switch (args.hasOption('bucket')) {
    true => args.getOption('bucket'),
    false => 'nnbd_artifacts',
  };

  print(
    'validate-storage-artifacts version: ${sdk.dartVersion} bucket: $bucket',
  );

  final urlBase = 'https://storage.googleapis.com/$bucket/';
  for (final artifact
      in sdk.useNewDdcSdk ? compilationArtifactsNew : compilationArtifacts) {
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

/// Builds the two project templates:
///
/// * the Dart project template,
/// * the Flutter project template,
@Task('build the project templates')
void buildProjectTemplates() async {
  final templatesPath = path.join(Directory.current.path, 'project_templates');
  final templatesDirectory = Directory(templatesPath);
  if (await templatesDirectory.exists()) {
    log('Removing ${templatesDirectory.path}');
    await templatesDirectory.delete(recursive: true);
  }

  final sdk = Sdk.fromLocalFlutter();
  final projectCreator = ProjectCreator(
    sdk,
    templatesPath,
    dartLanguageVersion: sdk.dartVersion,
    dependenciesFile: _pubDependenciesFile(channel: sdk.channel),
    log: log,
  );
  await projectCreator.buildDartProjectTemplate();
  await projectCreator.buildFlutterProjectTemplate();
}

@Task('build the sdk compilation artifacts for upload to google storage')
@Depends(updatePubDependencies)
void buildStorageArtifacts() async {
  final sdk = Sdk.fromLocalFlutter();
  delete(getDir('artifacts'));
  final instructions = <String>[];

  // build and copy ddc_module_loader.js, dart_sdk.js, flutter_web.js, and
  // flutter_web.dill
  final temp = Directory.systemTemp.createTempSync('flutter_web_sample');

  try {
    instructions.add(
      await _buildStorageArtifacts(temp, sdk, channel: sdk.channel),
    );
  } finally {
    temp.deleteSync(recursive: true);
  }

  log('\nFrom the dart-services project root dir, run:');
  for (final instruction in instructions) {
    log(instruction);
  }
}

// Packages to include in flutter_web.js. These are implicitly imported by all
// flutter apps. Since DDC doesn't do tree-shaking these would be included in
// every compilation.
const _flutterPackages = {
  'flutter',
  'flutter_test',
  'url_launcher_web',
  'shared_preferences_web',
  'video_player_web',
  'shared_preferences_platform_interface',
  'video_player_platform_interface',
  'web',
};

Future<String> _buildStorageArtifacts(
  Directory dir,
  Sdk sdk, {
  required String channel,
}) async {
  final dependenciesFile = _pubDependenciesFile(channel: channel);
  final pubspec = createPubspec(
    includeFlutterWeb: true,
    dartLanguageVersion: sdk.dartVersion,
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

  await runFlutterPubGet(sdk, dir.path, log: log);

  // Working around Flutter 3.3's deprecation of generated_plugin_registrant.dart
  // Context: https://github.com/flutter/flutter/pull/106921

  final pluginRegistrant = File(
    path.join(dir.path, '.dart_tool', 'dartpad', 'web_plugin_registrant.dart'),
  );
  if (pluginRegistrant.existsSync()) {
    Directory(path.join(dir.path, 'lib')).createSync();
    pluginRegistrant.copySync(
      path.join(dir.path, 'lib', 'generated_plugin_registrant.dart'),
    );
  }

  final flutterLibraries = <String>[];
  final config = await findPackageConfig(dir);
  if (config == null) {
    throw FileSystemException('package config not found', dir.toString());
  }
  for (final package in config.packages) {
    if (_flutterPackages.contains(package.name)) {
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
  // <flutter-sdk>/bin/cache/flutter_web_sdk/kernel/ddc_outline.dill is
  // installed.
  await _run(
    sdk.flutterToolPath,
    arguments: ['precache', '--web'],
    workingDirectory: dir.path,
  );

  // Build the artifacts using DDC:
  // dart-sdk/bin/dartdevc -s kernel/ddc_outline.dill
  //     --modules=amd package:flutter/animation.dart ...
  final compilerPath = path.join(sdk.dartSdkPath, 'bin', 'dart');

  // Later versions of Flutter remove the "sound" suffix from files. If the
  // suffixed version does not exist, the unsuffixed version is the sound file.
  var dillPath = path.join(sdk.flutterWebSdkPath, 'ddc_outline_sound.dill');
  var sdkJsPath = path.join(
    sdk.flutterWebSdkPath,
    'amd-canvaskit-sound/dart_sdk.js',
  );
  if (!getFile(dillPath).existsSync()) {
    dillPath = path.join(sdk.flutterWebSdkPath, 'ddc_outline.dill');
    sdkJsPath = path.join(sdk.flutterWebSdkPath, 'amd-canvaskit/dart_sdk.js');
  }

  final arguments = <String>[
    path.join(sdk.dartSdkPath, 'bin', 'snapshots', 'dartdevc.dart.snapshot'),
    '-s',
    dillPath,
    '--modules=amd',
    '--source-map',
    '-o',
    'flutter_web.js',
    ...flutterLibraries,
  ];

  await _run(compilerPath, arguments: arguments, workingDirectory: dir.path);

  // Copy all to the project directory.
  final artifactsDir = getDir(path.join('artifacts'));
  artifactsDir.createSync(recursive: true);

  copy(getFile(sdkJsPath), artifactsDir);
  copy(getFile('$sdkJsPath.map'), artifactsDir);
  copy(joinFile(dir, ['flutter_web.js']), artifactsDir);
  copy(joinFile(dir, ['flutter_web.js.map']), artifactsDir);
  copy(joinFile(dir, ['flutter_web.dill']), artifactsDir);

  // We only expect these hot reload artifacts to work at version 3.8 and later.
  if (sdk.useNewDdcSdk) {
    // Later versions of Flutter remove the "sound" suffix from the file. If
    // the suffixed version does not exist, the unsuffixed version is the sound
    // file.
    var newSdkJsPath = path.join(
      sdk.flutterWebSdkPath,
      'ddcLibraryBundle-canvaskit-sound/dart_sdk.js',
    );
    if (!getFile(newSdkJsPath).existsSync()) {
      newSdkJsPath = path.join(
        sdk.flutterWebSdkPath,
        'ddcLibraryBundle-canvaskit/dart_sdk.js',
      );
    }
    final ddcModuleLoaderPath = path.join(
      sdk.dartSdkPath,
      'lib/dev_compiler/ddc/ddc_module_loader.js',
    );

    final argumentsNew = <String>[
      path.join(sdk.dartSdkPath, 'bin', 'snapshots', 'dartdevc.dart.snapshot'),
      '-s',
      dillPath,
      '--modules=ddc',
      '--canary',
      '--source-map',
      // The dill file will be the same between legacy and new compilation.
      '--no-summarize',
      '-o',
      'flutter_web_new.js',
      ...flutterLibraries,
    ];

    await _run(
      compilerPath,
      arguments: argumentsNew,
      workingDirectory: dir.path,
    );

    copy(getFile(ddcModuleLoaderPath), artifactsDir);
    copy(getFile(newSdkJsPath), artifactsDir);
    copy(getFile('$newSdkJsPath.map'), artifactsDir);
    joinFile(artifactsDir, [
      'dart_sdk.js',
    ]).copySync(path.join('artifacts', 'dart_sdk_new.js'));
    joinFile(artifactsDir, [
      'dart_sdk.js.map',
    ]).copySync(path.join('artifacts', 'dart_sdk_new.js.map'));

    copy(joinFile(dir, ['flutter_web_new.js']), artifactsDir);
    copy(joinFile(dir, ['flutter_web_new.js.map']), artifactsDir);
  }

  final args = context.invocation.arguments;
  final bucket = switch (args.hasOption('bucket')) {
    true => args.getOption('bucket'),
    false => 'nnbd_artifacts',
  };

  // Emit some good Google Storage upload instructions.
  final version = sdk.dartVersion;
  return '  gsutil -h "Cache-Control: public, max-age=604800, immutable" '
      'cp -z js ${artifactsDir.path}/*.js* '
      'gs://$bucket/$version/';
}

@Task('Update generated files and run all checks prior to deployment')
@Depends(buildProjectTemplates, validateStorageArtifacts)
void deploy() {
  log('Deploy via Google Cloud Console');
}

Future<void> _run(
  String executable, {
  List<String> arguments = const [],
  String? workingDirectory,
  Map<String, String> environment = const {},
}) async {
  final process = await runWithLogging(
    executable,
    arguments: arguments,
    workingDirectory: workingDirectory,
    environment: environment,
    log: log,
  );
  final exitCode = await process.exitCode;
  if (exitCode != 0) {
    fail('Unable to exec $executable, failed with code $exitCode');
  }
}

@Task('Update pubspec dependency versions')
void updatePubDependencies() async {
  final sdk = Sdk.fromLocalFlutter();
  await _updateDependenciesFile(channel: sdk.channel, sdk: sdk);
}

/// Updates the "dependencies file".
///
/// The new set of dependency packages, and their version numbers, is determined
/// by resolving versions of direct and indirect dependencies of a Flutter web
/// app in a scratch pub package.
///
/// See [_pubDependenciesFile] for the location of the dependencies files.
Future<void> _updateDependenciesFile({
  required String channel,
  required Sdk sdk,
}) async {
  final tempDir = Directory.systemTemp.createTempSync('pubspec-scratch');

  final pubspec = createPubspec(
    includeFlutterWeb: true,
    dartLanguageVersion: sdk.dartVersion,
    dependencies: {
      'lints': 'any',
      for (final package in supportedFlutterPackages) package: 'any',
      for (final package in supportedBasicDartPackages) package: 'any',
    },
  );
  joinFile(tempDir, ['pubspec.yaml']).writeAsStringSync(pubspec);
  await runFlutterPubGet(sdk, tempDir.path, log: log);
  final packageVersions = packageVersionsFromPubspecLock(tempDir.path);

  final deps = const JsonEncoder.withIndent('  ').convert(packageVersions);
  _pubDependenciesFile(channel: channel).writeAsStringSync('$deps\n');
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
