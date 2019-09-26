// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

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

final exerciseModeNames = <String, ExerciseMode>{
  'dart': ExerciseMode.dart,
  'html': ExerciseMode.html,
  'flutter': ExerciseMode.flutter,
};

/// Metadata for a single file within a larger exercise.
class ExerciseFileMetadata {
  String name;
  String alternatePath;

  String get path =>
      (alternatePath == null || alternatePath.isEmpty) ? name : alternatePath;

  ExerciseFileMetadata.fromJson(Map<String, dynamic> json) {
    if (json == null) {
      throw MetadataException('Null json was given to ExerciseFileMetadata().');
    }

    if (json['name'] == null ||
        json['name'] is! String ||
        json['name'].isEmpty) {
      throw MetadataException('The "name" field is required for each file.');
    }

    name = json['name'];
    alternatePath = json['alternatePath'];
  }
}

/// Represents the metadata for a single codelab exercise, as defined by the
/// exercise's `dartpad-metadata.json` file.
///
/// This data will be deserialized from that file when an exercise is loaded
/// from GitHub, and used to set up the DartPad environment for that exercise.
class ExerciseMetadata {
  String name;
  ExerciseMode mode;
  List<ExerciseFileMetadata> files;

  ExerciseMetadata.fromJson(Map<String, dynamic> json) {
    if (json == null) {
      throw MetadataException('Null json was given to ExerciseMetadata().');
    }

    if (json['name'] == null ||
        json['name'] is! String ||
        json['name'].isEmpty) {
      throw MetadataException('The "name" field is required for an exercise.');
    }

    if (json['mode'] == null ||
        json['mode'] is! String ||
        !exerciseModeNames.containsKey(json['mode'])) {
      throw MetadataException('A "mode" field of "dart", "html" or "flutter" '
          'is required for an exercise.');
    }

    if (json['files'] == null ||
        json['files'] is! List<dynamic> ||
        json['files'].isEmpty) {
      throw MetadataException('Each exercise must have at least one file in '
          'its "files" array.');
    }

    name = json['name'];
    mode = exerciseModeNames[json['mode']];
    files = (json['files'] as Iterable<dynamic>)
        .map((f) => ExerciseFileMetadata.fromJson(f))
        .toList();
  }
}
