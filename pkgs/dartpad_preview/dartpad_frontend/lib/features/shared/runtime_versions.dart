// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:http/http.dart' as http;

/// The Dart and Flutter versions bundled with the DartPad SDK assets.
final class RuntimeVersions {
  const RuntimeVersions({
    required this.dart,
    required this.flutter,
  });

  final String dart;
  final String flutter;

  /// Loads the versions recorded in the generated SDK asset manifest.
  static Future<RuntimeVersions?> load() async {
    try {
      final response = await http.get(
        Uri.base.resolve('dartpad/dartpad-assets.json'),
      );
      if (response.statusCode != 200) {
        return null;
      }
      return fromManifest(jsonDecode(response.body));
    } on FormatException {
      return null;
    }
  }

  /// Parses version fields from a decoded SDK asset manifest.
  static RuntimeVersions? fromManifest(Object? manifest) {
    if (manifest is! Map<String, dynamic>) {
      return null;
    }
    final dartVersion = manifest['dartVersion'];
    final flutterVersion = manifest['flutterVersion'];
    if (dartVersion is! String || flutterVersion is! String) {
      return null;
    }
    return RuntimeVersions(dart: dartVersion, flutter: flutterVersion);
  }
}
