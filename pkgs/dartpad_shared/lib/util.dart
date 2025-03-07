// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:meta/meta.dart';

/// Whether [imports] denote use of Flutter Web.
bool usesFlutterWeb(List<String> imports) => imports.any(isFlutterWebImport);

bool usesPackageWeb(List<String> imports) {
  return imports.any(
    (i) => _packageNameFromPackageUri(i)?.contains('web') ?? false,
  );
}

bool isSupportedFlutterPackage(String package) =>
    _packagesIndicatingFlutter.contains(package);

/// Whether the [importString] represents an import that denotes use of Flutter
/// Web.
@visibleForTesting
bool isFlutterWebImport(String? importString) {
  if (importString == null) return false;
  if (importString == 'dart:ui') return true;

  final packageName = _packageNameFromPackageUri(importString);
  return packageName != null &&
      _packagesIndicatingFlutter.contains(packageName);
}

/// If [uriString] represents a 'package:' URI, then returns the package name;
/// otherwise `null`.
String? _packageNameFromPackageUri(String uriString) {
  final uri = Uri.tryParse(uriString);
  if (uri == null) return null;
  if (uri.scheme != 'package') return null;
  if (uri.pathSegments.isEmpty) return null;
  return uri.pathSegments.first;
}

/// The set of supported Flutter-oriented packages.
const Set<String> supportedFlutterPackages = {
  'animations',
  'creator',
  'flame',
  'flame_fire_atlas',
  'flame_forge2d',
  'flame_splash_screen',
  'flame_tiled',
  'flutter_adaptive_scaffold',
  'flutter_bloc',
  'flutter_hooks',
  'flutter_map',
  'flutter_markdown',
  'flutter_riverpod',
  'flutter_svg',
  'go_router',
  'google_fonts',
  'google_generative_ai',
  'hooks_riverpod',
  'mix',
  'provider',
  'shared_preferences',
  'url_launcher',
  'video_player',
};

/// The set of packages which indicate that Flutter Web is being used.
const Set<String> _packagesIndicatingFlutter = {
  'flutter',
  'flutter_test',
  ...supportedFlutterPackages,
};
