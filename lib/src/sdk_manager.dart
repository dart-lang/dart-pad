// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as path;

/// Generally, this should be a singleton instance (it's a heavy-weight object).
class SdkManager {
  static Sdk get sdk => _sdk ?? (_sdk = PlatformSdk());

  static FlutterSdk get flutterSdk =>
      _flutterSdk ?? (_flutterSdk = FlutterSdk());

  static void setSdk(Sdk value) {
    _sdk = sdk;
  }

  static void setFlutterSdk(FlutterSdk value) {
    _flutterSdk = value;
  }

  // The installed Dart SDK.
  static Sdk _sdk;

  // The installed Flutter SDK.
  static FlutterSdk _flutterSdk;
}

abstract class Sdk {
  /// Set up the sdk (download it if necessary, ...), and fail if there's an
  /// error.
  Future<void> init();

  /// Report the current version of the SDK.
  String get version {
    var ver = versionFull;
    if (ver.contains('-')) ver = ver.substring(0, ver.indexOf('-'));
    return ver;
  }

  /// Report the current version of the SDK, including any `-dev` suffix.
  String get versionFull;

  /// Get the path to the sdk.
  String get sdkPath;
}

/// Represents a Dart SDK present on the server.
class PlatformSdk extends Sdk {
  String _versionFull = '';

  @override
  Future<void> init() async {
    _versionFull =
        (await File(path.join(sdkPath, 'version')).readAsString()).trim();
  }

  @override
  String get versionFull => _versionFull;

  @override
  String get sdkPath => path.dirname(path.dirname(Platform.resolvedExecutable));
}

/// Represents a Flutter SDK installation (which includes its own version of the
/// Dart SDK) present on the server.
///
/// This class assumes the Flutter SDK is available at `./flutter`.
class FlutterSdk extends Sdk {
  String _versionFull = '';
  String _flutterVersion = '';

  @override
  Future<void> init() async {
    _versionFull =
        (await File(path.join(sdkPath, 'version')).readAsString()).trim();
    _flutterVersion =
        (await File(path.join(Directory.current.path, 'flutter', 'version'))
                .readAsString())
            .trim();
  }

  @override
  String get sdkPath => path.join(flutterBinPath, 'cache', 'dart-sdk');

  String get flutterBinPath =>
      path.join(Directory.current.path, 'flutter', 'bin');

  @override
  String get versionFull => _versionFull;

  String get flutterVersion => _flutterVersion;
}
