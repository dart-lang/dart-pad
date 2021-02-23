import 'package:path/path.dart' as path;

/// Matches any path in the string and replaces the part of the path before the
/// last separator with either dart:core, package:flutter, or removes it.
///
/// ## Examples:
///
/// "Unused import: '/path/foo.dart'" -> "Unused import: 'foo.dart'"
///
/// "Unused import: '/path/to/dart/lib/world.dart'" -> "Unused import:
/// 'dart:core/world.dart'"
///
/// "Unused import: 'package:flutter/material.dart'" -> "Unused import:
/// 'package:flutter/material.dart'"
String stripFilePaths(String str) {
  // Match any URI. Also match URIs that are prefixed with dart:core or
  // package:*
  final regex = RegExp(r'(?:dart:core?)?(?:package:?)?[a-z]*\/\S*');

  return str.replaceAllMapped(regex, (match) {
    final urlString = match.group(0);
    final pathComponents = path.split(urlString);
    final isDartPath =
        pathComponents.contains('lib') && pathComponents.contains('core');

    // matches the 'flutter' package in the SDK
    final isFlutterPath = pathComponents.contains('flutter');

    final isPackagePath = urlString.contains('package:');
    final isDartCorePath = urlString.contains('dart:core');
    final basename = path.basename(urlString);

    if (isFlutterPath) {
      return path.join('package:flutter', basename);
    }

    if (isDartCorePath) {
      return urlString;
    }

    if (isDartPath) {
      return path.join('dart:core', basename);
    }

    if (isPackagePath) {
      return urlString;
    }
    return basename;
  });
}
