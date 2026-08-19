// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dartpad_editor/dartpad_editor.dart';

import 'archive_loader.dart';
import 'project_loader.dart';
import 'samples.g.dart';

final class SampleLoadFailure {
  const SampleLoadFailure({
    required this.message,
    required this.error,
    required this.stackTrace,
  });

  final String message;
  final Object error;
  final StackTrace stackTrace;
}

typedef SampleLoadFailureHandler = void Function(SampleLoadFailure failure);

/// Loads a sample project from its packaged archive into [root].
Future<LoadedProject> loadSampleProject(
  WorkspaceFolder root, {
  String? sampleId,
  SampleLoadFailureHandler? onFailure,
}) async {
  final requestedSample = Samples.getById(sampleId);
  if (sampleId != null && requestedSample == null) {
    onFailure?.call(
      SampleLoadFailure(
        message: 'Error while loading $sampleId sample, falling back to counter sample.',
        error: ArgumentError.value(sampleId, 'sampleId', 'Unknown sample ID'),
        stackTrace: StackTrace.current,
      ),
    );
  }

  final sample = requestedSample ?? Samples.defaultSample;
  final loader = ArchiveLoader(
    archiveUrl: sample.archivePath,
    filePath: sample.entryPath,
  );

  try {
    return await loader.loadArchive(root);
  } catch (error, stackTrace) {
    onFailure?.call(
      SampleLoadFailure(
        message: 'Error while loading ${sample.id} sample, falling back to counter sample.',
        error: error,
        stackTrace: stackTrace,
      ),
    );
    await createFallbackSampleProject(root);
    return const LoadedProject(
      projectDir: '',
      entryPath: sampleProjectEntryPath,
      packageRoot: '',
    );
  }
}

/// The default entry path for sample projects.
const String sampleProjectEntryPath = 'lib/main.dart';

/// Opens the default sample files and leaves the Dart source active.
Future<void> openSampleProject(Future<void> Function(String path) openFile) {
  return openFile(sampleProjectEntryPath);
}

/// Creates the files for the default DartPad sample project (fallback).
Future<void> createFallbackSampleProject(WorkspaceFolder root) async {
  await root.getFolder('lib').create();
  await root.getFile(_samplePubspecPath).writeContent(samplePubspec.trimLeft());
  await root.getFile(_sampleAnalysisOptionsPath).writeContent(sampleAnalysisOptions.trimLeft());
  await root.getFile(sampleProjectEntryPath).writeContent(sampleMainDart.trimLeft());
}

const String _sampleAnalysisOptionsPath = 'analysis_options.yaml';
const String _samplePubspecPath = 'pubspec.yaml';

/// The initial Dart source for the default sample project fallback.
const String sampleMainDart = r'''
import 'package:flutter/material.dart';

void main() {
  runApp(const CounterApp());
}

class CounterApp extends StatelessWidget {
  const CounterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Counter',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const CounterPage(title: 'Flutter Demo Home Page'),
    );
  }
}

class CounterPage extends StatefulWidget {
  const CounterPage({super.key, required this.title});

  final String title;

  @override
  State<CounterPage> createState() => _CounterPageState();
}

class _CounterPageState extends State<CounterPage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text('You have pushed the button this many times:'),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
''';

/// The initial pubspec for the default sample project fallback.
const String samplePubspec = '''
name: counter_app
description: A simple counter app.
publish_to: none
version: 1.0.0+1

environment:
    sdk: ^3.12.0

dependencies:
  flutter:
    sdk: flutter

dev_dependencies:
  flutter_lints: ^6.0.0

flutter:
  uses-material-design: true
''';

const String sampleAnalysisOptions = '''
# This file configures the analyzer, which statically analyzes Dart code to
# check for errors, warnings, and lints.
#
# The issues identified by the analyzer are surfaced in the UI.
#
# For more information, see: https://dart.dev/guides/language/analysis-options

include: package:flutter_lints/flutter.yaml

# linter:
#   rules:
#     # avoid_print: false # Uncomment to disable the `avoid_print` rule
#     # prefer_single_quotes: true # Uncomment to enable the `prefer_single_quotes` rule
''';
