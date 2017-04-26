// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/**
 * This library is an interface to the command-line pub tool.
 */
library services.pub;

import 'dart:async';
import 'dart:io';

import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/error/listener.dart';
import 'package:analyzer/src/dart/scanner/reader.dart';
import 'package:analyzer/src/dart/scanner/scanner.dart';
import 'package:analyzer/src/string_source.dart';
import 'package:archive/archive.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;
import 'package:yaml/yaml.dart' as yaml;

import 'common.dart';

Logger _logger = new Logger('pub');

/**
 * This class has two general functions:
 *
 * Given a list of packages, resolve the list to the full transitive set of
 * referenced packages and their versions. This uses an implicit `any`
 * constraint. It will resolve to the lastest non-dev versions that satisfy
 * their mutual constraints.
 *
 * And, given a package and a version, it can return a local directory with the
 * contents of the package's `lib/` folder. This will download the
 * package+version from pub.dartlang.org and store it in a disk cache. As the
 * cache is populated the cost of asking for a package's `lib/` folder contents
 * will go to zero.
 *
 */
class Pub {
  Directory _cacheDir;

  Pub() {
    _cacheDir = Directory.systemTemp.createTempSync('dartpadcache');
    if (!_cacheDir.existsSync()) _cacheDir.createSync();
  }

  factory Pub.mock() => new _MockPub();

  Directory get cacheDir => _cacheDir;

  /**
   * Return the current version of the `pub` executable.
   */
  String getVersion() {
    ProcessResult result = Process.runSync('pub', ['--version']);
    return result.stdout.trim();
  }

  /**
   * Return the transitive closure of the given packages, resolved into the
   * latest compatible versions.
   */
  Future<PackagesInfo> resolvePackages(List<String> packages) {
    if (packages.isEmpty) return new Future.value(new PackagesInfo([]));

    Directory tempDir = Directory.systemTemp.createTempSync(
        /* prefix: */ 'temp_package');

    try {
      // Create pubspec file.
      File pubspecFile = new File(path.join(tempDir.path, 'pubspec.yaml'));
      String specContents = 'name: temp\ndependencies:\n' +
          packages.map((p) => '  ${p}: any').join('\n');
      pubspecFile.writeAsStringSync(specContents, flush: true);

      // Run pub.
      return Process
          .run('pub', ['get'], workingDirectory: tempDir.path)
          .timeout(new Duration(seconds: 20))
          .then((ProcessResult result) {
        if (result.exitCode != 0) {
          String message = result.stderr.isNotEmpty
              ? result.stderr
              : 'failed to get pub packages: ${result.exitCode}';
          _logger.severe('Error running pub get: ${message}');
          return new Future.value(message);
        }

        // Parse the lock file.
        File pubspecLock = new File(path.join(tempDir.path, 'pubspec.lock'));
        return new Future.value(
            _parseLockContents(pubspecLock.readAsStringSync()));
      }).whenComplete(() {
        tempDir.deleteSync(recursive: true);
      });
    } catch (e, st) {
      return new Future.error(e, st);
    }
  }

  /**
   * Return the directory on disk that points to the `lib/` directory of the
   * version of the specific package requested.
   */
  Future<Directory> getPackageLibDir(PackageInfo packageInfo) {
    try {
      String dirName = '${packageInfo.name}-${packageInfo.version}';
      Directory packageDir = new Directory(path.join(_cacheDir.path, dirName));
      Directory libDir = new Directory(path.join(packageDir.path, 'lib'));

      if (packageDir.existsSync() && libDir.existsSync()) {
        return new Future.value(libDir);
      }

      return _populatePackage(packageInfo, _cacheDir, packageDir).then((_) {
        return libDir;
      });
    } catch (e, st) {
      _logger.severe('Error getting package ${packageInfo}: ${e}\n${st}');
      return new Future.error(e);
    }
  }

  Future<PubHelper> createPubHelperForSource(String dartSource) {
    Set<String> packageImports =
        filterSafePackagesFromImports(getAllUnsafeImportsFor(dartSource));

    return resolvePackages(packageImports.toList())
        .then((PackagesInfo packages) {
      return new PubHelper._(this, packages.packages);
    });
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

//  String _userHomeDir() {
//    String envKey = Platform.operatingSystem == 'windows' ? 'APPDATA' : 'HOME';
//    String value = Platform.environment[envKey];
//    return value == null ? '.' : value;
//  }

  /**
   * Download the indicated package and expand it into the target directory.
   */
  Future _populatePackage(
      PackageInfo package, Directory cacheDir, Directory target) {
    final String base =
        'https://storage.googleapis.com/pub.dartlang.org/packages';

    // tuneup-0.0.1.tar.gz
    String tgzName = '${package.name}-${package.version}.tar.gz';
    return http.get('${base}/${tgzName}').then((http.Response response) {
      // Save to disk (for posterity?).
      File tzgFile = new File(path.join(cacheDir.path, tgzName));
      tzgFile.writeAsBytesSync(response.bodyBytes, flush: true);

      // Use the archive package to decompress.
      if (!target.existsSync()) target.createSync(recursive: true);

      // Embiggen the `.tar.gz` data.
      List<int> data = new GZipDecoder().decodeBytes(response.bodyBytes);

      // Extract the tar files.
      TarDecoder tarArchive = new TarDecoder();
      tarArchive.decodeBytes(data);

      for (TarFile file in tarArchive.files) {
        File f =
            new File('${target.path}${Platform.pathSeparator}${file.filename}');
        f.parent.createSync(recursive: true);
        f.writeAsBytesSync(file.content, flush: true);
      }
      ;
    });
  }
}

/**
 * A no-op version of the [Pub] class. This is used to disable `package:`
 * support without having to change the code using the `Pub` class.
 */
class _MockPub implements Pub {
  Directory _cacheDir = null;

