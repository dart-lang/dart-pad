// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// Run with: dart test --platform vm --compiler kernel test/tool/setup_sdk_assets_test.dart
@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../../tool/setup_sdk_assets.dart';

void main() {
  late Directory assets;

  setUp(() async {
    assets = await Directory.systemTemp.createTemp('sdk_manifest_test_');
  });

  tearDown(() async {
    await assets.delete(recursive: true);
  });

  Future<File> writeVersion(String sdkId, String contents) async {
    final sdkDir = await Directory(p.join(assets.path, sdkId)).create();
    return File(p.join(sdkDir.path, 'version.json')).writeAsString(contents);
  }

  test('reads bundle metadata without sdk.tar and preserves versions and Flutter default', () async {
    const dartVersion = '3.15.0-edge.00ca160f917cb531a91fe61ca5464fca2ad11db6';
    await writeVersion('dart', jsonEncode({'dartVersion': dartVersion, 'properties': <String, Object?>{}}));
    await writeVersion(
      'flutter',
      jsonEncode({
        'dartVersion': '3.14.0-315.1.beta',
        'properties': {'flutterVersion': '3.49.0-1.0.pre-444'},
      }),
    );

    final manifest = await generateSdkManifest(assets);

    expect(manifest, contains("const defaultSdkId = 'flutter';"));
    expect(manifest.indexOf("id: 'flutter'"), lessThan(manifest.indexOf("id: 'dart'")));
    expect(
      manifest,
      contains('''  SdkInfo(
    id: 'flutter',
    name: 'Flutter',
    path: 'dartpad/flutter/',
    dartVersion: '3.14.0 (build 3.14.0-315.1.beta)',
    flutterVersion: '3.49.0-1.0.pre-444',
  ),'''),
    );
    expect(
      manifest,
      contains('''  SdkInfo(
    id: 'dart',
    name: 'Dart',
    path: 'dartpad/dart/',
    dartVersion: '$dartVersion',
  ),'''),
    );
  });

  test('preserves stable Flutter Dart versions without adding a build suffix', () async {
    await writeVersion(
      'flutter',
      jsonEncode({
        'dartVersion': '3.13.3',
        'properties': {'flutterVersion': '3.46.0'},
      }),
    );

    expect(await generateSdkManifest(assets), contains("dartVersion: '3.13.3',"));
  });

  test('selects Dart as default when there is no Flutter bundle', () async {
    await writeVersion('dart', jsonEncode({'dartVersion': '3.13.3', 'properties': <String, Object?>{}}));

    expect(await generateSdkManifest(assets), contains("const defaultSdkId = 'dart';"));
  });

  test('fails with the metadata path when version.json is missing', () async {
    final sdkDir = await Directory(p.join(assets.path, 'dart')).create();

    await expectLater(
      generateSdkManifest(assets),
      throwsA(
        isA<StateError>().having((error) => error.message, 'message', contains(p.join(sdkDir.path, 'version.json'))),
      ),
    );
  });

  for (final (description, contents, reason) in [
    ('malformed JSON', '{', 'Invalid SDK metadata'),
    ('non-object JSON', '[]', 'Expected a JSON object'),
    ('missing Dart version', '{"properties": {}}', 'Expected a non-empty dartVersion'),
    ('empty Dart version', '{"dartVersion": "  ", "properties": {}}', 'Expected a non-empty dartVersion'),
    ('non-string Dart version', '{"dartVersion": 3, "properties": {}}', 'Expected a non-empty dartVersion'),
    ('missing properties', '{"dartVersion": "3.13.3"}', 'Expected a properties object'),
    ('non-object properties', '{"dartVersion": "3.13.3", "properties": []}', 'Expected a properties object'),
    (
      'missing Flutter version',
      '{"dartVersion": "3.13.3", "properties": {}}',
      'Expected a non-empty properties.flutterVersion',
    ),
    (
      'empty Flutter version',
      '{"dartVersion": "3.13.3", "properties": {"flutterVersion": ""}}',
      'Expected a non-empty properties.flutterVersion',
    ),
    (
      'non-string Flutter version',
      '{"dartVersion": "3.13.3", "properties": {"flutterVersion": 3}}',
      'Expected a non-empty properties.flutterVersion',
    ),
  ]) {
    test('fails for $description instead of silently omitting the SDK', () async {
      await writeVersion('dart', jsonEncode({'dartVersion': '3.13.3', 'properties': <String, Object?>{}}));
      final versionFile = await writeVersion('flutter', contents);

      await expectLater(
        generateSdkManifest(assets),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            allOf(contains(versionFile.path), contains(reason)),
          ),
        ),
      );
    });
  }

  test('fails for an empty asset directory', () async {
    await expectLater(
      generateSdkManifest(assets),
      throwsA(isA<StateError>().having((error) => error.message, 'message', contains('No SDK bundles found'))),
    );
  });
}
