// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

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

  /// If this is the stable channel.
  bool get stableChannel => _channel == 'stable';

  /// If this is the beta channel.
  bool get betaChannel => _channel == 'beta';

  /// If this is the main channel.
  bool get mainChannel => _channel == 'main';

  // Which channel is this SDK?
  String? _channel;

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

  String get sdkPath {
    _sdkPath ??= _getSdkPath();
    return _sdkPath!;
  }

  String get channel {
    _channel ??= _getChannel();
    return _channel!;
  }

  /// Returns the Flutter channel provided in environment variables.
  String _getChannel() {
    return Process.runSync(
            'git', 'rev-parse --abbrev-ref HEAD'.split(' ').toList(),
            workingDirectory: sdkPath)
        .stdout
        .toString().trim();
  }

  Sdk() {
    final flutterBinPath = path.join(sdkPath, 'bin');
    _flutterBinPath = flutterBinPath;
    dartSdkPath = path.join(flutterBinPath, 'cache', 'dart-sdk');
    dartVersion = _readVersionFile(dartSdkPath);
    flutterVersion = _readVersionFile(sdkPath);
    final engineVersionPath =
        path.join(flutterBinPath, 'internal', 'engine.version');
    engineVersion = _readFile(engineVersionPath);
    version = dartVersion.contains('-')
        ? dartVersion.substring(0, dartVersion.indexOf('-'))
        : dartVersion;
  }

  /// The path to the 'flutter' tool (binary).
  String get flutterToolPath => path.join(_flutterBinPath, 'flutter');

  String get flutterWebSdkPath {
    return path.join(_flutterBinPath, 'cache', 'flutter_web_sdk', 'kernel');
  }

  static String _readVersionFile(String filePath) =>
      _readFile(path.join(filePath, 'version'));
}

const channels = ['stable', 'beta', 'main'];

String _readFile(String filePath) => File(filePath).readAsStringSync().trim();
