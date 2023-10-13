// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:path/path.dart' as path;
import 'package:yaml/yaml.dart';

import 'project.dart' as project;
import 'sdk.dart';
import 'server_cache.dart';

part 'pub.g.dart';

/// Extract all imports from [dartSource] source code.
List<ImportDirective> getAllImportsFor(String? dartSource) {
  if (dartSource == null) return [];

  final unit = parseString(content: dartSource, throwIfDiagnostics: false).unit;
  return unit.directives.whereType<ImportDirective>().toList();
}

/// Takes a map {"filename":"sourcecode"..."filenameN":"sourcecodeN"}
/// of source files and extracts the imports from each file's sourcecode and
/// returns an overall list of all imports across all files in the set.
List<ImportDirective> getAllImportsForFiles(Map<String, String> files) {
  return [
    for (final sourcecode in files.values) ...getAllImportsFor(sourcecode)
  ];
}

/// Flutter packages which do not have version numbers in pubspec.lock.
const _flutterPackages = [
  'flutter',
  'flutter_test',
  'flutter_web_plugins',
  'sky_engine',
];

/// This is expensive to calculate; they require reading from disk.
/// None of them changes during execution.
final Map<String, String> _nullSafePackageVersions =
    packageVersionsFromPubspecLock(
        project.ProjectTemplates.projectTemplates.firebasePath);

/// Returns a mapping of Pub package name to package version.
Map<String, String> getPackageVersions() => _nullSafePackageVersions;

/// Returns a mapping of Pub package name to package version, retrieving data
/// from the project template's `pubspec.lock` file.
Map<String, String> packageVersionsFromPubspecLock(String templatePath) {
  final pubspecLockPath = File(path.join(templatePath, 'pubspec.lock'));
  final pubspecLock = loadYamlDocument(pubspecLockPath.readAsStringSync());
  final pubSpecLockContents = pubspecLock.contents as YamlMap;
  final packages = pubSpecLockContents['packages'] as YamlMap;
  final packageVersions = <String, String>{};

  packages.forEach((nameKey, packageValue) {
    final name = nameKey as String;
    if (_flutterPackages.contains(name)) {
      return;
    }
    final package = packageValue as YamlMap;
    final source = package['source'];
    if (source is! String || source != 'hosted') {
      // `name` is not hosted. Might be a local or git dependency.
      return;
    }
    final version = package['version'];
    if (version is String) {
      packageVersions[name] = version;
    } else {
      throw StateError(
          '$name does not have a well-formatted version: $version');
    }
  });

  return packageVersions;
}

extension ImportIterableExtensions on Iterable<ImportDirective> {
  /// Returns the names of packages that are referenced in this collection.
  /// These package names are sanitized defensively.
  Iterable<String> filterSafePackages() {
    return where((import) => !import.uri.stringValue!.startsWith('package:../'))
        .map((import) => Uri.parse(import.uri.stringValue!))
        .where((uri) => uri.scheme == 'package' && uri.pathSegments.isNotEmpty)
        .map((uri) => uri.pathSegments.first);
  }
}

// TODO: for dart, handle package:lints

// TODO: for flutter, handle package:flutter_lints

/// Provide resolution and caching for package information.
class PackageResolver {
  final ServerCache serverCache;
  final Sdk sdk;

  late final Directory pubCache;

  PackageResolver({
    required this.serverCache,
    required this.sdk,
  }) {
    pubCache = Directory.systemTemp.createTempSync('pub-cache');
  }

  /// Run the equivalent of 'pub get' in the given directory.
  ///
  /// The pubspec dependencies are inferred from the import statements in
  /// [dartSource]. The resolution information is cached; subsequent similar
  /// resolutions will be faster.
  Future<PackageConfig> pubGet(Directory dir, String dartSource) async {
    // parse the packages
    final packages = parsePackages(dartSource);

    // write the pubspec
    final pubspec = File(path.join(dir.path, 'pubspec.yaml'));
    pubspec.writeAsStringSync('''
name: dartpad_sample

environment:
  sdk: ^${sdk.version}

dependencies:
${packages.map((package) {
      // auto-promote flutter packages to sdk dependencies
      return isFlutterSdkPackage(package)
          ? '  $package:\n    sdk: flutter'
          : '  $package: any';
    }).join('\n')}

dev_dependencies:
  lints: any
''');

    // remove any existing pubspec.lock
    final pubspecLock = File(path.join(dir.path, 'pubspec.lock'));
    if (pubspecLock.existsSync()) {
      pubspecLock.deleteSync();
    }

    PackageConfig? packageConfig;
    final packageConfigFile =
        File(path.join(dir.path, '.dart_tool', 'package_config.json'));

    final cacheKey = '${sdk.version}:${packages.join(':')}';
    final resolutionData = await serverCache.get(cacheKey);

    if (resolutionData != null) {
      packageConfig = PackageConfig.fromJson(
          jsonDecode(resolutionData) as Map<String, dynamic>);
      packageConfig = PackageConfig(
        configVersion: packageConfig.configVersion,
        packages: packageConfig.packages,
        fromCached: true,
      );
    }

    if (packageConfig != null &&
        packageConfig.allPackagesExist(sdk, pubCache)) {
      // create our own package config file
      packageConfig.writeToFile(packageConfigFile,
          sdk: sdk, pubCache: pubCache);
      return packageConfig;
    } else {
      final resolutionNotCached = packageConfig == null;

      // run dart pub get
      await _runDartPubGet(dir);

      packageConfig = PackageConfig.readFromFile(sdk, packageConfigFile);

      // If there had been no cache entry, cache the resolution results.
      if (resolutionNotCached) {
        await serverCache.set(
          cacheKey,
          jsonEncode(packageConfig.toJson()),
          expiration: const Duration(hours: 1),
        );
      }

      return packageConfig;
    }
  }

