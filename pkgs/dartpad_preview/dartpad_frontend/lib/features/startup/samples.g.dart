// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// This file has been automatically generated - please do not edit it manually.

class Sample {
  final String name;
  final String id;
  final String archivePath;
  final String entryPath;

  const Sample({
    required this.name,
    required this.id,
    required this.archivePath,
    required this.entryPath,
  });

  @override
  String toString() => '$name ($id)';
}

abstract final class Samples {
  static const List<Sample> create = [
    _dart,
    _flutter,
  ];

  static const List<Sample> examples = [
    _counter,
  ];

  static const List<Sample> all = [
    _dart,
    _flutter,
    _counter,
  ];

  static Sample? getById(String? id) {
    for (final sample in all) {
      if (sample.id == id) {
        return sample;
      }
    }
    return null;
  }

  static const Sample defaultSample = _counter;
}

const _dart = Sample(
  name: 'Dart snippet',
  id: 'dart',
  archivePath: 'samples/dart.tar.gz',
  entryPath: 'lib/main.dart',
);

const _flutter = Sample(
  name: 'Flutter snippet',
  id: 'flutter',
  archivePath: 'samples/flutter.tar.gz',
  entryPath: 'lib/main.dart',
);

const _counter = Sample(
  name: 'Counter',
  id: 'counter',
  archivePath: 'samples/counter.tar.gz',
  entryPath: 'lib/main.dart',
);
