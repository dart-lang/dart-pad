// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;

import 'experiments.dart';

/// Information about the device's currently configured Flutter SDK
/// and its embedded Dart SDK.
final class Sdk {
  /// The path to the Dart SDK (vended into the Flutter SDK).
  final String dartSdkPath;

  /// The path to the Flutter SDK.
  final String flutterSdkPath;

  /// The path to the Flutter CLI tool.
  final String flutterToolPath;

  /// The path to the Flutter binaries.
  final String _flutterBinPath;

  /// The current version of the Dart SDK, including any `-dev` suffix.
  final String dartVersion;

  /// The current version of the Flutter SDK.
  final String flutterVersion;

  /// The current version of the Flutter engine.
  final String engineVersion;

  /// The channel for this SDK.
  final String channel;

  /// If this [Sdk] is from the `stable` channel.
  bool get stableChannel => channel == 'stable';

  /// If this [Sdk] is from the `beta` channel.
  bool get betaChannel => channel == 'beta';

  /// If this [Sdk] is from the `main` channel.
  bool get mainChannel => channel == 'main';

  /// The experiments to use for the current [channel].
  List<String> get experiments =>
      (mainChannel || betaChannel) ? enabledExperiments : const [];

  Sdk._({
    required this.channel,
    required this.dartSdkPath,
    required this.dartVersion,
    required String flutterBinPath,
    required this.flutterToolPath,
    required this.flutterSdkPath,
    required this.flutterVersion,
    required this.engineVersion,
  }) : _flutterBinPath = flutterBinPath;

  /// Create an [Sdk] to track the location and version information
  /// of the Flutter SDK used to run `dart_services`, or if not valid,
  /// the one configured using the `FLUTTER_ROOT` environment variable.
  factory Sdk.fromLocalFlutter() {
    // Note below, 'Platform.resolvedExecutable' will not lead to a real SDK if
    // we've been compiled into an AOT binary. In those cases we fall back to
    // looking for a 'FLUTTER_ROOT' environment variable.

    // <flutter-sdk>/bin/cache/dart-sdk/bin/dart
    final potentialFlutterSdkPath = path.dirname(path.dirname(
        path.dirname(path.dirname(path.dirname(Platform.resolvedExecutable)))));

    final String flutterSdkPath;
    if (_validFlutterSdk(potentialFlutterSdkPath)) {
      flutterSdkPath = potentialFlutterSdkPath;
    } else {
      final flutterRootPath = Platform.environment['FLUTTER_ROOT'];
      if (flutterRootPath == null || !_validFlutterSdk(flutterRootPath)) {
        throw StateError('Flutter SDK not found');
      }
      flutterSdkPath = flutterRootPath;
    }

    final flutterBinPath = path.join(flutterSdkPath, 'bin');
    final flutterToolPath = path.join(flutterBinPath, 'flutter');
    final dartSdkPath = path.join(flutterSdkPath, 'bin', 'cache', 'dart-sdk');
    final dartVersion = _readDartSdkVersionFile(dartSdkPath);

    final versions = _retrieveFlutterVersion(flutterSdkPath, flutterToolPath);

    final flutterVersion = versions['flutterVersion'] as String;
    final engineVersion = versions['engineRevision'] as String;

    final rawChannel = versions['channel'] as String;
    // Report the 'master' channel as 'main';
    final channel = rawChannel == 'master' ? 'main' : rawChannel;
    assert(const {'stable', 'beta', 'main'}.contains(channel));

    return Sdk._(
      channel: channel,
      dartSdkPath: dartSdkPath,
      dartVersion: dartVersion,
      flutterSdkPath: flutterSdkPath,
      flutterBinPath: flutterBinPath,
      flutterToolPath: flutterToolPath,
      flutterVersion: flutterVersion,
      engineVersion: engineVersion,
    );
  }

  String get flutterWebSdkPath =>
      path.join(_flutterBinPath, 'cache', 'flutter_web_sdk', 'kernel');

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

  static Map<String, Object?> _retrieveFlutterVersion(
    String flutterSdkPath,
    String flutterToolPath,
  ) {
    // Note that we try twice here as the 'flutter --version --machine' command
    // can (erroneously) emit non-json text to stdout (for example, an initial
    // analytics disclaimer).

    try {
      return jsonDecode(Process.runSync(
        flutterToolPath,
        ['--version', '--machine'],
        workingDirectory: flutterSdkPath,
      ).stdout.toString().trim()) as Map<String, Object?>;
    } on FormatException {
      return jsonDecode(Process.runSync(
        flutterToolPath,
        ['--version', '--machine'],
        workingDirectory: flutterSdkPath,
      ).stdout.toString().trim()) as Map<String, Object?>;
    }
  }

  static String _readDartSdkVersionFile(String filePath) {
    final file = File(path.join(filePath, 'version'));
    return file.readAsStringSync().trim();
  }

  static bool _validFlutterSdk(String sdkPath) {
    // Verify that this is a Flutter sdk; check for bin/, packages/, and
    // packages/flutter/.
    if (!FileSystemEntity.isDirectorySync(sdkPath) ||
        !FileSystemEntity.isDirectorySync(path.join(sdkPath, 'bin'))) {
      return false;
    }

    final packages = path.join(sdkPath, 'packages');
    if (!FileSystemEntity.isDirectorySync(packages) ||
        !FileSystemEntity.isDirectorySync(path.join(packages, 'flutter'))) {
      return false;
    }

    return true;
  }
}
