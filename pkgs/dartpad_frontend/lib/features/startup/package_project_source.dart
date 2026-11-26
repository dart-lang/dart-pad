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
    response = await retry(
      () async {
        final response = await http.get(uri, headers: {'Accept': 'application/vnd.pub.v2+json'});
        if (response.statusCode == 408 ||
            response.statusCode == 429 ||
            (response.statusCode >= 500 && response.statusCode < 600)) {
          throw _RetryablePubResponse(response);
        }
        return response;
      },
      retryIf: (error) => error is http.ClientException || error is _RetryablePubResponse,
      maxAttempts: 4,
    );
  } on http.ClientException {
    throw ProjectSourceRetrievalException('Failed to GET package $packageDescription');
  } on _RetryablePubResponse catch (error) {
    throw PubPackageMetadataException(
      'pub.dev returned HTTP ${error.response.statusCode} for $packageDescription.',
    );
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

/// Carries a transient HTTP response through the retry loop.
final class _RetryablePubResponse implements Exception {
  const _RetryablePubResponse(this.response);

  final http.Response response;
}
