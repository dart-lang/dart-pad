// Copyright 2023 the Dart project authors. All rights reserved.
// Use of this source code is governed by a BSD-style license
// that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;

void main(List<String> args) {
  final argParser = ArgParser()
    ..addFlag('verify',
        negatable: false, help: 'Verify the generated samples files.')
    ..addFlag('help',
        abbr: 'h', negatable: false, help: 'Display this help output.');

  final argResults = argParser.parse(args);

  if (argResults['help'] as bool) {
    print(argParser.usage);
    exit(0);
  }

  final samples = Samples();
  samples.parse();
  if (argResults['verify'] as bool) {
    samples.verifyGeneration();
  } else {
    samples.generate();
  }
}

const Set<String> categories = {
  'Dart',
  'Flutter',
};

class Samples {
  late final Map<String, String> defaults;
  late final List<Sample> samples;

  void parse() {
    // read the samples
    var json =
        jsonDecode(File(p.join('lib', 'samples.json')).readAsStringSync());

    defaults = (json['defaults'] as Map).cast<String, String>();
    samples = (json['samples'] as List).map((j) => Sample.fromJson(j)).toList();

    // do basic validation
    var hadFailure = false;
    void fail(String message) {
      stderr.writeln(message);
      hadFailure = true;
    }

    for (var entry in defaults.entries) {
      if (!File(entry.value).existsSync()) {
        fail('File ${entry.value} not found.');
      }
    }

    for (var sample in samples) {
      print(sample);

      if (sample.id.contains(' ')) {
        fail('Illegal chars in sample ID.');
      }

      if (!File(sample.path).existsSync()) {
        fail('File ${sample.path} not found.');
      }

      if (!categories.contains(sample.category)) {
        fail('Unknown category: ${sample.category}');
      }

      if (samples.where((s) => s.id == sample.id).length > 1) {
        fail('Duplicate sample id: ${sample.id}');
      }
    }

    if (hadFailure) {
      exit(1);
    }

    samples.sort();
  }

  void generate() {
    // readme.md
    var readme = File('README.md');
    readme.writeAsStringSync(_generateReadmeContent());

    // print generation message
    print('');
    print('Wrote ${readme.path}');

    // samples.g.dart
    var codeFile = File('../sketch_pad/lib/samples.g.dart');
    var contents = _generateSourceContent();
    codeFile.writeAsStringSync(contents);
    print('Wrote ${codeFile.path}');
  }

  void verifyGeneration() {
    print('');

    print('Verifying sample file generation...');

    var readme = File('README.md');
    if (readme.readAsStringSync() != _generateReadmeContent()) {
      stderr.writeln('Generated sample files not up-to-date.');
      stderr.writeln('Re-generate by running:');
      stderr.writeln('');
      stderr.writeln('  dart tool/samples.dart');
      stderr.writeln('');
      exit(1);
    }

    // print success message
    print('Generated files up-to-date');
  }

  String _generateReadmeContent() {
    const marker = '<!-- samples -->';

    var contents = File('README.md').readAsStringSync();
    var table = _generateTable();

    return contents.substring(0, contents.indexOf(marker) + marker.length + 1) +
        table +
        contents.substring(contents.lastIndexOf(marker));
  }

  String _generateTable() {
    return '''
| Category | Name | Sample | ID |
| --- | --- | --- | --- |
${samples.map((s) => s.toTableRow()).join('\n')}
''';
  }

  String _generateSourceContent() {
    var buf = StringBuffer('''
// Copyright 2023 the Dart project authors. All rights reserved.
// Use of this source code is governed by a BSD-style license
// that can be found in the LICENSE file.

// This file has been automatically generated - please do not edit it manually.

import 'package:collection/collection.dart';

class Sample {
  final String category;
  final String name;
  final String id;
  final String source;

  Sample({
    required this.category,
    required this.name,
    required this.id,
    required this.source,
  });

  bool get isDart => category == 'Dart';

  @override
  String toString() => '[\$category] \$name (\$id)';
}

class Samples {
  static final List<Sample> all = [
    ${samples.map((s) => s.sourceId).join(',\n    ')},
  ];

  static final Map<String, List<Sample>> categories = {
    ${categories.map((category) => _mapForCategory(category)).join(',\n    ')},
  };

  static Sample? getById(String? id) => all.firstWhereOrNull((s) => s.id == id);

  static String getDefault({required String type}) => _defaults[type]!;
}

''');

    buf.writeln('Map<String, String> _defaults = {');

    for (var entry in defaults.entries) {
      var source = File(entry.value).readAsStringSync().trimRight();
      buf.writeln("  '${entry.key}': r'''\n$source\n''',");
    }

    buf.writeln('};\n');

    buf.write(samples.map((sample) => sample.sourceDef).join('\n'));

    return buf.toString();
  }

  String _mapForCategory(String category) {
    var items = samples.where((s) => s.category == category);
    return ''''$category': [
      ${items.map((i) => i.sourceId).join(',\n      ')},
    ]''';
  }
}

class Sample implements Comparable<Sample> {
  final String category;
  final String name;
  final String id;
  final String path;

  Sample({
    required this.category,
    required this.name,
    required this.id,
    required this.path,
  });

  factory Sample.fromJson(Map json) {
    return Sample(
      category: json['category'],
      name: json['name'],
      id: (json['id'] as String?) ?? _idFromName(json['name']),
      path: json['path'],
    );
  }

  String get sourceId {
    var gen = id;
    while (gen.contains('-')) {
      var index = id.indexOf('-');
      gen = gen.substring(0, index) +
          gen.substring(index + 1, index + 2).toUpperCase() +
          gen.substring(index + 2);
    }
    return '_$gen';
  }

  String get source => File(path).readAsStringSync();

  String get sourceDef {
    return '''
final $sourceId = Sample(
  category: '$category',
  name: '$name',
  id: '$id',
  source: r\'\'\'
${source.trimRight()}
\'\'\',
);
''';
  }

  String toTableRow() =>
      '| $category | $name | [${p.basename(path)}]($path) | `$id` |';

  @override
  int compareTo(Sample other) {
    if (category == other.category) {
      return name.compareTo(other.name);
    } else {
      return category.compareTo(other.category);
    }
  }

  @override
  String toString() => '[$category] $name ($id)';

  static String _idFromName(String name) =>
      name.trim().toLowerCase().replaceAll(' ', '-');
}
