// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:meta/meta.dart';
import 'package:web/web.dart' as web;

/// Information about an available DartPad SDK/runtime.
@immutable
final class SdkInfo {
  const SdkInfo({
    required this.id,
    required this.name,
    required this.path,
    required this.dartVersion,
    this.flutterVersion,
    this.channel,
  });

  /// Unique identifier for this SDK runtime (e.g. `'flutter'`, `'dart'`).
  final String id;

  /// Human-readable display name for this SDK (e.g. `'Flutter'`, `'Dart'`).
  final String name;

  /// Relative path from the application base URI to this SDK's asset bundle directory (e.g. `'dartpad/flutter/'`).
  final String path;

  /// The version of the Dart SDK (e.g. `'3.14.0'`).
  final String dartVersion;

  /// The version of the Flutter SDK (e.g. `'3.48.0'`), or `null` if this is a pure Dart runtime.
  final String? flutterVersion;

  /// Release channel assigned to this runtime, independent of its pinned revision.
  final String? channel;

  bool get isFlutter => flutterVersion != null;

  /// Runtime versions for display, without prerelease or build suffixes.
  String get displayName {
    final dart = 'Dart ${_shortVersion(dartVersion)}';
    final flutter = flutterVersion;
    return flutter == null ? dart : 'Flutter ${_shortVersion(flutter)} • $dart';
  }

  static final _versionPattern = RegExp(r'^\d+\.\d+\.\d+');

  static String _shortVersion(String version) => _versionPattern.firstMatch(version)?.group(0) ?? version;

  /// Resolved base URL for this SDK's assets.
  Uri get assetBaseUrl => Uri.parse(web.document.baseURI).resolve(path);

  static SdkInfo? fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String?;
    final name = json['name'] as String?;
    final path = json['path'] as String?;
    final dartVersion = json['dartVersion'] as String?;
    final flutterVersion = json['flutterVersion'] as String?;
    if (id == null || name == null || path == null || dartVersion == null) {
      return null;
    }
    return SdkInfo(
      id: id,
      name: name,
      path: path,
      dartVersion: dartVersion,
      flutterVersion: flutterVersion,
      channel: json['channel'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'path': path,
    'dartVersion': dartVersion,
    if (flutterVersion != null) 'flutterVersion': flutterVersion,
    if (channel != null) 'channel': channel,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SdkInfo && runtimeType == other.runtimeType && id == other.id && path == other.path;

  @override
  int get hashCode => Object.hash(id, path);
}
