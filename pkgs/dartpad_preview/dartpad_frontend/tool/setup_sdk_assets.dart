// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

// Temporarily retain Dart 3.15.0-27.0.dev: newer workers access Platform.version
// while starting the analysis server, which is unsupported in the browser.
const flutterRevision = 'e81f444cc0835365bda671876183e3f9cd149925';

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
    final sdkManifest = await generateSdkManifest(assets, requireFlutter: true);
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

/// Checks out the pinned Flutter revision with the history needed to determine its version.
Future<Directory> checkoutFlutterSdk(
  Directory stagingDir, {
  Future<void> Function(String, List<String>, String) runCommand = _run,
}) async {
  final flutterRoot = Directory(p.join(stagingDir.path, 'flutter'));
  await runCommand('git', [
    'clone',
    // Flutter's version fallback needs release tags from other branches and
    // their common ancestors with master, so retain all commit history.
    '--filter=blob:none',
    '--branch=master',
    // TODO: Remove --no-checkout once the browser worker regression is fixed.
    '--no-checkout',
    'https://github.com/flutter/flutter.git',
    flutterRoot.path,
  ], stagingDir.path);
  // TODO: Remove this checkout and flutterRevision once the browser worker regression is fixed.
  await runCommand('git', ['checkout', '--detach', flutterRevision], flutterRoot.path);
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

/// Requires Dart and, when requested, Flutter metadata before generating the manifest.
Future<String> generateSdkManifest(Directory assetRoot, {bool requireFlutter = true}) async {
  final sdks = <Map<String, dynamic>>[];
  // Validate the expected bundles explicitly, including directories that are
  // entirely missing. Keep Flutter first as the default when it is requested.
  for (final sdkId in [if (requireFlutter) 'flutter', 'dart']) {
    final isFlutter = sdkId == 'flutter';
    final versions = await readSdkVersions(Directory(p.join(assetRoot.path, sdkId)), isFlutter: isFlutter);
    sdks.add({
      'id': sdkId,
      'name': isFlutter ? 'Flutter' : 'Dart',
      'path': 'dartpad/$sdkId/',
      'dartVersion': versions.dartVersion,
      'flutterVersion': ?versions.flutterVersion,
    });
  }

  final defaultSdkId = requireFlutter ? 'flutter' : 'dart';

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

/// Reads and validates bundle metadata, preserving DartPad's version display format.
Future<({String dartVersion, String? flutterVersion})> readSdkVersions(
  Directory sdkDir, {
  required bool isFlutter,
}) async {
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
    // A Flutter bundle must identify its Flutter SDK in addition to its Dart SDK.
    if (isFlutter && flutterVersion == null) {
      throw const FormatException('Expected a non-empty properties.flutterVersion');
    }
    if (flutterVersion != null && (flutterVersion is! String || flutterVersion.trim().isEmpty)) {
      throw const FormatException('Expected a non-empty properties.flutterVersion');
    }

    // version.json contains the raw Dart version: X.Y.Z or X.Y.Z-<prerelease>.
    // The first '-' separates the core version from the prerelease suffix.
    // Preserve Flutter's previous display, e.g. 3.15.0-27.0.dev becomes
    // "3.15.0 (build 3.15.0-27.0.dev)". Dart-only versions stay verbatim.
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
