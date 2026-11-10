// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of 'project_source.dart';

/// A package downloaded using archive metadata from pub.dev.
final class PackageProjectSource extends ProjectSource {
  /// Describes [package] at [version], or its latest version when null.
  const PackageProjectSource(this.package, {this.version});

  /// The package name used to request metadata from pub.dev.
  final String package;

  /// Exact package version, or null to load the latest version from pub.dev.
  final String? version;

  @override
  Future<Project> loadProject() async => _loadArchive(
    await _loadPackageArchiveUrl(package, version: version),
  );
}

Future<String> _loadPackageArchiveUrl(String packageName, {String? version}) async {
  final uri = Uri(
    scheme: 'https',
    host: 'pub.dev',
    pathSegments: [
      'api',
      'packages',
      packageName,
      if (version != null) ...['versions', version],
    ],
  );
  final failureMessage = 'Failed to load package $packageName${version == null ? '' : ' version $version'}';
  final response = await _getSourceResponse(uri, failureMessage: failureMessage);
  if (response.statusCode != 200) {
    throw ProjectSourceException('$failureMessage (${response.statusCode}).');
  }
  final Object? json = _decodeSourceJson(response.body);
  final Object? metadata = version == null && json is Map<String, Object?> ? json['latest'] : json;
  if (metadata is Map<String, Object?> && metadata['archive_url'] is String) {
    return metadata['archive_url'] as String;
  }
  throw const ProjectSourceException('Unexpected package response.');
}
