// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

Future<void> main() async {
  final frontendRoot = Directory.fromUri(Platform.script.resolve('..'));
  final targetAssetDir = Directory(p.join(frontendRoot.path, 'web', 'dartpad'));
  final stagingDir = await Directory.systemTemp.createTemp('dartpad_assets_');
  final assets = Directory(p.join(stagingDir.path, 'assets'));

  try {
    // Download the latest Dart beta bundle independently of Flutter's Dart SDK.
    await _run(Platform.resolvedExecutable, [
      'run',
      'dartpad',
      'setup',
      'dart',
      '--channel=beta',
      '--output=${p.join(assets.path, 'dart')}',
    ], frontendRoot.path);

    final flutterRoot = await checkoutFlutterSdk(stagingDir);
    await _run(Platform.resolvedExecutable, [
      'run',
      'dartpad',
      'setup',
      'flutter',
      '--flutter-root=${flutterRoot.path}',
      // Build matching web SDK sources instead of relying on Flutter's
      // prebuilt DDC bundle layout, which changes between Flutter revisions.
      '--web-sdk=build',
      '--output=${p.join(assets.path, 'flutter')}',
    ], frontendRoot.path);

    // Validate both bundles before replacing the existing assets.
    final sdkManifest = await generateSdkManifest(assets);
    if (targetAssetDir.existsSync()) {
      await targetAssetDir.delete(recursive: true);
    }
    await _copyDirectory(assets, targetAssetDir);
    final manifestFile = File(p.join(frontendRoot.path, 'lib', 'sdks.g.dart'));
    await manifestFile.writeAsString(sdkManifest);
    stdout.writeln('Generated ${manifestFile.path}');
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

/// Checks out the latest Flutter master with the history needed to determine its version.
Future<Directory> checkoutFlutterSdk(
  Directory stagingDir, {
  String repository = 'https://github.com/flutter/flutter.git',
}) async {
  final flutterRoot = Directory(p.join(stagingDir.path, 'flutter'));
  await _run('git', [
    'clone',
    // Flutter's version fallback needs release tags from other branches and
    // their common ancestors with master, so retain all commit history.
    '--filter=blob:none',
    '--branch=master',
    repository,
    flutterRoot.path,
  ], stagingDir.path);
  return flutterRoot;
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

/// Generates the SDK manifest from bundle metadata, failing if it is incomplete.
Future<String> generateSdkManifest(Directory assetRoot) async {
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
      sdks.add({
        'id': sdkId,
        'name': versions.flutterVersion != null ? 'Flutter' : 'Dart',
        'path': 'dartpad/$sdkId/',
        'dartVersion': versions.dartVersion,
        'flutterVersion': ?versions.flutterVersion,
      });
    }
  }

  if (sdks.isEmpty) {
    throw StateError('No SDK bundles found in ${assetRoot.path}');
  }

  final defaultSdkId = sdks.any((s) => s['id'] == 'flutter') ? 'flutter' : sdks.first['id'] as String;

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

  return buffer.toString();
}

Future<({String dartVersion, String? flutterVersion})> _readSdkVersions(Directory sdkDir) async {
  final versionFile = File(p.join(sdkDir.path, 'version.json'));
  try {
    final metadata = jsonDecode(await versionFile.readAsString());
    if (metadata is! Map<String, dynamic>) {
      throw const FormatException('Expected a JSON object');
    }

    final dartVersion = metadata['dartVersion'];
    if (dartVersion is! String || dartVersion.trim().isEmpty) {
      throw const FormatException('Expected a non-empty dartVersion');
    }

    final properties = metadata['properties'];
    if (properties is! Map<String, dynamic>) {
      throw const FormatException('Expected a properties object');
    }
    final flutterVersion = properties['flutterVersion'];
    if ((flutterVersion != null && (flutterVersion is! String || flutterVersion.trim().isEmpty)) ||
        (p.basename(sdkDir.path) == 'flutter' && flutterVersion == null)) {
      throw const FormatException('Expected a non-empty properties.flutterVersion');
    }

    // Flutter previously supplied this display format through flutter.version.json.
    // Keep Dart-only bundle versions (including edge revisions) verbatim.
    final displayDartVersion = flutterVersion != null && dartVersion.contains('-')
        ? '${dartVersion.split('-').first} (build $dartVersion)'
        : dartVersion;
    return (dartVersion: displayDartVersion, flutterVersion: flutterVersion as String?);
  } on FileSystemException catch (error) {
    throw StateError('Could not read SDK metadata at ${versionFile.path}: ${error.message}');
  } on FormatException catch (error) {
    throw StateError('Invalid SDK metadata at ${versionFile.path}: ${error.message}');
  }
}
