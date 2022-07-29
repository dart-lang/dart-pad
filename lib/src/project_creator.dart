// Copyright (c) 2021, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert' show jsonDecode;
import 'dart:io';

import 'package:path/path.dart' as path;
import 'project.dart';
import 'sdk.dart';
import 'utils.dart';

typedef LogFunction = void Function(String);

class ProjectCreator {
  final String _dartSdkPath;

  final String _flutterToolPath;

  final String _templatesPath;

  /// The Dart Language Version to use for code using null safety.
  final String _dartLanguageVersion;

  final File _dependenciesFile;

  final LogFunction _log;

  ProjectCreator(
    Sdk sdk,
    this._templatesPath, {
    required String dartLanguageVersion,
    required File dependenciesFile,
    required LogFunction log,
  })  : _dartSdkPath = sdk.dartSdkPath,
        _flutterToolPath = sdk.flutterToolPath,
        _dartLanguageVersion = dartLanguageVersion,
        _dependenciesFile = dependenciesFile,
        _log = log;

  /// Builds a basic Dart project template directory, complete with `pubspec.yaml`
  /// and `analysis_options.yaml`.
  Future<void> buildDartProjectTemplate({required bool oldChannel}) async {
    final projectPath = path.join(_templatesPath, 'dart_project');
    final projectDirectory = Directory(projectPath);
    await projectDirectory.create(recursive: true);
    final dependencies =
        _dependencyVersions(supportedBasicDartPackages, oldChannel: oldChannel);
    File(path.join(projectPath, 'pubspec.yaml'))
        .writeAsStringSync(createPubspec(
      includeFlutterWeb: false,
      dartLanguageVersion: _dartLanguageVersion,
      dependencies: dependencies,
    ));
    await _runDartPubGet(projectDirectory);
    File(path.join(projectPath, 'analysis_options.yaml')).writeAsStringSync('''
include: package:lints/recommended.yaml
linter:
  rules:
    avoid_print: false
''');
  }

  /// Builds a Flutter project template directory, complete with `pubspec.yaml`,
  /// `analysis_options.yaml`, and `web/index.html`.
  ///
  /// Depending on [firebaseStyle], Firebase packages are included in
  /// `pubspec.yaml` which affects how `flutter packages get` will register
  /// plugins.
  Future<void> buildFlutterProjectTemplate({
    required FirebaseStyle firebaseStyle,
    required bool devMode,
    required bool oldChannel,
  }) async {
    final projectDirName = firebaseStyle == FirebaseStyle.none
        ? 'flutter_project'
        : 'firebase_project';
    final projectPath = path.join(
      _templatesPath,
      projectDirName,
    );
    final projectDir = await Directory(projectPath).create(recursive: true);
    await Directory(path.join(projectPath, 'lib')).create();
    await Directory(path.join(projectPath, 'web')).create();
    await File(path.join(projectPath, 'web', 'index.html')).create();
    var packages = {
      ...supportedBasicDartPackages,
      ...supportedFlutterPackages(devMode: devMode),
      if (firebaseStyle != FirebaseStyle.none) ...coreFirebasePackages,
      if (firebaseStyle == FirebaseStyle.flutterFire)
        ...registerableFirebasePackages,
    };
    final dependencies = _dependencyVersions(packages, oldChannel: oldChannel);
    File(path.join(projectPath, 'pubspec.yaml'))
        .writeAsStringSync(createPubspec(
      includeFlutterWeb: true,
      dartLanguageVersion: _dartLanguageVersion,
      dependencies: dependencies,
    ));
    await runFlutterPackagesGet(_flutterToolPath, projectPath, log: _log);

    // Working around Flutter 3.3's deprecation of generated_plugin_registrant.dart
    // Context: https://github.com/flutter/flutter/pull/106921

    final pluginRegistrant = File(path.join(
        projectPath, '.dart_tool', 'dartpad', 'web_plugin_registrant.dart'));
    if (pluginRegistrant.existsSync()) {
      Directory(path.join(projectPath, 'lib')).createSync();
      pluginRegistrant.copySync(
          path.join(projectPath, 'lib', 'generated_plugin_registrant.dart'));
    }

    if (firebaseStyle != FirebaseStyle.none) {
      // `flutter packages get` has been run with a _subset_ of all supported
      // Firebase packages, the ones that don't require a Firebase app to be
      // configured in JavaScript, before executing Dart. Now add the full set of
      // supported Firebase pacakges. This workaround is a very fragile hack.
      packages = {
        ...supportedBasicDartPackages,
        ...supportedFlutterPackages(devMode: devMode),
        ...firebasePackages,
      };
      final dependencies =
          _dependencyVersions(packages, oldChannel: oldChannel);
      File(path.join(projectPath, 'pubspec.yaml'))
          .writeAsStringSync(createPubspec(
        includeFlutterWeb: true,
        dartLanguageVersion: _dartLanguageVersion,
        dependencies: dependencies,
      ));
      await _runDartPubGet(projectDir);
    }
    File(path.join(projectPath, 'analysis_options.yaml')).writeAsStringSync('''
include: package:flutter_lints/flutter.yaml
linter:
  rules:
    avoid_print: false
    use_key_in_widget_constructors: false
''');
  }

  Future<void> _runDartPubGet(Directory dir) async {
    final process = await runWithLogging(
      path.join(_dartSdkPath, 'bin', 'dart'),
      arguments: ['pub', 'get'],
      workingDirectory: dir.path,
      environment: {'PUB_CACHE': _pubCachePath},
      log: _log,
    );
    await process.exitCode;
  }

  Map<String, String> _dependencyVersions(Iterable<String> packages,
      {required bool oldChannel}) {
    final allVersions =
        parsePubDependenciesFile(dependenciesFile: _dependenciesFile);
    return {
      for (var package in packages) package: allVersions[package] ?? 'any',
      // Overwrite with important constraints:
      ...packageVersionConstraints(oldChannel: oldChannel),
    };
  }
}

/// A mapping of version constraints for certain packages.
Map<String, String> packageVersionConstraints({required bool oldChannel}) {
  // Ensure that pub version solving keeps these at sane minimum versions.
  return {
    'cloud_firestore': '^3.1.0',
    'firebase_auth': '^3.3.0',
    'firebase_core': '^1.15.0',
  };
}

/// Parses [dependenciesFile] as a JSON Map of Strings.
Map<String, String> parsePubDependenciesFile({required File dependenciesFile}) {
  final packageVersions =
      jsonDecode(dependenciesFile.readAsStringSync()) as Map;
  return packageVersions.cast<String, String>();
}

/// Build a return a `pubspec.yaml` file.
String createPubspec({
  required bool includeFlutterWeb,
  required String dartLanguageVersion,
  Map<String, String> dependencies = const {},
}) {
  var content = '''
name: dartpad_sample
environment:
  sdk: '>=$dartLanguageVersion <3.0.0'
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

Future<void> runFlutterPackagesGet(
  String flutterToolPath,
  String projectPath, {
  required LogFunction log,
}) async {
  final process = await runWithLogging(flutterToolPath,
      arguments: ['packages', 'get'],
      workingDirectory: projectPath,
      environment: {'PUB_CACHE': _pubCachePath},
      log: log);
  await process.exitCode;
}

/// Builds the local pub cache directory and returns the path.
String get _pubCachePath {
  final pubCachePath = path.join(Directory.current.path, 'local_pub_cache');
  Directory(pubCachePath).createSync();
  return pubCachePath;
}

enum FirebaseStyle {
  /// Indicates that no Firebase is used.
  none,

  /// Indicates that the "pure Dart" Flutterfire packages are used.
  flutterFire,
}
