// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Builds a deployable `build/` folder with the script (the CodeMirror bundle
/// followed by the compiled Dart), the stylesheets, the shared worker script,
/// the demo page and the DartPad SDK assets:
///
/// ```sh
/// dart run tool/build.dart [--sdk-assets=<dir>] [--output=<dir>]
/// ```
///
/// `--sdk-assets` defaults to the Dart SDK assets downloaded for the preview
/// frontend by `dartpad_frontend/tool/setup_sdk_assets.dart`.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

Future<void> main(List<String> args) async {
  final root = Directory.fromUri(Platform.script.resolve('..')).path;
  var sdkAssets = p.join(root, '..', 'dartpad_frontend', 'web', 'dartpad', 'dart');
  var output = p.join(root, 'build');
  for (final arg in args) {
    if (arg.startsWith('--sdk-assets=')) {
      sdkAssets = arg.substring('--sdk-assets='.length);
    } else if (arg.startsWith('--output=')) {
      output = arg.substring('--output='.length);
    } else {
      stderr.writeln('Unknown argument: $arg');
      exit(64);
    }
  }
  if (!Directory(sdkAssets).existsSync()) {
    stderr.writeln('No DartPad SDK assets at $sdkAssets, pass --sdk-assets=<dir>');
    exit(1);
  }

  if (Directory(output).existsSync()) {
    Directory(output).deleteSync(recursive: true);
  }
  Directory(output).createSync(recursive: true);
  final compiled = p.join(output, 'inline_dartpad.dart.js');
  await _run([
    'compile',
    'js',
    '-O2',
    '--no-source-maps',
    '-o',
    compiled,
    p.join(root, 'web', 'inline_dartpad.dart'),
  ], workingDirectory: root);
  File('$compiled.deps').deleteSync();

  // One script to include: the CodeMirror bundle, which the compiled Dart
  // expects at `window._codemirror`, followed by the compiled Dart.
  final codemirror = File(p.join(root, '..', 'codemirror-dart', 'lib', 'assets', 'codemirror-dart.bundle.js'));
  File(p.join(output, 'inline_dartpad.js')).writeAsStringSync(
    '${codemirror.readAsStringSync()}\n${File(compiled).readAsStringSync()}',
  );
  File(compiled).deleteSync();

  // The shared worker script comes from package:dartpad, so it matches the
  // DartPadSdk.sharedWorker in the compiled script.
  await _run([
    'run',
    'dartpad',
    'setup',
    'shared-worker',
    '-o',
    p.join(output, 'shared-worker.js'),
  ], workingDirectory: root);

  for (final name in ['index.html', 'inline_dartpad.css', 'themes.css']) {
    File(p.join(root, 'web', name)).copySync(p.join(output, name));
  }

  final sdkOutput = Directory(p.join(output, 'dartpad', 'dart'))..createSync(recursive: true);
  for (final file in Directory(sdkAssets).listSync().whereType<File>()) {
    // Source maps are not worth the download for a documentation site.
    if (file.path.endsWith('.map')) {
      continue;
    }
    file.copySync(p.join(sdkOutput.path, p.basename(file.path)));
  }
  stdout.writeln('Built $output');
}

Future<void> _run(List<String> arguments, {required String workingDirectory}) async {
  final process = await Process.start(
    Platform.resolvedExecutable,
    arguments,
    workingDirectory: workingDirectory,
    mode: ProcessStartMode.inheritStdio,
  );
  if (await process.exitCode != 0) {
    exit(1);
  }
}
