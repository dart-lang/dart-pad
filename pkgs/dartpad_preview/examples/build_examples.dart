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

enum ExampleCategory {
  snippet('Snippet'),
  sample('Sample');

  const ExampleCategory(this.label);
  final String label;
}

class ExampleConfig implements Comparable<ExampleConfig> {
  final ExampleCategory category;
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
      category: ExampleCategory.values.firstWhere(
        (c) => c.label == json['category'] as String,
        orElse: () => throw FormatException('Unknown category: ${json['category']}'),
      ),
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
      return category.label.compareTo(other.category.label);
    }
  }
}

class ExamplesBuilder {
  late final List<ExampleConfig> examples;
  static const _webExamplesDir = '../dartpad_frontend/web/examples';
  static const _generatedCodePath = '../dartpad_frontend/lib/features/startup/examples.g.dart';

  void parse() {
    final jsonFile = File('examples.json');
    if (!jsonFile.existsSync()) {
      stderr.writeln('examples.json not found.');
      exit(1);
    }

    final json = jsonDecode(jsonFile.readAsStringSync()) as List;
    examples = json.map((j) => ExampleConfig.fromJson(j as Map<String, Object?>)).toList();

    var hadFailure = false;
    void fail(String message) {
      stderr.writeln(message);
      hadFailure = true;
    }

    final ids = <String>{};
    for (final example in examples) {
      if (!RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$').hasMatch(example.id)) {
        fail('Illegal example ID: ${example.id}');
      } else if (!ids.add(example.id)) {
        fail('Duplicate example ID: ${example.id}');
      }

      final projectPath = example.projectDir;
      if (!Directory(projectPath).existsSync()) {
        fail('Project directory $projectPath not found.');
      }

      final pubspecPath = p.join(projectPath, 'pubspec.yaml');
      if (!File(pubspecPath).existsSync()) {
        fail('pubspec.yaml missing in $projectPath.');
      }

      final entryFullPath = p.join(projectPath, example.entryPath);
      if (!File(entryFullPath).existsSync()) {
        fail('Entry file ${example.entryPath} missing in $projectPath.');
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

    examples.sort();
  }

  void generate() {
    // 1. Pack tar.gz files
    final outputDir = Directory(_webExamplesDir);
    if (!outputDir.existsSync()) {
      outputDir.createSync(recursive: true);
    }

    for (final example in examples) {
      final tarGzFile = File(p.join(outputDir.path, example.archiveFileName));
      tarGzFile.writeAsBytesSync(_archiveBytes(example));
      print('Packaged ${example.id} -> ${tarGzFile.path}');
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

import 'example.dart';

abstract final class Examples {
  static const List<Example> snippets = [
    ${_itemsForCategory(ExampleCategory.snippet)},
  ];

  static const List<Example> samples = [
    ${_itemsForCategory(ExampleCategory.sample)},
  ];

  static const List<Example> all = [
    ${examples.map((s) => s.varName).join(',\n    ')},
  ];

  static Example? getById(String id) {
    for (final example in all) {
      if (example.id == id) {
        return example;
      }
    }
    return null;
  }

  static const Example defaultExample = _counter;
}

''');

    buf.write(examples.map((e) => e.sourceDef).join('\n'));
    return _normalizeLineEndings(buf.toString());
  }

  String _itemsForCategory(ExampleCategory category) {
    final items = examples.where((s) => s.category == category).toList();
    return items.map((item) => item.varName).join(',\n    ');
  }

  List<int> _archiveBytes(ExampleConfig example) {
    final projectDir = Directory(example.projectDir);
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
