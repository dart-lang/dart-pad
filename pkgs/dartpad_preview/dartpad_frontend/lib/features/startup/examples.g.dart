// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// This file has been automatically generated - please do not edit it manually.

class Example {
  final String name;
  final String id;
  final String archivePath;
  final String entryPath;

  const Example({
    required this.name,
    required this.id,
    required this.archivePath,
    required this.entryPath,
  });

  @override
  String toString() => '$name ($id)';
}

abstract final class Examples {
  static const List<Example> snippets = [
    _dart,
    _flutter,
  ];

  static const List<Example> samples = [
    _counter,
  ];

  static const List<Example> all = [
    _dart,
    _flutter,
    _counter,
  ];

  static Example? getById(String? id) {
    for (final example in all) {
      if (example.id == id) {
        return example;
      }
    }
    return null;
  }

  static const Example defaultExample = _counter;
}

const _dart = Example(
  name: 'Dart snippet',
  id: 'dart',
  archivePath: 'examples/dart.tar.gz',
  entryPath: 'lib/main.dart',
);

const _flutter = Example(
  name: 'Flutter snippet',
  id: 'flutter',
  archivePath: 'examples/flutter.tar.gz',
  entryPath: 'lib/main.dart',
);

const _counter = Example(
  name: 'Counter',
  id: 'counter',
  archivePath: 'examples/counter.tar.gz',
  entryPath: 'lib/main.dart',
);
