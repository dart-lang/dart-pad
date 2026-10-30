// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of 'project_source.dart';

/// A generated Flutter API documentation sample selected by its identifier.
final class FlutterApiDocsProjectSource extends ProjectSource {
  /// Describes the Flutter API documentation sample.
  const FlutterApiDocsProjectSource(this.sampleId, {this.channel});

  /// The identifier used by the Flutter documentation snippet generator.
  final String sampleId;

  /// The Flutter API docs host to use. Null selects the stable host.
  final FlutterApiChannel? channel;

  /// The public URL from which the generated Dart source is downloaded.
  Uri get snippetUri {
    final host = channel == FlutterApiChannel.main ? 'main-api.flutter.dev' : 'api.flutter.dev';
    return Uri(
      scheme: 'https',
      host: host,
      pathSegments: ['snippets', '$sampleId.dart'],
    );
  }

  @override
  Future<Project> loadProject() async {
    if (sampleId.isEmpty) {
      throw ArgumentError.value(sampleId, 'sampleId', 'must not be empty');
    }
    final response = await http.get(snippetUri);
    if (response.statusCode != 200) {
      throw Exception('Failed to load Flutter API sample $sampleId (${response.statusCode})');
    }

    final main = ProjectFile(path: 'lib/main.dart', bytes: response.bodyBytes);
    // Startup generates the pubspec after selecting the runtime SDK.
    return Project([main]);
  }
}
