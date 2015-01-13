// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/**
 * This library is an interface to the command-line pub tool.
 */
library dartpad_server.pub;

import 'dart:async';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;
import 'package:yaml/yaml.dart' as yaml;

Logger _logger = new Logger('pub');

class Pub {
  Directory _cacheDir;

  Pub() {
    _cacheDir = new Directory(path.join(_userHomeDir(), '.dartpadcache'));
    if (!_cacheDir.existsSync()) _cacheDir.createSync();
  }

  String get version {
    ProcessResult result = Process.runSync('pub', ['--version']);
    return result.stdout.trim();
  }

  Future<PackagesInfo> resolvePackages(List<String> packages) {
    Directory tempDir = Directory.systemTemp.createTempSync('temp_package');

    try {
      // Create pubspec file.
      File pubspecFile = new File(path.join(tempDir.path, 'pubspec.yaml'));
      String specContents = 'name: temp\ndependencies:\n' +
          packages.map((p) => '  ${p}: any').join('\n');
      pubspecFile.writeAsStringSync(specContents);

      // Run pub.
      ProcessResult result = Process.runSync(
          'pub', ['get'], workingDirectory: tempDir.path);
      if (result.exitCode != 0) {
        if (result.stderr.isNotEmpty) {
          return new Future.value(result.stderr);
        } else {
          return new Future.value(
              'failed to get pub packages: ${result.exitCode}');
        }
      }

      // Parse the lock file.
      File pubspecLock = new File(path.join(tempDir.path, 'pubspec.lock'));
      return new Future.value(
          _parseLockContents(pubspecLock.readAsStringSync()));
    } catch (e, st) {
      return new Future.error(e, st);
    } finally {
      tempDir.deleteSync(recursive: true);
    }

    return new Future.value();
  }

  /**
   * Return the directory on disk that points to the `lib/` directory of the
   * version of the specific package requested.
   */
  Directory getPackageLibDir(PackageInfo packageInfo) {
    try {
      String dirName = '${packageInfo.name}_${packageInfo.version}';
      Directory packageDir = new Directory(path.join(_cacheDir.path, dirName));
      Directory libDir = new Directory(path.join(packageDir.path, 'lib'));

      if (packageDir.existsSync() && libDir.existsSync()) {
        return libDir;
      }

      _populatePackage(packageInfo, packageDir);

      if (packageDir.existsSync() && libDir.existsSync()) {
        return libDir;
      }

      return null;
    } catch (e, st) {
      _logger.severe('Error getting package ${packageInfo}: ${e}\n${st}');
      return null;
    }
  }

  void flushCache() {
    if (_cacheDir.existsSync()) {
      _cacheDir.deleteSync(recursive: true);
      _cacheDir.createSync();
    }
  }

  PackagesInfo _parseLockContents(String lockContents) {
//    packages:
//      collection:
//        description: collection
//        source: hosted
//        version: "1.1.0"
//      matcher:
//        description: matcher
//        source: hosted
//        version: "0.11.3"

    yaml.YamlNode root = yaml.loadYamlNode(lockContents);

    Map m = root.value;
    Map packages = m['packages'];

    List results = [];

    for (var key in packages.keys) {
      results.add(new PackageInfo(key, packages[key]['version']));
    }

    return new PackagesInfo(results);
  }

  String _userHomeDir() {
    String envKey = Platform.operatingSystem == 'windows' ? 'APPDATA' : 'HOME';
    String value = Platform.environment[envKey];
    return value == null ? '.' : value;
  }

  /**
   * Download the indicated package and expand it into the target directory.
   */
  void _populatePackage(PackageInfo package, Directory target) {
    // TODO:

  }
}

class PackagesInfo {
  final List<PackageInfo> packages;

  PackagesInfo(this.packages);

  String toString() => '${packages}';
}

class PackageInfo {
  final String name;
  final String version;

  PackageInfo(this.name, this.version);

  String toString() => '[${name}: ${version}]';
}
