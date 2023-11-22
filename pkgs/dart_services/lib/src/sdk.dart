// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;

class Sdk {
  /// The path to the Dart SDK (vended into the Flutter SDK).
  late final String dartSdkPath;

  /// The path to the Flutter SDK.
  late final String flutterSdkPath;

  /// The path to the Flutter binaries.
  late final String _flutterBinPath;

  /// The current version of the Dart SDK, including any `-dev` suffix.
  late final String dartVersion;

  /// The current version of the Flutter SDK.
  late final String flutterVersion;

  /// The current version of the Flutter engine.
  late final String engineVersion;

  // The channel for this SDK.
  late final String channel;

  /// If this is the stable channel.
  bool get stableChannel => channel == 'stable';

  /// If this is the beta channel.
  bool get betaChannel => channel == 'beta';

  /// If this is the main channel.
  bool get mainChannel => channel == 'main';

  /// Experiments that this SDK is configured with
  List<String> get experiments {
    if (mainChannel) return const ['inline-class'];
    return const [];
  }

  void _initPaths() {
    // <flutter-sdk>/bin/cache/dart-sdk
    final dartVM = Platform.resolvedExecutable;

    dartSdkPath = path.dirname(path.dirname(dartVM));
    flutterSdkPath = path.dirname(path.dirname(path.dirname(dartSdkPath)));
    _flutterBinPath = path.join(flutterSdkPath, 'bin');

    // Verify that this is a flutter sdk; check for bin/, packages/, and
    // packages/flutter/.
    final packages = path.join(flutterSdkPath, 'packages');
    if (!FileSystemEntity.isDirectorySync(flutterSdkPath) ||
        !FileSystemEntity.isDirectorySync(path.join(flutterSdkPath, 'bin')) ||
        !FileSystemEntity.isDirectorySync(packages) ||
        !FileSystemEntity.isDirectorySync(path.join(packages, 'flutter'))) {
      throw StateError('flutter sdk not found (from $dartSdkPath)');
    }
  }

  Sdk() {
    _initPaths();

    dartSdkPath = path.join(_flutterBinPath, 'cache', 'dart-sdk');
    dartVersion = _readVersionFile(dartSdkPath);

    // flutter --version --machine
    final versions = _callFlutterVersion();

    flutterVersion = versions['flutterVersion'] as String;
    engineVersion = versions['engineRevision'] as String;

    // Report the 'master' channel as 'main';
    final tempChannel = versions['channel'] as String;
    channel = tempChannel == 'master' ? 'main' : tempChannel;
  }

  /// The path to the 'flutter' tool (binary).
  String get flutterToolPath => path.join(_flutterBinPath, 'flutter');

  String get flutterWebSdkPath {
    return path.join(_flutterBinPath, 'cache', 'flutter_web_sdk', 'kernel');
  }

  bool get usesNewBootstrapEngine {
    final uiWebPackage =
        path.join(_flutterBinPath, 'cache', 'flutter_web_sdk', 'lib', 'ui_web');
    final initializationLibrary =
        path.join(uiWebPackage, 'ui_web', 'initialization.dart');

    final file = File(initializationLibrary);
    if (!file.existsSync()) return false;

    // Look for 'Future<void> bootstrapEngine({ ... }) { ... }'.
    return file.readAsStringSync().contains('bootstrapEngine(');
  }

  Map<String, dynamic> _callFlutterVersion() {
    // Note that we try twice here as the 'flutter --version --machine' command
    // can (erroneously) emit non-json text to stdout (for example, an initial
    // analytics disclaimer).

    try {
      return jsonDecode(Process.runSync(
        flutterToolPath,
        ['--version', '--machine'],
        workingDirectory: flutterSdkPath,
      ).stdout.toString().trim()) as Map<String, dynamic>;
    } on FormatException {
      return jsonDecode(Process.runSync(
        flutterToolPath,
        ['--version', '--machine'],
        workingDirectory: flutterSdkPath,
      ).stdout.toString().trim()) as Map<String, dynamic>;
    }
  }

  static String _readVersionFile(String filePath) {
    final file = File(path.join(filePath, 'version'));
    return file.readAsStringSync().trim();
  }
}
