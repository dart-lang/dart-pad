// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library services.grind;

import 'dart:async';
import 'dart:io';

import 'package:dart_services/src/flutter_web.dart';
import 'package:grinder/grinder.dart';
import 'package:grinder/grinder_files.dart';
import 'package:http/http.dart' as http;

Future main(List<String> args) => grind(args);

@Task()
void analyze() {
  Pub.run('tuneup', arguments: ['check']);
}

@Task()
void init() => Dart.run('bin/update_sdk.dart');

@Task()
@Depends(init)
Future test() => TestRunner().testAsync();

@DefaultTask()
@Depends(analyze, test)
void analyzeTest() => null;

@Task()
@Depends(init)
void serve() {
  // You can run the `grind serve` command, or just run
  // `dart bin/server_dev.dart --port 8002` locally.

  Process.runSync(
      Platform.executable, ['bin/server_dev.dart', '--port', '8082']);
}

final _dockerVersionMatcher = RegExp(r'^FROM google/dart-runtime:(.*)$');
final _dartSdkVersionMatcher = RegExp(r'(^\d+[.]\d+[.]\d+.*)');

@Task('Update the docker and SDK versions')
void updateDockerVersion() {
  String platformVersion = Platform.version.split(' ').first;
  List<String> dockerImageLines =
      File('Dockerfile').readAsLinesSync().map((String s) {
    if (s.contains(_dockerVersionMatcher)) {
      return 'FROM google/dart-runtime:$platformVersion';
    }
    return s;
  }).toList();
  dockerImageLines.add('');

  File('Dockerfile').writeAsStringSync(dockerImageLines.join('\n'));

  List<String> dartSdkVersionLines =
      File('dart-sdk.version').readAsLinesSync().map((String s) {
    if (s.contains(_dartSdkVersionMatcher)) {
      return platformVersion;
    }
    return s;
  }).toList();
  dartSdkVersionLines.add('');

  File('dart-sdk.version').writeAsStringSync(dartSdkVersionLines.join('\n'));
}

final List<String> compilationArtifacts = [
  'dart_sdk.js',
  'flutter_web.js',
  'flutter_web.sum',
];

@Task('validate that we have the correct compilation artifacts available in '
    'google storage')
void validateStorageArtifacts() async {
  String version = File('dart-sdk.version').readAsStringSync().trim();

  const String urlBase =
      'https://storage.googleapis.com/compilation_artifacts/';

  for (String artifact in compilationArtifacts) {
    await _validateExists('$urlBase$version/$artifact');
  }
}

Future _validateExists(String url) async {
  log('checking $url...');

  http.Response response = await http.head(url);
  if (response.statusCode != 200) {
    fail(
      'compilation artifact not found: $url '
      '(${response.statusCode} ${response.reasonPhrase})',
    );
  }
}

@Task('build the sdk compilation artifacts for upload to google storage')
@Depends(init)
void buildStorageArtifacts() {
  // build and copy dart_sdk.js, flutter_web.js, and flutter_web.sum
  final Directory temp =
      Directory.systemTemp.createTempSync('flutter_web_sample');

  try {
    _buildStorageArtifacts(temp);
  } finally {
    temp.deleteSync(recursive: true);
  }
}

void _buildStorageArtifacts(Directory dir) {
  String pubspec = FlutterWebManager.createPubspec(true);
  joinFile(dir, ['pubspec.yaml']).writeAsStringSync(pubspec);

  // run pub get
  Pub.get(workingDirectory: dir.path);

  // locate the artifacts
  final List<String> flutterPackages = [
    'flutter_web',
    'flutter_web_ui',
    'flutter_web_test',
  ];

  List<String> flutterLibraries = [];
  List<String> packageLines = joinFile(dir, ['.packages']).readAsLinesSync();
  for (String line in packageLines) {
    line = line.trim();
    if (line.startsWith('#') || line.isEmpty) {
      continue;
    }
    int index = line.indexOf(':');
    if (index == -1) {
      continue;
    }
    String packageName = line.substring(0, index);
    String url = line.substring(index + 1);
    if (flutterPackages.contains(packageName)) {
      // This is a package we're interested in - add all the public libraries to
      // the list.
      String libPath = Uri.parse(url).toFilePath();
      for (FileSystemEntity entity in getDir(libPath).listSync()) {
        if (entity is File && entity.path.endsWith('.dart')) {
          flutterLibraries.add('package:$packageName/${fileName(entity)}');
        }
      }
    }
  }

  // build the artifacts using DDC
  // dartdevc -o flutter_web.js package:flutter_web/animation.dart ...
  run(
    getFile('dart-sdk/bin/dartdevc').absolute.path,
    arguments: [
      '--modules=amd',
      '-o',
      'flutter_web.js',
    ]..addAll(flutterLibraries),
    workingDirectory: dir.path,
  );

  // copy them to the project dir
  Directory artifactsDir = getDir('artifacts');
  artifactsDir.create();

  copy(getFile('dart-sdk/lib/dev_compiler/amd/dart_sdk.js'), artifactsDir);
  copy(joinFile(dir, ['flutter_web.js']), artifactsDir);
  copy(joinFile(dir, ['flutter_web.sum']), artifactsDir);

  // emit some good google storage upload instructions
  final String version = File('dart-sdk.version').readAsStringSync().trim();
  log('\nFrom the dart-services project root dir, run:');
  log('  gsutil -h "Cache-Control:public, max-age=86400" cp -z js '
      'artifacts/*.js gs://compilation_artifacts/$version/');
  log('  gsutil -h "Cache-Control:public, max-age=86400" cp -z sum '
      'artifacts/*.sum gs://compilation_artifacts/$version/');
}

@Task()
@Depends(init)
void fuzz() {
  log('warning: fuzz testing is a noop, see #301');
}

@Task('Update discovery files and run all checks prior to deployment')
@Depends(updateDockerVersion, init, discovery, analyze, test, fuzz,
    validateStorageArtifacts)
void deploy() {
  log('Run: gcloud app deploy --project=dart-services --no-promote');
}

@Task()
@Depends(init, discovery, analyze, fuzz)
void buildbot() => null;

@Task('Generate the discovery doc and Dart library from the annotated API')
void discovery() {
  ProcessResult result = Process.runSync(
      Platform.executable, ['bin/server_dev.dart', '--discovery']);

  if (result.exitCode != 0) {
    throw 'Error generating the discovery document\n${result.stderr}';
  }

  File discoveryFile = File('doc/generated/dartservices.json');
  discoveryFile.parent.createSync();
  log('writing ${discoveryFile.path}');
  discoveryFile.writeAsStringSync('${result.stdout.trim()}\n');

  ProcessResult resultDb = Process.runSync(
      Platform.executable, ['bin/server_dev.dart', '--discovery', '--relay']);

  if (resultDb.exitCode != 0) {
    throw 'Error generating the discovery document\n${result.stderr}';
  }

  File discoveryDbFile = File('doc/generated/_dartpadsupportservices.json');
  discoveryDbFile.parent.createSync();
  log('writing ${discoveryDbFile.path}');
  discoveryDbFile.writeAsStringSync('${resultDb.stdout.trim()}\n');

  // Generate the Dart library from the json discovery file.
  Pub.global.activate('discoveryapis_generator');
  Pub.global.run('discoveryapis_generator:generate', arguments: [
    'files',
    '--input-dir=doc/generated',
    '--output-dir=doc/generated'
  ]);
}
