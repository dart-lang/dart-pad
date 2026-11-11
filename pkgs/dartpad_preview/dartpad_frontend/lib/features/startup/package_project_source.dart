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
  final packageDescription = '$packageName${version == null ? '' : ' version $version'}';
  final uri = Uri(
    scheme: 'https',
    host: 'pub.dev',
    pathSegments: ['api', 'packages', packageName],
  );
  final http.Response response;
  try {
    response = await http.get(uri, headers: {'Accept': 'application/vnd.pub.v2+json'});
  } on http.ClientException {
    throw PubPackageMetadataException('pub.dev is unreachable for $packageDescription.');
  }
  if (response.statusCode != 200) {
    throw PubPackageMetadataException(
      'pub.dev returned HTTP ${response.statusCode} for $packageDescription.',
    );
  }
  final Object? json;
  try {
    json = jsonDecode(response.body);
  } on FormatException {
    throw PubPackageMetadataException('pub.dev returned invalid JSON for $packageDescription.');
  }
  if (json is! Map<String, Object?>) {
    throw PubPackageMetadataException('pub.dev returned an unexpected response for $packageDescription.');
  }
  final Object? metadata;
  if (version == null) {
    metadata = json['latest'];
  } else {
    final versions = json['versions'];
    if (versions is! List<Object?> ||
        versions.any((entry) => entry is! Map<String, Object?> || entry['version'] is! String)) {
      throw PubPackageMetadataException('pub.dev returned an unexpected response for $packageDescription.');
    }
    metadata = versions.whereType<Map<String, Object?>>().where((entry) => entry['version'] == version).firstOrNull;
    if (metadata == null) {
      throw PackageVersionNotFoundException('$packageName version $version');
    }
  }
  if (metadata is Map<String, Object?> && metadata['archive_url'] is String) {
    return metadata['archive_url'] as String;
  }
  throw PubPackageMetadataException('pub.dev returned an unexpected response for $packageDescription.');
}
