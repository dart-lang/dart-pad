// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:args/args.dart';
import 'package:path/path.dart' as p;

void main(List<String> args) {
  final argParser = ArgParser()
    ..addFlag(
      'help',
      abbr: 'h',
      negatable: false,
      help: 'Display this help output.',
    );

  final argResults = argParser.parse(args);

  if (argResults['help'] as bool) {
    print(argParser.usage);
    exit(0);
  }

  final builder = ExamplesBuilder();
  builder.parse();
  builder.generate();
}

const Set<String> validCategories = {'Snippet', 'Sample'};

class ExampleConfig implements Comparable<ExampleConfig> {
  final String category;
  final String id;
  final String name;
  final String projectDir;
  final String entryPath;

  ExampleConfig({
    required this.category,
    required this.id,
    required this.name,
    required this.projectDir,
    required this.entryPath,
  });

  factory ExampleConfig.fromJson(Map<String, Object?> json) {
    return ExampleConfig(
      category: json['category'] as String,
      id: json['id'] as String,
      name: json['name'] as String,
      projectDir: json['projectDir'] as String,
      entryPath: json['entryPath'] as String? ?? 'lib/main.dart',
    );
  }

  String get archiveFileName => '$id.tar.gz';
  String get archiveRelativeUrl => 'examples/$archiveFileName';

  String get varName {
    var gen = id;
    while (gen.contains('-')) {
      final index = gen.indexOf('-');
      gen = gen.substring(0, index) + gen.substring(index + 1, index + 2).toUpperCase() + gen.substring(index + 2);
    }
    return '_$gen';
  }

  String get sourceDef {
    return '''
const $varName = Example(
  name: '$name',
  id: '$id',
  archivePath: '$archiveRelativeUrl',
  entryPath: '$entryPath',
);
''';
  }

  @override
  int compareTo(ExampleConfig other) {
    if (category == other.category) {
      return name.compareTo(other.name);
    } else {
      return category.compareTo(other.category);
    }
  }
}

class ExamplesBuilder {
  late final List<ExampleConfig> samples;
  static const _webExamplesDir = '../dartpad_frontend/web/examples';
  static const _generatedCodePath = '../dartpad_frontend/lib/features/startup/examples.g.dart';

  void parse() {
    final jsonFile = File(p.join('lib', 'examples.json'));
    if (!jsonFile.existsSync()) {
      stderr.writeln('lib/examples.json not found.');
      exit(1);
    }

    final json = jsonDecode(jsonFile.readAsStringSync()) as List;
    samples = json.map((j) => ExampleConfig.fromJson(j as Map<String, Object?>)).toList();

    var hadFailure = false;
    void fail(String message) {
      stderr.writeln(message);
      hadFailure = true;
    }

    final ids = <String>{};
    for (final sample in samples) {
      if (!RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$').hasMatch(sample.id)) {
        fail('Illegal example ID: ${sample.id}');
      } else if (!ids.add(sample.id)) {
        fail('Duplicate example ID: ${sample.id}');
      }

      if (!validCategories.contains(sample.category)) {
        fail('Unknown category: ${sample.category}');
      }

      final projectPath = p.join('lib', 'projects', sample.projectDir);
      if (!Directory(projectPath).existsSync()) {
        fail('Project directory $projectPath not found.');
      }

      final pubspecPath = p.join(projectPath, 'pubspec.yaml');
      if (!File(pubspecPath).existsSync()) {
        fail('pubspec.yaml missing in $projectPath.');
      }

      final entryFullPath = p.join(projectPath, sample.entryPath);
      if (!File(entryFullPath).existsSync()) {
        fail('Entry file ${sample.entryPath} missing in $projectPath.');
      }
    }

    for (final requiredId in ['dart', 'flutter', 'counter']) {
      if (!ids.contains(requiredId)) {
        fail('The $requiredId example is required.');
      }
    }

    if (hadFailure) {
      exit(1);
    }

    samples.sort();
  }

  void generate() {
    // 1. Pack tar.gz files
    final outputDir = Directory(_webExamplesDir);
    if (!outputDir.existsSync()) {
      outputDir.createSync(recursive: true);
    }

    for (final sample in samples) {
      final tarGzFile = File(p.join(outputDir.path, sample.archiveFileName));
      tarGzFile.writeAsBytesSync(_archiveBytes(sample));
      print('Packaged ${sample.id} -> ${tarGzFile.path}');
    }

    // 2. Generate examples.g.dart
    final codeFile = File(_generatedCodePath);
    codeFile.parent.createSync(recursive: true);
    codeFile.writeAsStringSync(_generateSourceContent());
    print('Wrote ${codeFile.path}');
  }

  String _generateSourceContent() {
    final buf = StringBuffer('''
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
  String toString() => '\$name (\$id)';
}

abstract final class Examples {
  static const List<Example> snippets = [
    ${_itemsForCategory('Snippet')},
  ];

  static const List<Example> samples = [
    ${_itemsForCategory('Sample')},
  ];

  static const List<Example> all = [
    ${samples.map((s) => s.varName).join(',\n    ')},
  ];

  static Example? getById(String? id) {
    for (final sample in all) {
      if (sample.id == id) {
        return sample;
      }
    }
    return null;
  }

  static const Example defaultExample = _counter;
}

''');

    buf.write(samples.map((sample) => sample.sourceDef).join('\n'));
    return _normalizeLineEndings(buf.toString());
  }

  String _itemsForCategory(String category) {
    final items = samples.where((s) => s.category == category).toList();
    return items.map((item) => item.varName).join(',\n    ');
  }

  List<int> _archiveBytes(ExampleConfig sample) {
    final projectDir = Directory(p.join('lib', 'projects', sample.projectDir));
    final archive = Archive();

    for (final file in _projectFiles(projectDir)) {
      final relativePath = _relativeProjectPath(file, projectDir);
      final bytes = file.readAsBytesSync();
      archive.addFile(ArchiveFile(relativePath, bytes.length, bytes));
    }

    return const GZipEncoder().encode(TarEncoder().encode(archive));
  }

  List<File> _projectFiles(Directory projectDir) {
    final files = projectDir.listSync(recursive: true).whereType<File>().toList();
    files.sort((a, b) => _relativeProjectPath(a, projectDir).compareTo(_relativeProjectPath(b, projectDir)));
    return files;
  }

  String _relativeProjectPath(File file, Directory projectDir) =>
      p.relative(file.path, from: projectDir.path).replaceAll(r'\', '/');

  String _normalizeLineEndings(String value) => value.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
}
