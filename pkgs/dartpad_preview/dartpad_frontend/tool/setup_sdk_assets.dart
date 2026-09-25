// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

// Pin runtime sources independently of the dartpad client package. Update these
// revisions intentionally and regenerate lib/sdks.g.dart when upgrading SDKs.
// These specific revisions are not required by dartpad 0.0.10.

// Selected on 2026-09-25 from the official Dart archive's latest main build:
// https://storage.googleapis.com/dart-archive/channels/main/raw/latest/VERSION
// Downloads the prebuilt DartPad assets for this exact Dart SDK revision.
const _dartRevision = 'e686006ff5b0b3c31731f158a74d1a09ee75b15b';

// Selected on 2026-09-25 from the Flutter repository's main/master HEAD using
// `git ls-remote https://github.com/flutter/flutter.git`.
// Builds Flutter assets from this checkout using its own matching Dart SDK,
// independently of _dartRevision above. Displayed SDK versions are extracted
// from the generated sdk.tar files when writing lib/sdks.g.dart.
const _flutterRevision = 'afde83da30bcbf7f35a90dba132c92aee8111eb8';

Future<void> main() async {
  final frontendRoot = Directory.fromUri(Platform.script.resolve('..'));
  final targetAssetDir = Directory(p.join(frontendRoot.path, 'web', 'dartpad'));
  final stagingDir = await Directory.systemTemp.createTemp('dartpad_assets_');
  final assets = Directory(p.join(stagingDir.path, 'assets'));

  try {
    await _run(Platform.resolvedExecutable, [
      'run',
      'dartpad',
      'setup',
      'dart',
      '--channel=main',
      '--revision=$_dartRevision',
      '--output=${p.join(assets.path, 'dart')}',
    ], frontendRoot.path);

    // Build Flutter assets from a pinned checkout, independently of the Flutter
    // installation used to build the frontend or available on the developer's PATH.
    final flutterRoot = p.join(stagingDir.path, 'flutter');
    // Flutter derives its version from Git tags and history. A depth=1 fetch
    // of an untagged revision reports 0.0.0-unknown and breaks pub resolution.
    await _run('git', [
      'clone',
      '--filter=blob:none',
      '--no-checkout',
      'https://github.com/flutter/flutter.git',
      flutterRoot,
    ], frontendRoot.path);
    await _run('git', ['checkout', '--detach', _flutterRevision], flutterRoot);
    await _run(Platform.resolvedExecutable, [
      'run',
      'dartpad',
      'setup',
      'flutter',
      '--flutter-root=$flutterRoot',
      '--output=${p.join(assets.path, 'flutter')}',
    ], frontendRoot.path);

    // Keep the existing assets until both SDKs have been generated successfully.
    if (targetAssetDir.existsSync()) {
      await targetAssetDir.delete(recursive: true);
    }
    await _copyDirectory(assets, targetAssetDir);
    await _writeSdkManifest(targetAssetDir, frontendRoot);
    stdout.writeln('Successfully generated DartPad assets at ${targetAssetDir.path}');
  } finally {
    await stagingDir.delete(recursive: true);
  }
}

Future<void> _run(String executable, List<String> arguments, String workingDirectory) async {
  final process = await Process.start(
    executable,
    arguments,
    workingDirectory: workingDirectory,
    mode: ProcessStartMode.inheritStdio,
  );
  final result = await process.exitCode;
  if (result != 0) {
    throw ProcessException(executable, arguments, 'SDK asset setup failed', result);
  }
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

Future<void> _writeSdkManifest(Directory assetRoot, Directory frontendRoot) async {
  final sdks = <Map<String, dynamic>>[];

  final entries = await assetRoot.list(recursive: false).toList();
  // Sort so flutter comes first by default, then dart, then others
  entries.sort((a, b) {
    if (p.basename(a.path) == 'flutter') {
      return -1;
    }
    if (p.basename(b.path) == 'flutter') {
      return 1;
    }
    return a.path.compareTo(b.path);
  });

  for (final entity in entries) {
    if (entity is Directory) {
      final sdkId = p.basename(entity.path);
      final versions = await _readSdkVersions(entity);
      if (versions != null) {
        final dartVersion = versions['dartVersion'] as String?;
        final flutterVersion = versions['flutterVersion'] as String?;
        if (dartVersion != null) {
          final isFlutter = flutterVersion != null;
          sdks.add({
            'id': sdkId,
            'name': isFlutter ? 'Flutter' : 'Dart',
            'path': 'dartpad/$sdkId/',
            'dartVersion': dartVersion,
            'flutterVersion': ?flutterVersion,
          });
        }
      }
    }
  }

  final defaultSdkId = sdks.any((s) => s['id'] == 'flutter')
      ? 'flutter'
      : (sdks.isNotEmpty ? sdks.first['id'] as String : 'default');

  final buffer = StringBuffer()
    ..writeln('// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file')
    ..writeln('// for details. All rights reserved. Use of this source code is governed by a')
    ..writeln('// BSD-style license that can be found in the LICENSE file.')
    ..writeln('//')
    ..writeln('// Generated file. Do not edit directly.')
    ..writeln('// Run `dart tool/setup_sdk_assets.dart` to regenerate.')
    ..writeln()
    ..writeln("import 'features/shared/sdk_info.dart';")
    ..writeln()
    ..writeln("const defaultSdkId = '$defaultSdkId';")
    ..writeln()
    ..writeln('const availableSdks = <SdkInfo>[');

  for (final sdk in sdks) {
    buffer.writeln('  SdkInfo(');
    buffer.writeln("    id: '${sdk['id']}',");
    buffer.writeln("    name: '${sdk['name']}',");
    buffer.writeln("    path: '${sdk['path']}',");
    buffer.writeln("    dartVersion: '${sdk['dartVersion']}',");
    if (sdk['flutterVersion'] != null) {
      buffer.writeln("    flutterVersion: '${sdk['flutterVersion']}',");
    }
    buffer.writeln('  ),');
  }

  buffer.writeln('];');
  buffer.writeln();
  buffer.writeln('final defaultSdk = availableSdks.firstWhere(');
  buffer.writeln('  (sdk) => sdk.id == defaultSdkId,');
  buffer.writeln('  orElse: () => availableSdks.first,');
  buffer.writeln(');');

  final targetFile = File(p.join(frontendRoot.path, 'lib', 'sdks.g.dart'));
  await targetFile.writeAsString(buffer.toString());
  stdout.writeln('Generated ${targetFile.path}');

  // Remove any legacy sdks.g.dart in features/shared/ if present
  final oldGeneratedFile = File(p.join(frontendRoot.path, 'lib', 'features', 'shared', 'sdks.g.dart'));
  if (oldGeneratedFile.existsSync()) {
    oldGeneratedFile.deleteSync();
  }

  // Remove any legacy sdks.json if present
  final legacyJson = File(p.join(assetRoot.path, 'sdks.json'));
  if (legacyJson.existsSync()) {
    legacyJson.deleteSync();
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
