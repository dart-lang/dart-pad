import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as path;

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

  /// report the current version
  String get version;

  /// get the path to the sdk
  String get sdkPath;
}

class HostSdk extends Sdk {
  Future init() => new Future.value();

  String get version => Platform.version;

  String get sdkPath => path.dirname(path.dirname(Platform.resolvedExecutable));
}

/// For this class, the cwd should be the root of the project.
class DownloadingSdk extends Sdk {
  static const String kSdkPathName = 'dart-sdk';

  String _version;

  DownloadingSdk() {
    _version = new File('dart-sdk.version').readAsStringSync().trim();
  }

  Future init() async {
    File file = new File(path.join(sdkPath, 'version'));
    if (file.existsSync() && file.readAsStringSync().trim() == _version) {
      return;
    }

    String channel = 'stable';
    if (_version.contains('-dev.')) {
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
        '$channel/raw/$_version/sdk/$zipName';

    File destFile = new File(path.join(Directory.systemTemp.path, zipName));

    print('Downloading Dart SDK $version...');
    ProcessResult result = await Process.run('curl',
        ['-continue-at=-', '--location', '--output', destFile.path, url]);
    if (result.exitCode != 0) {
      throw 'curl failed: ${result.exitCode}\n${result.stdout}\n${result
          .stderr}';
    }
    result = await Process
        .run('unzip', ['-o', '-q', destFile.path, '-d', path.dirname(sdkPath)]);
    if (result.exitCode != 0) {
      throw 'unzip failed: ${result.exitCode}\n${result.stdout}\n${result
          .stderr}';
    }
    print('SDK available at $sdkPath');
  }

  String get version => _version;

  String get sdkPath => path.join(Directory.current.path, kSdkPathName);
}
