// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;

const stableChannel = 'stable';

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

  // When running with `dart run`, the FLUTTER_ROOT environment variable is
  // set automatically.
  String _getSdkPath() {
    final env = Platform.environment;
    if (!env.containsKey('FLUTTER_ROOT') || env['FLUTTER_ROOT']!.isEmpty) {
      throw Exception('No FLUTTER_ROOT variable set');
    }

    return env['FLUTTER_ROOT']!;
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
    channel = versions['channel'] as String;
    engineVersion = versions['engineRevision'] as String;
  }

  /// The path to the 'flutter' tool (binary).
  String get flutterToolPath => path.join(_flutterBinPath, 'flutter');

  String get flutterWebSdkPath {
    return path.join(_flutterBinPath, 'cache', 'flutter_web_sdk', 'kernel');
  }

  Map<String, dynamic> _callFlutterVersion() {
    // Note that we try twice here as the 'flutter --version --machine' command
    // can (erroneously) emit non-json text to stdout (for example, an initial
    // analytics disclaimer).

    try {
      final str = Process.runSync(
        flutterToolPath,
        ['--version', '--machine'],
        workingDirectory: sdkPath,
      ).stdout.toString().trim();
      return jsonDecode(str) as Map<String, dynamic>;
    } on FormatException {
      final str = Process.runSync(
        flutterToolPath,
        ['--version', '--machine'],
        workingDirectory: sdkPath,
      ).stdout.toString().trim();
      return jsonDecode(str) as Map<String, dynamic>;
    }
  }

  static String _readVersionFile(String filePath) =>
      _readFile(path.join(filePath, 'version'));
}

const channels = ['stable', 'beta', 'main'];

String _readFile(String filePath) => File(filePath).readAsStringSync().trim();
