// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert' show utf8;
import 'dart:io';

import 'package:meta/meta.dart';
import 'package:path/path.dart' as path;
import 'package:yaml/yaml.dart';

class Sdk {
  static Sdk _instance;
  factory Sdk() => _instance ?? (_instance = Sdk._());

  String _versionFull = '';
  String _flutterVersion = '';

  Sdk._() {
    _versionFull =
        (File(path.join(sdkPath, 'version')).readAsStringSync()).trim();
    _flutterVersion =
        (File(path.join(flutterSdkPath, 'version')).readAsStringSync()).trim();
  }

  /// Get the path to the Flutter SDK.
  static String get flutterSdkPath =>
      path.join(Directory.current.path, 'flutter-sdk');

  /// Get the path to the Dart SDK.
  static String get sdkPath => path.join(flutterBinPath, 'cache', 'dart-sdk');

  /// Get the path to the Flutter binaries.
  static String get flutterBinPath => path.join(flutterSdkPath, 'bin');

  /// Report the current version of the SDK.
  String get version {
    var ver = versionFull;
    if (ver.contains('-')) ver = ver.substring(0, ver.indexOf('-'));
    return ver;
  }

  /// Report the current version of the SDK, including any `-dev` suffix.
  String get versionFull => _versionFull;

  String get flutterVersion => _flutterVersion;
}

class DownloadingSdkManager {
  DownloadingSdkManager();

  /// Read and return the Flutter sdk configuration file info
  /// (`flutter-sdk-version.yaml`).
  static Map<String, Object> getSdkConfigInfo() {
    final file =
        File(path.join(Directory.current.path, 'flutter-sdk-version.yaml'));
    return (loadYaml(file.readAsStringSync()) as Map).cast<String, Object>();
  }

  /// Create a Flutter SDK in `flutter-sdk/` that configured using the
  /// `flutter-sdk-version.yaml` file.
  ///
  /// Note that this is an expensive operation.
  Future<Sdk> createFromConfigFile() async {
    final sdkConfig = getSdkConfigInfo();

    // flutter_sdk:
    //   channel: beta
    //   #version: 1.25.0-8.1.pre
    if (!sdkConfig.containsKey('flutter_sdk')) {
      throw "No key 'flutter_sdk' found in sdk config file";
    }

    final config = (sdkConfig['flutter_sdk'] as Map).cast<String, Object>();

    if (config.containsKey('channel') && config.containsKey('version')) {
      throw "config file contains both 'channel' and 'version' config settings";
    }

    if (config.containsKey('channel')) {
      return createUsingFlutterChannel(channel: config['channel'] as String);
    } else if (config.containsKey('version')) {
      return createUsingFlutterVersion(version: config['version'] as String);
    } else {
      // Clone the repo if necessary but don't do any other setup.
      return (await _cloneSdkIfNecessary()).asSdk();
    }
  }

  /// Create a Flutter SDK in `flutter-sdk/` that tracks a specific Flutter
  /// channel.
  ///
  /// Note that this is an expensive operation.
  Future<Sdk> createUsingFlutterChannel({
    @required String channel,
  }) async {
    final sdk = await _cloneSdkIfNecessary();

    // git checkout master
    await sdk.checkout('master');

    // Check if 'beta' exists.
    if (await sdk.checkChannelAvailableLocally(channel)) {
      await sdk.checkout(channel);
    } else {
      await sdk.trackChannel(channel);
    }

    // git pull
    await sdk.pull();

    return sdk.asSdk();
  }

  /// Create a Flutter SDK in `flutter-sdk/` that tracks a specific Flutter
  /// version.
  ///
  /// Note that this is an expensive operation.
  Future<Sdk> createUsingFlutterVersion({
    @required String version,
  }) async {
    final sdk = await _cloneSdkIfNecessary();

    // git checkout master
    await sdk.checkout('master');
    // git fetch --tags
    await sdk.fetchTags();
    // git checkout 1.25.0-8.1.pre
    await sdk.checkout(version);

    // Force downloading of Dart SDK before constructing the Sdk singleton.
    await sdk.init();

    return sdk.asSdk();
  }

  Future<_DownloadedFlutterSdk> _cloneSdkIfNecessary() async {
    final sdk = _DownloadedFlutterSdk(Sdk.flutterSdkPath);

    if (!Directory(sdk.flutterSdkPath).existsSync()) {
      // This takes perhaps ~20 seconds.
      await sdk.clone(
        [
          '--depth',
          '1',
          '--no-single-branch',
          'https://github.com/flutter/flutter',
          sdk.flutterSdkPath,
        ],
        cwd: Directory.current.path,
      );
    }

    return sdk;
  }
}

class _DownloadedFlutterSdk {
  final String flutterSdkPath;

  _DownloadedFlutterSdk(this.flutterSdkPath);

  Future<void> init() async {
    // flutter --version takes ~28s
    await _execLog('bin/flutter', ['--version'], flutterSdkPath);
  }

  Sdk asSdk() => Sdk();

  String get sdkPath => path.join(flutterSdkPath, 'bin/cache/dart-sdk');

  String get versionFull =>
      File(path.join(sdkPath, 'version')).readAsStringSync().trim();

  String get flutterVersion =>
      File(path.join(flutterSdkPath, 'version')).readAsStringSync().trim();

  /// Perform a git clone, logging the command and any output, and throwing an
  /// exception if there are any issues with the clone.
  Future<void> clone(List<String> args, {@required String cwd}) async {
    final result = await _execLog('git', ['clone', ...args], cwd);
    if (result != 0) {
      throw 'result from git clone: $result';
    }
  }

  Future<void> checkout(String branch) async {
    final result = await _execLog('git', ['checkout', branch], flutterSdkPath);
    if (result != 0) {
      throw 'result from git checkout: $result';
    }
  }

  Future<void> fetchTags() async {
    final result = await _execLog('git', ['fetch', '--tags'], flutterSdkPath);
    if (result != 0) {
      throw 'result from git fetch: $result';
    }
  }

  Future<void> pull() async {
    final result = await _execLog('git', ['pull'], flutterSdkPath);
    if (result != 0) {
      throw 'result from git pull: $result';
    }
  }

  Future<void> trackChannel(String channel) async {
    // git checkout --track -b beta origin/beta
    final result = await _execLog(
      'git',
      [
        'checkout',
        '--track',
        '-b',
        channel,
        'origin/$channel',
      ],
      flutterSdkPath,
    );
    if (result != 0) {
      throw 'result from git checkout $channel: $result';
    }
  }

  Future<bool> checkChannelAvailableLocally(String channel) async {
    // git show-ref --verify --quiet refs/heads/beta
    final result = await _execLog(
      'git',
      [
        'show-ref',
        '--verify',
        '--quiet',
        'refs/heads/$channel',
      ],
      flutterSdkPath,
    );

    return result == 0;
  }

  Future<int> _execLog(
      String executable, List<String> arguments, String cwd) async {
    print('$executable ${arguments.join(' ')}');

    final process = await Process.start(
      executable,
      arguments,
      workingDirectory: cwd,
    );
    process.stdout
        .transform<String>(utf8.decoder)
        .listen((string) => stdout.write(string));
    process.stderr
        .transform<String>(utf8.decoder)
        .listen((string) => stderr.write(string));

    return await process.exitCode;
  }
}