  _MockPub();

  Directory get cacheDir => _cacheDir;

  PackagesInfo _parseLockContents(String lockContents) => null;

  Future _populatePackage(
          PackageInfo package, Directory cacheDir, Directory target) =>
      null;

  Future<PubHelper> createPubHelperForSource(String dartSource) =>
      new Future.value(new PubHelper._(this, []));

  void flushCache() {}

  Future<Directory> getPackageLibDir(PackageInfo packageInfo) =>
      new Future.value();

  String getVersion() => null;

  Future<PackagesInfo> resolvePackages(List<String> packages) =>
      new Future.value(new PackagesInfo([]));
}

/**
 * A class with knowledge of a certain set of `package:` imports, and the
 * ability to load the package data for those imports.
 */
class PubHelper {
  final Pub pub;
  final List<PackageInfo> packages;

  PubHelper._(this.pub, this.packages);

  bool get hasPackages => packages.isNotEmpty;

  /**
   * Given a package path fragment, return the contents for the package:
   * reference, or an error from the `Future` if the reference couldn't be
   * resolved.
   */
  Future<String> getPackageContentsAsync(String packageReference) {
    if (!packageReference.startsWith('package:')) {
      return new Future.error('invalid package reference');
    }

    String pathFragment = packageReference.substring(8);

    if (pathFragment == null || pathFragment.trim().isEmpty) {
      return new Future.error('invalid path');
    }

    int index = pathFragment.indexOf('/');

    if (index == -1) {
      return new Future.error('invalid path');
    }

    String packageName = pathFragment.substring(0, index);
    pathFragment = pathFragment.substring(index + 1);

    PackageInfo package = getPackage(packageName);
    if (package == null) {
      return new Future.error('package not found: ${packageName}');
    }

    return pub.getPackageLibDir(package).then((dir) {
      _logger.fine('PACKAGE: reference to ${packageReference}');

      File file = new File(path.join(dir.path, pathFragment));
      if (file.existsSync()) {
        return file.readAsString();
      } else {
        return new Future.error('not found: ${packageReference}');
      }
    });
  }

  PackageInfo getPackage(String packageName) {
    return packages.firstWhere((p) => p.name == packageName,
        orElse: () => null);
  }
}

/**
 * A set of packages.
 */
class PackagesInfo {
  final List<PackageInfo> packages;

  PackagesInfo(this.packages);

  String toString() => '${packages}';
}

/**
 * A package name and version tuple.
 */
class PackageInfo {
  static final nameRegex = new RegExp(r'^([\w]+)$');
  static final versionRegex = new RegExp(r'^([\w-\+\.]+)$');

  final String name;
  final String version;

  PackageInfo(this.name, this.version) {
    if (!nameRegex.hasMatch(name)) throw 'invalid package name: ${name}';
    if (!versionRegex
        .hasMatch(version)) throw 'invalid package version: ${version}';
  }

  String toString() => '[${name}: ${version}]';
}

Set<String> getAllUnsafeImportsFor(String dartSource) {
  if (dartSource == null) return new Set();

  Scanner scanner = new Scanner(new StringSource(dartSource, 'main.dart'),
      new CharSequenceReader(dartSource), AnalysisErrorListener.NULL_LISTENER);
  Token token = scanner.tokenize();

  Set imports = new Set();

  while (token.type != TokenType.EOF) {
    if (_isLibrary(token)) {
      token = _consumeSemi(token);
    } else if (_isImport(token)) {
      token = token.next;

      if (token.type == TokenType.STRING) {
        imports.add(stripMatchingQuotes(token.lexeme));
      }

      token = _consumeSemi(token);
    } else {
      break;
    }
  }

  return imports;
}

/**
 * Return the list of packages that are imported from the given imports. These
 * packages are sanitized defensively.
 */
Set<String> filterSafePackagesFromImports(Set<String> allImports) {
  return new Set.from(allImports.where((import) {
    return import.startsWith('package:');
  }).map((String import) {
    return import.substring(8);
  }).map((String import) {
    int index = import.indexOf('/');
    return index == -1 ? import : import.substring(0, index);
  }).map((String import) {
    return import.replaceAll('..', '');
  }).where((import) {
    return import.isNotEmpty;
  }));
}

bool _isLibrary(Token token) {
  return token.type == TokenType.KEYWORD && token.lexeme == 'library';
}

bool _isImport(Token token) {
  return token.type == TokenType.KEYWORD && token.lexeme == 'import';
}

Token _consumeSemi(Token token) {
  while (token.type != TokenType.SEMICOLON) {
    if (token.type == TokenType.EOF) return token;
    token = token.next;
  }

  // Skip past the semi-colon.
  token = token.next;

  return token;
}
