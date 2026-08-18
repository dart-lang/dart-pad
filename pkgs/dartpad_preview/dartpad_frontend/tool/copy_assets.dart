// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

Future<void> main(List<String> args) async {
  final packageUri = await Isolate.resolvePackageUri(
    Uri.parse('package:dartpad/dartpad.dart'),
  );
  if (packageUri == null) {
    stderr.writeln('Error: Could not resolve package:dartpad');
    exitCode = 1;
    return;
  }

  final packageDir = Directory.fromUri(packageUri.resolve('..'));
  final sourceWebDir = Directory(p.join(packageDir.path, 'web'));
  if (!sourceWebDir.existsSync()) {
    stderr.writeln('Error: Missing web/ directory in package:dartpad at ${sourceWebDir.path}');
    exitCode = 1;
    return;
  }

  // Resolve dartpad_frontend package root
  final scriptUri = Platform.script;
  final frontendRoot = Directory.fromUri(scriptUri.resolve('..'));
  final targetAssetDir = Directory(p.join(frontendRoot.path, 'web', 'dartpad'));

  stdout.writeln('Copying assets from ${sourceWebDir.path} to ${targetAssetDir.path}...');

  if (targetAssetDir.existsSync()) {
    targetAssetDir.deleteSync(recursive: true);
  }
  await targetAssetDir.create(recursive: true);

  await _copyDirectory(sourceWebDir, targetAssetDir);

  // Generate dartpad-assets.json manifest for runtime version inspection
  await _writeManifest(targetAssetDir);

  stdout.writeln('Successfully copied DartPad assets to ${targetAssetDir.path}');
}

Future<void> _copyDirectory(Directory source, Directory target) async {
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

Future<List<File>> _assetFiles(Directory root) async {
  final files = <File>[];
  await for (final entity in root.list(recursive: true, followLinks: false)) {
    if (entity is File && p.basename(entity.path) != 'dartpad-assets.json') {
      files.add(entity);
    }
  }
  files.sort((a, b) => a.path.compareTo(b.path));
  return files;
}

Future<void> _writeManifest(Directory assetRoot) async {
  final entries = <String, Object>{};
  for (final file in await _assetFiles(assetRoot)) {
    final relative = p.posix.joinAll(p.split(p.relative(file.path, from: assetRoot.path)));
    entries[relative] = {
      'bytes': await file.length(),
      'sha256': (await sha256.bind(file.openRead()).first).toString(),
    };
  }

  final runtimeVersions = await _readRuntimeVersions(assetRoot);
  final manifest = {
    'schemaVersion': 1,
    if (runtimeVersions != null) ...{
      'dartVersion': runtimeVersions.dartVersion,
      'flutterVersion': runtimeVersions.flutterVersion,
    },
    'files': entries,
  };
  final encoder = const JsonEncoder.withIndent('  ');
  await File(p.join(assetRoot.path, 'dartpad-assets.json')).writeAsString('${encoder.convert(manifest)}\n');
}

Future<({String dartVersion, String flutterVersion})?> _readRuntimeVersions(
  Directory assetRoot,
) async {
  final sdkTarFile = File(p.join(assetRoot.path, 'flutter', 'sdk.tar'));
  if (!sdkTarFile.existsSync()) {
    return null;
  }
  try {
    final archiveBytes = await sdkTarFile.readAsBytes();
    final archive = TarDecoder().decodeBytes(archiveBytes);

    String readEntry(String path) {
      final file = archive.files.firstWhere(
        (file) => file.name == path || file.name == '/$path',
      );
      return utf8.decode(file.content);
    }

    final flutterVersion =
        jsonDecode(
              readEntry('sdk/bin/cache/flutter.version.json'),
            )
            as Map<String, dynamic>;
    return (
      dartVersion: flutterVersion['dartSdkVersion'] as String,
      flutterVersion: flutterVersion['flutterVersion'] as String,
    );
  } catch (e) {
    stdout.writeln('Warning: Failed to read runtime versions from sdk.tar: $e');
    return null;
  }
}
