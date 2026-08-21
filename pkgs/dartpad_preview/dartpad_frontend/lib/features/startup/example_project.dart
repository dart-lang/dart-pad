// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dartpad_editor/dartpad_editor.dart';

import 'archive_loader.dart';
import 'project_loader.dart';
import 'examples.g.dart';

final class ExampleLoadFailure {
  const ExampleLoadFailure({
    required this.message,
    required this.error,
    required this.stackTrace,
  });

  final String message;
  final Object error;
  final StackTrace stackTrace;
}

typedef ExampleLoadFailureHandler = void Function(ExampleLoadFailure failure);

/// Loads an example project from its packaged archive into [root].
Future<LoadedProject> loadExampleProject(
  WorkspaceFolder root, {
  String? sampleId,
  ExampleLoadFailureHandler? onFailure,
}) async {
  final requestedSample = Examples.getById(sampleId);
  if (sampleId != null && requestedSample == null) {
    onFailure?.call(
      ExampleLoadFailure(
        message: 'Error while loading $sampleId example, falling back to counter example.',
        error: ArgumentError.value(sampleId, 'sampleId', 'Unknown example ID'),
        stackTrace: StackTrace.current,
      ),
    );
  }

  final sample = requestedSample ?? Examples.defaultExample;
  final loader = ArchiveLoader(
    archiveUrl: sample.archivePath,
    filePath: sample.entryPath,
  );

  try {
    return await loader.loadArchive(root);
  } catch (error, stackTrace) {
    onFailure?.call(
      ExampleLoadFailure(
        message: 'Error while loading ${sample.id} example, falling back to counter example.',
        error: error,
        stackTrace: stackTrace,
      ),
    );
    await createFallbackExampleProject(root);
    return const LoadedProject(
      projectDir: '',
      entryPath: exampleProjectEntryPath,
      packageRoot: '',
    );
  }
}

/// The default entry path for example projects.
const String exampleProjectEntryPath = 'lib/main.dart';

/// Opens the default example files and leaves the Dart source active.
Future<void> openExampleProject(Future<void> Function(String path) openFile) {
  return openFile(exampleProjectEntryPath);
}

/// Creates the files for the default DartPad example project (fallback).
Future<void> createFallbackExampleProject(WorkspaceFolder root) async {
  await root.getFolder('lib').create();
  await root.getFile(_fallbackPubspecPath).writeContent(fallbackPubspec.trimLeft());
  await root.getFile(_fallbackAnalysisOptionsPath).writeContent(fallbackAnalysisOptions.trimLeft());
  await root.getFile(exampleProjectEntryPath).writeContent(fallbackMainDart.trimLeft());
}

const String _fallbackAnalysisOptionsPath = 'analysis_options.yaml';
const String _fallbackPubspecPath = 'pubspec.yaml';

/// The initial Dart source for the default example project fallback.
const String fallbackMainDart = r'''
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

/// The initial pubspec for the default example project fallback.
const String fallbackPubspec = '''
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

const String fallbackAnalysisOptions = '''
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
