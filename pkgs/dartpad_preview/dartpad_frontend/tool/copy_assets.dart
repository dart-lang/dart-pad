// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive.dart';
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

  // Generate versions.json file in each sdk directory (e.g. dart/ and flutter/)
  await _writeSdkVersions(targetAssetDir);

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

Future<void> _writeSdkVersions(Directory assetRoot) async {
  await for (final entity in assetRoot.list(recursive: false)) {
    if (entity is Directory) {
      final versions = await _readSdkVersions(entity);
      if (versions != null) {
        final versionsFile = File(p.join(entity.path, 'versions.json'));
        final encoder = const JsonEncoder.withIndent('  ');
        await versionsFile.writeAsString('${encoder.convert(versions)}\n');
        stdout.writeln('Generated ${p.relative(versionsFile.path, from: assetRoot.path)}');
      }
    }
  }
}

Future<Map<String, dynamic>?> _readSdkVersions(Directory sdkDir) async {
  final sdkTarFile = File(p.join(sdkDir.path, 'sdk.tar'));
  if (!sdkTarFile.existsSync()) {
    return null;
  }
  try {
    final archiveBytes = await sdkTarFile.readAsBytes();
    final archive = TarDecoder().decodeBytes(archiveBytes);

    ArchiveFile? findFile(bool Function(ArchiveFile file) predicate) {
      for (final file in archive.files) {
        if (predicate(file)) {
          return file;
        }
      }
      return null;
    }

    final flutterVersionFile = findFile(
      (f) => f.name.endsWith('flutter.version.json'),
    );

    if (flutterVersionFile != null) {
      final json = jsonDecode(utf8.decode(flutterVersionFile.content)) as Map<String, dynamic>;
      final dartVersion = (json['dartSdkVersion'] ?? json['dartVersion']) as String?;
      final flutterVersion = (json['flutterVersion'] ?? json['frameworkVersion']) as String?;
      return {
        'dartVersion': ?dartVersion,
        'flutterVersion': ?flutterVersion,
      };
    }

    final dartVersionFile = findFile(
      (f) => f.name == 'sdk/version' || f.name == '/sdk/version',
    );

    if (dartVersionFile != null) {
      final dartVersion = utf8.decode(dartVersionFile.content).trim();
      return {
        'dartVersion': dartVersion,
      };
    }

    return null;
  } catch (e) {
    stdout.writeln('Warning: Failed to read SDK versions for ${sdkDir.path}: $e');
    return null;
  }
}
