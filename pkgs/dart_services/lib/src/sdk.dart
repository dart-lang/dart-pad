// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;

class Sdk {
  /// The path to the Flutter binaries.
  late final String _flutterBinPath;

  /// The path to the Dart SDK.
  late final String dartSdkPath;

  /// The current version of the SDK, including any `-dev` suffix.
  late final String dartVersion;

  late final String flutterVersion;

  /// The current version of the Flutter engine
  late final String engineVersion;

  /// The current version of the SDK, not including any `-dev` suffix.
  late final String version;

  // The channel for this SDK.
  late final String channel;

  /// If this is the stable channel.
  bool get stableChannel => channel == 'stable';

  /// If this is the beta channel.
  bool get betaChannel => channel == 'beta';

  /// If this is the main channel.
  bool get mainChannel => channel == 'main';

  // The directory that contains this SDK
  String? _sdkPath;

  /// Experiments that this SDK is configured with
  List<String> get experiments {
    if (mainChannel) return const ['inline-class'];
    return const [];
  }

  String _getSdkPath() {
    // <flutter-sdk>/bin/cache/dart-sdk
    final dart = Platform.resolvedExecutable;
    final dartSdk = path.dirname(path.dirname(dart));
    final flutterSdk = path.dirname(path.dirname(path.dirname(dartSdk)));

    // Verify that this is a flutter sdk; check for bin/, packages/, and
    // packages/flutter/.
    final packages = path.join(flutterSdk, 'packages');
    if (!FileSystemEntity.isDirectorySync(flutterSdk) ||
        !FileSystemEntity.isDirectorySync(path.join(flutterSdk, 'bin')) ||
        !FileSystemEntity.isDirectorySync(packages) ||
        !FileSystemEntity.isDirectorySync(path.join(packages, 'flutter'))) {
      throw StateError('flutter sdk not found (from $dartSdk)');
    }

    return flutterSdk;
  }

  String get sdkPath => _sdkPath ??= _getSdkPath();

  Sdk() {
    _flutterBinPath = path.join(sdkPath, 'bin');

    dartSdkPath = path.join(_flutterBinPath, 'cache', 'dart-sdk');
    dartVersion = _readVersionFile(dartSdkPath);
    version = dartVersion.contains('-')
        ? dartVersion.substring(0, dartVersion.indexOf('-'))
        : dartVersion;

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
        workingDirectory: sdkPath,
      ).stdout.toString().trim()) as Map<String, dynamic>;
    } on FormatException {
      return jsonDecode(Process.runSync(
        flutterToolPath,
        ['--version', '--machine'],
        workingDirectory: sdkPath,
      ).stdout.toString().trim()) as Map<String, dynamic>;
    }
  }

  static String _readVersionFile(String filePath) {
    final file = File(path.join(filePath, 'version'));
    return file.readAsStringSync().trim();
  }
}
