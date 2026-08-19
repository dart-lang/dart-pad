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

  final builder = SamplesBuilder();
  builder.parse();
  builder.generate();
}

const Set<String> validCategories = {'Create', 'Examples'};

class SampleConfig implements Comparable<SampleConfig> {
  /// Top-level grouping, e.g. `"Create"` or `"Examples"`.
  final String category;

  /// Optional sub-grouping within [category], used as a divider label in the
  /// dropdown menu (e.g. `"Dart"`, `"Flutter"`, `"Ecosystem"`).
  final String? subcategory;

  /// Unique kebab-case identifier for the sample (e.g. `"hello-world"`).
  final String id;

  /// Human-readable display name shown in the UI.
  final String name;

  /// Directory name under `lib/projects/` that contains the sample source.
  final String projectDir;

  /// Relative path to the main entry file within the project archive.
  final String entryPath;

  /// Optional path to a logo image served from the web root
  /// (e.g. `"images/flutter_logo_192.png"`).
  final String? icon;

  /// Original position in `samples.json`, used to preserve declaration order
  /// when sorting within a [category].
  final int index;

  SampleConfig({
    required this.category,
    this.subcategory,
    required this.id,
    required this.name,
    required this.projectDir,
    required this.entryPath,
    this.icon,
    this.index = 0,
  });

  factory SampleConfig.fromJson(Map<String, Object?> json, {int index = 0}) {
    return SampleConfig(
      category: json['category'] as String,
      subcategory: json['subcategory'] as String?,
      id: json['id'] as String,
      name: json['name'] as String,
      projectDir: json['projectDir'] as String,
      entryPath: json['entryPath'] as String? ?? 'lib/main.dart',
      icon: json['icon'] as String?,
      index: index,
    );
  }

  String get archiveFileName => '$id.tar.gz';
  String get archiveRelativeUrl => 'samples/$archiveFileName';

  String get varName {
    var gen = id;
    while (gen.contains('-')) {
      final index = gen.indexOf('-');
      gen = gen.substring(0, index) + gen.substring(index + 1, index + 2).toUpperCase() + gen.substring(index + 2);
    }
    return '_$gen';
  }

  String get sourceDef {
    final buf = StringBuffer('const $varName = Sample(\n');
    buf.writeln("  name: '$name',");
    buf.writeln("  id: '$id',");
    if (subcategory != null) {
      buf.writeln("  subcategory: '$subcategory',");
    }
    if (icon != null) {
      buf.writeln("  icon: '$icon',");
    }
    buf.writeln("  archivePath: '$archiveRelativeUrl',");
    buf.writeln("  entryPath: '$entryPath',");
    buf.write(');');
    return buf.toString();
  }

  @override
  int compareTo(SampleConfig other) {
    if (category != other.category) {
      return category.compareTo(other.category);
    }
    return index.compareTo(other.index);
  }
}

class SamplesBuilder {
  late final List<SampleConfig> samples;
  static const _webSamplesDir = '../dartpad_frontend/web/samples';
  static const _generatedCodePath = '../dartpad_frontend/lib/features/startup/samples.g.dart';

  void parse() {
    final jsonFile = File(p.join('lib', 'samples.json'));
    if (!jsonFile.existsSync()) {
      stderr.writeln('lib/samples.json not found.');
      exit(1);
    }

    final json = jsonDecode(jsonFile.readAsStringSync()) as List;
    samples = [
      for (final (i, j) in json.indexed) SampleConfig.fromJson(j as Map<String, Object?>, index: i),
    ];

    var hadFailure = false;
    void fail(String message) {
      stderr.writeln(message);
      hadFailure = true;
    }

    final ids = <String>{};
    for (final sample in samples) {
      if (!RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$').hasMatch(sample.id)) {
        fail('Illegal sample ID: ${sample.id}');
      } else if (!ids.add(sample.id)) {
        fail('Duplicate sample ID: ${sample.id}');
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
        fail('The $requiredId sample is required.');
      }
    }

    if (hadFailure) {
      exit(1);
    }

    samples.sort();
  }

  void generate() {
    // 1. Pack tar.gz files
    final outputDir = Directory(_webSamplesDir);
    if (!outputDir.existsSync()) {
      outputDir.createSync(recursive: true);
    }

    for (final sample in samples) {
      final tarGzFile = File(p.join(outputDir.path, sample.archiveFileName));
      tarGzFile.writeAsBytesSync(_archiveBytes(sample));
      print('Packaged ${sample.id} -> ${tarGzFile.path}');
    }

    // 2. Generate samples.g.dart
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

class Sample {
  final String name;
  final String id;
  final String? subcategory;
  final String? icon;
  final String archivePath;
  final String entryPath;

  const Sample({
    required this.name,
    required this.id,
    this.subcategory,
    this.icon,
    required this.archivePath,
    required this.entryPath,
  });

  @override
  String toString() => '\$name (\$id)';
}

abstract final class Samples {
  static const List<Sample> create = [
    ${_itemsForCategory('Create')},
  ];

  static const List<Sample> examples = [
    ${_itemsForCategory('Examples')},
  ];

  static const List<Sample> all = [
    ${samples.map((s) => s.varName).join(',\n    ')},
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

''');

    buf.write(samples.map((sample) => sample.sourceDef).join('\n'));
    buf.writeln();
    return _normalizeLineEndings(buf.toString());
  }

  String _itemsForCategory(String category) {
    final items = samples.where((s) => s.category == category).toList();
    return items.map((item) => item.varName).join(',\n    ');
  }

  List<int> _archiveBytes(SampleConfig sample) {
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
