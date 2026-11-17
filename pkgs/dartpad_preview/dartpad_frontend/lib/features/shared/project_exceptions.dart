// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Pub.dev package metadata could not be loaded or was invalid.
final class PubPackageMetadataException implements Exception {
  const PubPackageMetadataException(this.message);

  final String message;
}

/// The requested package version was not present in pub.dev metadata.
final class PackageVersionNotFoundException implements Exception {
  const PackageVersionNotFoundException(this.message);

  final String message;
}
