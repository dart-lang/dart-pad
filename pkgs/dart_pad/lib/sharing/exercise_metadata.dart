// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:yaml/yaml.dart' as yaml;

/// An exception thrown when a metadata file has missing or invalid fields.
class MetadataException implements Exception {
  final String message;

  const MetadataException(this.message);
}

/// Modes for individual exercises.
///
/// The DartPad editors, output windows, and so on will be configured according
/// to this value.
enum ExerciseMode {
  dart,
  html,
  flutter,
}

const exerciseModeNames = <String, ExerciseMode>{
  'dart': ExerciseMode.dart,
  'html': ExerciseMode.html,
  'flutter': ExerciseMode.flutter,
};

/// Metadata for a single file within a larger exercise.
class ExerciseFileMetadata {
  late String name;
  late String alternatePath;

  String get path => alternatePath.isEmpty ? name : alternatePath;

  ExerciseFileMetadata.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      throw MetadataException('Null json was given to ExerciseFileMetadata().');
    }

    if (map['name'] == null ||
        map['name'] is! String ||
        (map['name'] as String).isEmpty) {
      throw MetadataException('The "name" field is required for each file.');
    }

    name = map.containsKey('name') ? map['name'] as String : '';
    alternatePath =
        map.containsKey('alternatePath') ? map['alternatePath'] as String : '';
  }
}

/// Represents the metadata for a single codelab exercise, as defined by the
/// exercise's `dartpad-metadata.json` file.
///
/// This data will be deserialized from that file when an exercise is loaded
/// from GitHub, and used to set up the DartPad environment for that exercise.
class ExerciseMetadata {
  late String name;
  late ExerciseMode mode;
  late List<ExerciseFileMetadata> files;

  ExerciseMetadata.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      throw MetadataException('Null json was given to ExerciseMetadata().');
    }

    if (map['name'] == null ||
        map['name'] is! String ||
        (map['name'] as String).isEmpty) {
      throw MetadataException('The "name" field is required for an exercise.');
    }

    if (map['mode'] == null ||
        map['mode'] is! String ||
        !exerciseModeNames.containsKey(map['mode'])) {
      throw MetadataException('A "mode" field of "dart", "html" or "flutter" '
          'is required for an exercise.');
    }

    if (map['files'] == null ||
        map['files'] is! List ||
        (map['files'] as List).isEmpty) {
      throw MetadataException('Each exercise must have at least one file in '
          'its "files" array.');
    }

    name = map['name'] as String;
    mode = exerciseModeNames[map['mode']]!;
    files = (map['files'] as yaml.YamlList)
        .map((f) => ExerciseFileMetadata.fromMap((f as yaml.YamlMap).cast()))
        .toList();
  }
}
