// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

const dartRevision = '682f45325f17dc10c33dd07c485256154715ddb9';
const flutterRevision = 'd776076fe2f7470f4da43cc6084137e5bbe35b6d';

Future<void> main(List<String> args) async {
  final packageRoot = Directory.current.absolute;
  final webRoot = Directory(p.join(packageRoot.path, 'web'));
  final assetRoot = Directory(p.join(webRoot.path, 'dartpad'));
  if (args.length == 1 && args.single == '--validate-only') {
    await _validateManifest(assetRoot);
    return;
  }
  if (args.length == 1 && args.single == '--write-manifest') {
    await _writeManifest(assetRoot);
    await _validateManifest(assetRoot);
    return;
  }
  if (args.length != 2) {
    stderr.writeln(
      'Usage: dart run tool/build_sdk_assets.dart <dart-sdk-checkout> <flutter-checkout>\n'
      '   or: dart run tool/build_sdk_assets.dart --write-manifest\n'
      '   or: dart run tool/build_sdk_assets.dart --validate-only',
    );
    exitCode = 64;
    return;
  }

  final dartRoot = Directory(args[0]).absolute;
  final flutterRoot = Directory(args[1]).absolute;
  await _requireRevision(dartRoot, dartRevision, 'Dart SDK');
  await _requireRevision(flutterRoot, flutterRevision, 'Flutter');

  await _run(
    Platform.isWindows ? 'python' : p.join(dartRoot.path, 'tools', 'build.py'),
    [
      if (Platform.isWindows) p.join(dartRoot.path, 'tools', 'build.py'),
      '-m',
      'release',
      '-a',
      'x64',
      'dartpad',
      '--no-verify-sdk-hash',
    ],
    workingDirectory: dartRoot.path,
  );

  final configuration = 'ReleaseX64';
  final buildRoot = Directory(p.join(dartRoot.path, Platform.isMacOS ? 'xcodebuild' : 'out', configuration));
  final builtDart = p.join(
    buildRoot.path,
    'dart-sdk',
    'bin',
    Platform.isWindows ? 'dart.exe' : 'dart',
  );
  await _run(
    builtDart,
    ['pkg/dartpad_worker/tool/setup_local_flutter.dart'],
    workingDirectory: dartRoot.path,
    environment: {...Platform.environment, 'FLUTTER_ROOT': flutterRoot.path},
  );

  final flutterAssets = Directory(
    p.join(
      dartRoot.path,
      'pkg',
      'dartpad_worker',
      '.dart_tool',
      'dartpad_worker',
      'asset',
      'flutter',
    ),
  );
  await assetRoot.create(recursive: true);

  final flutterTarget = Directory(p.join(assetRoot.path, 'flutter'));
  if (!_isInside(assetRoot, flutterTarget)) {
    throw StateError('Refusing to replace an asset directory outside web/dartpad/.');
  }
  if (flutterTarget.existsSync()) {
    flutterTarget.deleteSync(recursive: true);
  }
  await _copyDirectory(flutterAssets, flutterTarget);
  await _writeManifest(assetRoot);
  await _validateManifest(assetRoot);
}

Future<void> _requireRevision(Directory root, String expected, String label) async {
  final result = await Process.run('git', ['rev-parse', 'HEAD'], workingDirectory: root.path);
  final actual = (result.stdout as String).trim();
  if (result.exitCode != 0 || actual != expected) {
    throw StateError('$label must be checked out at $expected (found $actual).');
  }
}

Future<void> _run(
  String executable,
  List<String> arguments, {
  required String workingDirectory,
  Map<String, String>? environment,
}) async {
  stdout.writeln('> $executable ${arguments.join(' ')}');
  final process = await Process.start(
    executable,
    arguments,
    workingDirectory: workingDirectory,
    environment: environment,
    mode: ProcessStartMode.inheritStdio,
    runInShell: Platform.isWindows,
  );
  final result = await process.exitCode;
  if (result != 0) {
    throw ProcessException(executable, arguments, 'Exited with $result', result);
  }
}

Future<void> _copyDirectory(Directory source, Directory target) async {
  if (!source.existsSync()) {
    throw StateError('Missing build output: ${source.path}');
  }
  await target.create(recursive: true);
  await for (final entity in source.list(recursive: false)) {
    final destination = p.join(target.path, p.basename(entity.path));
    if (entity is Directory) {
      await _copyDirectory(entity, Directory(destination));
    } else if (entity is File) {
      await entity.copy(destination);
    }
  }
}

bool _isInside(Directory parent, Directory child) {
  final relative = p.relative(child.absolute.path, from: parent.absolute.path);
  return relative != '..' && !relative.startsWith('..${p.separator}') && !p.isAbsolute(relative);
}

Future<List<File>> _assetFiles(Directory webRoot) async {
  final files = <File>[];
  final flutter = Directory(p.join(webRoot.path, 'flutter'));
  if (flutter.existsSync()) {
    await for (final entity in flutter.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        files.add(entity);
      }
    }
  }
  files.sort((a, b) => a.path.compareTo(b.path));
  return files;
}

Future<void> _writeManifest(Directory webRoot) async {
  final entries = <String, Object>{};
  for (final file in await _assetFiles(webRoot)) {
    final relative = p.posix.joinAll(p.split(p.relative(file.path, from: webRoot.path)));
    entries[relative] = {
      'bytes': await file.length(),
      'sha256': (await sha256.bind(file.openRead()).first).toString(),
    };
  }
  final manifest = {
    'schemaVersion': 1,
    'dartRevision': dartRevision,
    'flutterRevision': flutterRevision,
    'files': entries,
  };
  final encoder = const JsonEncoder.withIndent('  ');
  await File(p.join(webRoot.path, 'dartpad-assets.json')).writeAsString('${encoder.convert(manifest)}\n');
}

Future<void> _validateManifest(Directory webRoot) async {
  final manifestFile = File(p.join(webRoot.path, 'dartpad-assets.json'));
  if (!manifestFile.existsSync()) {
    throw StateError('Missing ${manifestFile.path}. Build the SDK assets first.');
  }
  final manifest = jsonDecode(await manifestFile.readAsString()) as Map<String, dynamic>;
  if (manifest['dartRevision'] != dartRevision || manifest['flutterRevision'] != flutterRevision) {
    throw StateError('Asset manifest SDK revisions do not match this source tree.');
  }
  final expected = (manifest['files'] as Map).cast<String, dynamic>();
  for (final entry in expected.entries) {
    final file = File(p.join(webRoot.path, p.joinAll(p.posix.split(entry.key))));
    if (!file.existsSync()) {
      throw StateError('Missing asset: ${entry.key}');
    }
    final metadata = (entry.value as Map).cast<String, dynamic>();
    final digest = (await sha256.bind(file.openRead()).first).toString();
    if (await file.length() != metadata['bytes'] || digest != metadata['sha256']) {
      throw StateError('Checksum mismatch: ${entry.key}');
    }
  }
  stdout.writeln('Validated ${expected.length} SDK assets.');
}