  Future<void> _runDartPubGet(Directory dir) async {
    final result = Process.runSync(
      sdk.flutterToolPath,
      ['pub', 'get'],
      workingDirectory: dir.path,
      environment: {'PUB_CACHE': pubCache.path},
    );

    if (result.exitCode != 0) {
      throw Exception(result.stderr as String);
    }
  }

  List<String> parsePackages(String dartSource) {
    final imports = getAllImportsFor(dartSource);

    return imports
        .where((import) {
          final uriString = import.uri.stringValue;
          if (uriString == null || uriString.isEmpty) {
            return false;
          }

          final uri = Uri.tryParse(uriString);
          return uri != null && uri.scheme == 'package';
        })
        .map((import) {
          final uri = Uri.parse(import.uri.stringValue!);
          final segments = uri.pathSegments;

          return segments.isEmpty ? null : segments.first;
        })
        .whereType<String>()
        .toSet()
        .toList()
      ..sort();
  }

  void dispose() {
    pubCache.deleteSync(recursive: true);
  }

  static bool isFlutterSdkPackage(String name) {
    const flutterSdkPackages = {
      'flutter',
      'flutter_driver',
      'flutter_goldens',
      'flutter_localizations',
      'flutter_test',
      'flutter_web_plugins',
      'integration_test',
    };

    return flutterSdkPackages.contains(name);
  }
}

@JsonSerializable()
class PackageConfig {
  final int configVersion;
  final List<PackageInfo> packages;
  final bool fromCached;

  PackageConfig({
    required this.configVersion,
    required this.packages,
    required this.fromCached,
  });

  factory PackageConfig.fromJson(Map<String, dynamic> json) =>
      _$PackageConfigFromJson(json);

  bool allPackagesExist(Sdk sdk, Directory pubCache) {
    return packages.every((package) {
      return package.exists(sdk, pubCache);
    });
  }

  Map<String, dynamic> toJson() => _$PackageConfigToJson(this);

  void writeToFile(
    File packageConfigFile, {
    required Sdk sdk,
    required Directory pubCache,
  }) {
    const encoder = JsonEncoder.withIndent('  ');

    final json = {
      'configVersion': configVersion,
      'packages': packages.map((package) {
        final dir = package.directoryForCache(sdk, pubCache).absolute;

        return {
          'name': package.name,
          'rootUri': dir.uri.toString(),
          'packageUri': 'lib/',
          'languageVersion': package.languageVersion,
        };
      }).toList(),
      'generator': 'dartpad',
    };

    packageConfigFile.writeAsStringSync(encoder.convert(json));
  }

  static PackageConfig readFromFile(Sdk sdk, File packageConfigFile) {
    final json = jsonDecode(packageConfigFile.readAsStringSync())
        as Map<String, dynamic>;

    final packages = (json['packages'] as List).cast<Map<String, dynamic>>();

    return PackageConfig(
      configVersion: json['configVersion'] as int,
      packages: packages
          .map((data) {
            // file:///Users/devoncarew/.pub-cache/hosted/pub.dev/path-1.8.3
            final rootUri = data['rootUri'] as String;
            if (rootUri == '../') return null;

            final filePath = Uri.parse(rootUri).toFilePath();
            final flutterPackage = path.isWithin(sdk.sdkPath, filePath);

            if (flutterPackage) {
              return PackageInfo(
                name: data['name'] as String,
                languageVersion: data['languageVersion'] as String,
                flutterSdkPath: path.relative(filePath, from: sdk.sdkPath),
              );
            } else {
              // .../web-0.1.4-beta
              final uri = Uri.parse(rootUri);
              final name = uri.pathSegments.last;
              final index = name.contains('-') ? name.indexOf('-') + 1 : 0;

              return PackageInfo(
                name: data['name'] as String,
                languageVersion: data['languageVersion'] as String,
                version: name.substring(index),
              );
            }
          })
          .whereType<PackageInfo>()
          .toList(),
      fromCached: false,
    );
  }
}

@JsonSerializable()
class PackageInfo {
  final String name;
  final String languageVersion;
  final String? version;
  final String? flutterSdkPath;

  PackageInfo({
    required this.name,
    required this.languageVersion,
    this.version,
    this.flutterSdkPath,
  });

  factory PackageInfo.fromJson(Map<String, dynamic> json) =>
      _$PackageInfoFromJson(json);

  Map<String, dynamic> toJson() => _$PackageInfoToJson(this);

  bool exists(Sdk sdk, Directory pubCache) {
    return directoryForCache(sdk, pubCache).existsSync();
  }

  Directory directoryForCache(Sdk sdk, Directory pubCache) {
    if (flutterSdkPath != null) {
      return Directory(path.join(sdk.sdkPath, flutterSdkPath));
    } else {
      return Directory(
          path.join(pubCache.path, 'hosted', 'pub.dev', '$name-$version'));
    }
  }
}
