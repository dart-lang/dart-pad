// Copyright (c) 2021, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert' show jsonDecode;
import 'dart:io';

import 'package:path/path.dart' as path;
import 'project_templates.dart';
import 'sdk.dart';
import 'utils.dart';

typedef LogFunction = void Function(String);

class ProjectCreator {
  final Sdk _sdk;

  final String _templatesPath;

  /// The Dart language version to use.
  final String _dartLanguageVersion;

  final File _dependenciesFile;

  final LogFunction _log;

  ProjectCreator(
    this._sdk,
    this._templatesPath, {
    required String dartLanguageVersion,
    required File dependenciesFile,
    required LogFunction log,
  })  : _dartLanguageVersion = dartLanguageVersion,
        _dependenciesFile = dependenciesFile,
        _log = log;

  /// Builds a basic Dart project template directory, complete with `pubspec.yaml`
  /// and `analysis_options.yaml`.
  Future<void> buildDartProjectTemplate() async {
    final projectPath = path.join(_templatesPath, 'dart_project');
    final projectDirectory = Directory(projectPath);
    await projectDirectory.create(recursive: true);
    final dependencies = _dependencyVersions(supportedBasicDartPackages);
    File(path.join(projectPath, 'pubspec.yaml'))
        .writeAsStringSync(createPubspec(
      includeFlutterWeb: false,
      dartLanguageVersion: _dartLanguageVersion,
      dependencies: dependencies,
    ));

    final exitCode = await _runDartPubGet(projectDirectory);
    if (exitCode != 0) {
      throw StateError('pub get failed ($exitCode)');
    }

    File(path.join(projectPath, 'analysis_options.yaml'))
        .writeAsStringSync(_createAnalysisOptionsContents());
  }

  /// Builds a Flutter project template directory, complete with `pubspec.yaml`,
  /// `analysis_options.yaml`, and `web/index.html`.
  Future<void> buildFlutterProjectTemplate() async {
    final projectPath = path.join(_templatesPath, 'flutter_project');
    await Directory(projectPath).create(recursive: true);
    await Directory(path.join(projectPath, 'lib')).create();
    await Directory(path.join(projectPath, 'web')).create();
    await File(path.join(projectPath, 'web', 'index.html')).create();

    final dependencies = _dependencyVersions({
      ...supportedBasicDartPackages,
      ...supportedFlutterPackages,
    });
    File(path.join(projectPath, 'pubspec.yaml'))
        .writeAsStringSync(createPubspec(
      includeFlutterWeb: true,
      dartLanguageVersion: _dartLanguageVersion,
      dependencies: dependencies,
    ));

    final exitCode = await runFlutterPubGet(_sdk, projectPath, log: _log);
    if (exitCode != 0) {
      throw StateError('flutter pub get failed ($exitCode)');
    }

    // Working around Flutter 3.3's deprecation of generated_plugin_registrant.dart
    // Context: https://github.com/flutter/flutter/pull/106921

    final pluginRegistrant = File(path.join(
        projectPath, '.dart_tool', 'dartpad', 'web_plugin_registrant.dart'));
    if (pluginRegistrant.existsSync()) {
      Directory(path.join(projectPath, 'lib')).createSync();
      pluginRegistrant.copySync(
          path.join(projectPath, 'lib', 'generated_plugin_registrant.dart'));
    }

    File(path.join(projectPath, 'analysis_options.yaml'))
        .writeAsStringSync(_createAnalysisOptionsContents());
  }

  String _createAnalysisOptionsContents() {
    var contents = '''
include: package:lints/core.yaml
''';
    if (_sdk.experiments.isNotEmpty) {
      contents += '''

analyzer:
  enable-experiment:
${_sdk.experiments.map((experiment) => '    - $experiment').join('\n')}
''';
    }
    return contents;
  }

  Future<int> _runDartPubGet(Directory dir) async {
    final process = await runWithLogging(
      path.join(_sdk.dartSdkPath, 'bin', 'dart'),
      arguments: ['pub', 'get'],
      workingDirectory: dir.path,
      environment: {'PUB_CACHE': _pubCachePath},
      log: _log,
    );
    return process.exitCode;
  }

  Map<String, String> _dependencyVersions(Iterable<String> packages) {
    final allVersions =
        parsePubDependenciesFile(dependenciesFile: _dependenciesFile);
    return {
      for (final package in packages) package: allVersions[package] ?? 'any',
    };
  }
}

/// Parses [dependenciesFile] as a JSON Map of Strings.
Map<String, String> parsePubDependenciesFile({required File dependenciesFile}) {
  final packageVersions =
      jsonDecode(dependenciesFile.readAsStringSync()) as Map;
  return packageVersions.cast<String, String>();
}

/// Build and return a `pubspec.yaml` file.
String createPubspec({
  required bool includeFlutterWeb,
  required String dartLanguageVersion,
  Map<String, String> dependencies = const {},
}) {
  var content = '''
name: dartpad_sample
environment:
  sdk: ^$dartLanguageVersion
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

Future<int> runFlutterPubGet(
  Sdk sdk,
  String projectPath, {
  required LogFunction log,
}) async {
  final process = await runWithLogging(
    sdk.flutterToolPath,
    arguments: ['pub', 'get'],
    workingDirectory: projectPath,
    environment: {'PUB_CACHE': _pubCachePath},
    log: log,
  );
  return process.exitCode;
}

/// Builds the local pub cache directory and returns the path.
String get _pubCachePath {
  final pubCachePath = path.join(Directory.current.path, 'local_pub_cache');
  Directory(pubCachePath).createSync();
  return pubCachePath;
}
