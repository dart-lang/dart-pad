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

  test('Flutter checkout follows latest master and retains release tags and history', () async {
    final source = await Directory(p.join(assets.path, 'source')).create();
    Future<String> git(List<String> arguments, {Directory? workingDirectory}) async {
      final result = await Process.run('git', arguments, workingDirectory: (workingDirectory ?? source).path);
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
      return (result.stdout as String).trim();
    }

    await git(['init', '--initial-branch=master']);
    await git(['config', 'user.name', 'SDK setup test']);
    await git(['config', 'user.email', 'sdk-setup-test@example.invalid']);
    await git(['commit', '--allow-empty', '-m', 'Tagged release']);
    await git(['tag', '3.33.0-1.0.pre']);
    await git(['commit', '--allow-empty', '-m', 'Shared release ancestor']);
    final expectedAncestor = await git(['rev-parse', 'HEAD']);
    await git(['switch', '-c', 'beta']);
    await git(['commit', '--allow-empty', '-m', 'Beta release']);
    await git(['tag', '3.49.0-0.2.pre']);
    await git(['commit', '--allow-empty', '-m', 'Future beta release']);
    await git(['tag', '3.50.0-0.1.pre']);
    await git(['switch', 'master']);
    await git(['commit', '--allow-empty', '-m', 'Untagged master commit']);
    await git(['commit', '--allow-empty', '-m', 'Future master commit']);
    final expectedRevision = await git(['rev-parse', 'HEAD']);

    final checkout = await checkoutFlutterSdk(
      assets,
      repository: source.uri.toString(),
    );

    expect(await git(['rev-parse', 'HEAD'], workingDirectory: checkout), expectedRevision);
    expect(await git(['rev-parse', '--is-shallow-repository'], workingDirectory: checkout), 'false');
    expect(await git(['tag', '--list'], workingDirectory: checkout), '3.33.0-1.0.pre\n3.49.0-0.2.pre\n3.50.0-0.1.pre');
    // Flutter's version fallback uses the newest release tag, including tags
    // from beta/stable branches, and the common ancestor with master.
    final latestTag = await git([
      'for-each-ref',
      '--sort=-v:refname',
      '--count=1',
      '--format=%(refname:short)',
      'refs/tags/[0-9]*.*.*',
    ], workingDirectory: checkout);
    expect(latestTag, '3.50.0-0.1.pre');
    final ancestor = await git(['merge-base', 'HEAD', latestTag], workingDirectory: checkout);
    expect(ancestor, expectedAncestor);
    expect(await git(['rev-list', '--count', '$ancestor..HEAD'], workingDirectory: checkout), '2');
  });

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
