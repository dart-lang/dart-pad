// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;

Logger _logger = new Logger('sdk_manager');

/// Generally, this should be a singleton instance (it's a heavy-weight object).
class SdkManager {
  static Sdk get sdk => _sdk ?? (_sdk = new DownloadingSdk());

  static void setSdk(Sdk value) {
    _sdk = sdk;
  }

  static Sdk _sdk;
}

abstract class Sdk {
  /// Set up the sdk (download it if necessary, ...), and fail if there's an
  /// error.
  Future init();

  /// Report the current version of the SDK.
  String get version {
    String ver = versionFull;
    if (ver.contains('-')) ver = ver.substring(0, ver.indexOf('-'));
    return ver;
  }

  /// Report the current version of the SDK, including any `-dev` suffix.
  String get versionFull;

  /// Get the path to the sdk.
  String get sdkPath;
}

class HostSdk extends Sdk {
  Future init() => new Future.value();

  String get versionFull => Platform.version;

  String get sdkPath => path.dirname(path.dirname(Platform.resolvedExecutable));
}

/// For this class, the cwd should be the root of the project.
class DownloadingSdk extends Sdk {
  static const String kSdkPathName = 'dart-sdk';

  String _versionFull;

  DownloadingSdk() {
    _versionFull = new File('dart-sdk.version').readAsStringSync().trim();
  }

  Future init() async {
    File file = new File(path.join(sdkPath, 'version'));
    if (file.existsSync() && file.readAsStringSync().trim() == _versionFull) {
      return;
    }

    String channel = 'stable';
    if (_versionFull.contains('-dev.')) {
      channel = 'dev';
    }

    String zipName;
    if (Platform.isMacOS) {
      zipName = 'dartsdk-macos-x64-release.zip';
    } else if (Platform.isLinux) {
      zipName = 'dartsdk-linux-x64-release.zip';
    } else {
      throw 'platform ${Platform.operatingSystem} not supported';
    }

    String url = 'https://storage.googleapis.com/dart-archive/channels/'
        '$channel/raw/$_versionFull/sdk/$zipName';

    File destFile = new File(path.join(Directory.systemTemp.path, zipName));

    ProcessResult result =
        await _curl('Dart SDK $version', url, destFile, retryCount: 2);
    if (result.exitCode != 0) {
      throw 'curl failed: ${result.exitCode}\n${result.stdout}\n${result
          .stderr}';
    }

    Directory destDir = new Directory(path.dirname(sdkPath));
    if (!destDir.existsSync()) {
      destDir.createSync(recursive: true);
    }
    result = await Process
        .run('unzip', ['-o', '-q', destFile.path, '-d', destDir.path]);
    if (result.exitCode != 0) {
      throw 'unzip failed: ${result.exitCode}\n${result.stdout}\n${result
          .stderr}';
    }
    _logger.info('SDK available at $sdkPath');
  }

  String get versionFull => _versionFull;

  String get sdkPath => path.join(Directory.current.path, kSdkPathName);
}

Future<ProcessResult> _curl(
  String message,
  String url,
  File destFile, {
  int retryCount: 1,
}) async {
  int count = 0;
  ProcessResult result;

  while (count < retryCount) {
    count++;

    _logger.info('Downloading $message...');
    result = await Process.run('curl',
        ['-continue-at=-', '--location', '--output', destFile.path, url]);
    if (result.exitCode == 0) {
      return result;
    }
  }

  return result;
}
