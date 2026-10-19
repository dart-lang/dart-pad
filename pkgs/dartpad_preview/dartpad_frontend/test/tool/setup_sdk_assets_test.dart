// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// Run with: dart test --platform vm --compiler kernel test/tool/setup_sdk_assets_test.dart
@TestOn('vm')
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:process/process.dart';
import 'package:test/test.dart';

import '../../tool/setup_sdk_assets.dart';

// Only process startup and completion are needed by the setup script.
// Fail on any other process API instead of accidentally running real commands.
class _FakeProcessManager implements ProcessManager {
  final calls = <({List<Object> command, String? workingDirectory, ProcessStartMode mode})>[];
  final exitCodes = [0, 0];

  @override
  Future<Process> start(
    List<Object> command, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool includeParentEnvironment = true,
    bool runInShell = false,
    ProcessStartMode mode = ProcessStartMode.normal,
  }) async {
    calls.add((command: List.of(command), workingDirectory: workingDirectory, mode: mode));
    return _FakeProcess(exitCodes.removeAt(0));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeProcess implements Process {
  _FakeProcess(int code) : exitCode = Future.value(code);

  @override
  final Future<int> exitCode;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late Directory assets;

  setUp(() async {
    assets = await Directory.systemTemp.createTemp('sdk_metadata_test_');
  });

  tearDown(() async {
    await assets.delete(recursive: true);
  });

  Future<Directory> writeVersion(String sdkId, String contents) async {
    final sdkDir = await Directory(p.join(assets.path, sdkId)).create();
    await File(p.join(sdkDir.path, 'version.json')).writeAsString(contents);
    return sdkDir;
  }

  group('Flutter checkout', () {
    late _FakeProcessManager processManager;
    late SdkAssetSetup setup;
    late String flutterRoot;
    late List<String> cloneCommand;
    final checkoutCommand = ['git', 'checkout', '--detach', flutterRevision];

    setUp(() {
      processManager = _FakeProcessManager();
      setup = SdkAssetSetup(processManager: processManager);
      flutterRoot = p.join(assets.path, 'flutter');
      cloneCommand = [
        'git',
        'clone',
        '--filter=blob:none',
        '--branch=master',
        '--no-checkout',
        'https://github.com/flutter/flutter.git',
        flutterRoot,
      ];
    });

    test('clones with full history and tags before checking out the pinned revision', () async {
      final checkout = await setup.checkoutFlutterSdk(assets);

      expect(checkout.path, flutterRoot);
      expect(processManager.calls.map((call) => call.command), [cloneCommand, checkoutCommand]);
      expect(processManager.calls.map((call) => call.workingDirectory), [assets.path, flutterRoot]);
      expect(processManager.calls.map((call) => call.mode), everyElement(ProcessStartMode.inheritStdio));
    });

    test('stops before checkout when cloning fails', () async {
      processManager.exitCodes[0] = 128;

      await expectLater(
        setup.checkoutFlutterSdk(assets),
        throwsA(
          isA<ProcessException>()
              .having((error) => error.executable, 'executable', 'git')
              .having((error) => error.arguments, 'arguments', cloneCommand.skip(1).toList())
              .having((error) => error.errorCode, 'errorCode', 128),
        ),
      );
      expect(processManager.calls.map((call) => call.command), [cloneCommand]);
    });

    test('reports a failed checkout', () async {
      processManager.exitCodes[1] = 1;

      await expectLater(
        setup.checkoutFlutterSdk(assets),
        throwsA(
          isA<ProcessException>()
              .having((error) => error.executable, 'executable', 'git')
              .having((error) => error.arguments, 'arguments', checkoutCommand.skip(1).toList())
              .having((error) => error.errorCode, 'errorCode', 1),
        ),
      );
      expect(processManager.calls.map((call) => call.command), [cloneCommand, checkoutCommand]);
    });
  });

  test('keeps a Dart-only prerelease version verbatim', () async {
    final sdkDir = await writeVersion('dart', '{"dartVersion": "3.15.0-edge.example", "properties": {}}');

    expect(await readSdkVersions(sdkDir, isFlutter: false), (
      dartVersion: '3.15.0-edge.example',
      flutterVersion: null,
    ));
  });

  test('preserves the Flutter Dart prerelease display format', () async {
    final sdkDir = await writeVersion(
      'flutter',
      '{"dartVersion": "3.15.0-27.0.dev", "properties": {"flutterVersion": "3.49.0-pre"}}',
    );

    expect(await readSdkVersions(sdkDir, isFlutter: true), (
      dartVersion: '3.15.0 (build 3.15.0-27.0.dev)',
      flutterVersion: '3.49.0-pre',
    ));
  });

  test('reports the metadata path when version.json is missing', () async {
    final sdkDir = Directory(p.join(assets.path, 'dart'));
    await expectLater(
      readSdkVersions(sdkDir, isFlutter: false),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains(p.join(sdkDir.path, 'version.json')),
        ),
      ),
    );
  });

  // Keep all other fields valid so each fixture isolates its intended failure.
  // Check the affected file and field without fixing the diagnostic wording.
  for (final (description, contents, field) in [
    ('malformed JSON', '{', null),
    ('a non-object document', '[]', null),
    ('a missing Dart version', '{"properties": {"flutterVersion": "3.48.0"}}', 'dartVersion'),
    (
      'an invalid Dart version',
      '{"dartVersion": 3, "properties": {"flutterVersion": "3.48.0"}}',
      'dartVersion',
    ),
    ('invalid properties', '{"dartVersion": "3.14.0", "properties": []}', 'properties'),
    ('a missing Flutter version', '{"dartVersion": "3.14.0", "properties": {}}', 'properties.flutterVersion'),
    (
      'an invalid Flutter version',
      '{"dartVersion": "3.14.0", "properties": {"flutterVersion": " "}}',
      'properties.flutterVersion',
    ),
  ]) {
    test('rejects $description', () async {
      final sdkDir = await writeVersion('flutter', contents);
      var expectedError = isA<StateError>().having(
        (error) => error.message,
        'message',
        contains(p.join(sdkDir.path, 'version.json')),
      );
      if (field != null) {
        expectedError = expectedError.having((error) => error.message, 'message', contains(field));
      }
      await expectLater(
        readSdkVersions(sdkDir, isFlutter: true),
        throwsA(expectedError),
      );
    });
  }

  test('generates a manifest when both requested bundles have valid metadata', () async {
    await writeVersion('dart', '{"dartVersion": "3.15.0-edge.example", "properties": {}}');
    await writeVersion('flutter', '{"dartVersion": "3.14.0-1.0.dev", "properties": {"flutterVersion": "3.48.0"}}');

    final manifest = await generateSdkManifest(assets);

    expect(manifest, contains("const defaultSdkId = 'flutter';"));
    expect(RegExp(r'\bSdkInfo\(').allMatches(manifest), hasLength(2));
    expect(
      manifest,
      stringContainsInOrder([
        "id: 'flutter'",
        "name: 'Flutter'",
        "path: 'dartpad/flutter/'",
        "dartVersion: '3.14.0 (build 3.14.0-1.0.dev)'",
        "flutterVersion: '3.48.0'",
        "id: 'dart'",
        "name: 'Dart'",
        "path: 'dartpad/dart/'",
        "dartVersion: '3.15.0-edge.example'",
      ]),
    );
  });

  test('requires the Dart bundle even when Flutter metadata is valid', () async {
    await writeVersion('flutter', '{"dartVersion": "3.14.0", "properties": {"flutterVersion": "3.48.0"}}');
    await expectLater(
      generateSdkManifest(assets),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains(p.join('dart', 'version.json')),
        ),
      ),
    );
  });

  test('requires the requested Flutter bundle even when Dart metadata is valid', () async {
    await writeVersion('dart', '{"dartVersion": "3.14.0", "properties": {}}');
    await expectLater(
      generateSdkManifest(assets),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains(p.join('flutter', 'version.json')),
        ),
      ),
    );
  });

  test('allows a Dart-only manifest when Flutter is explicitly not requested', () async {
    await writeVersion('dart', '{"dartVersion": "3.14.0", "properties": {}}');

    final manifest = await generateSdkManifest(assets, requireFlutter: false);

    expect(manifest, contains("const defaultSdkId = 'dart';"));
    expect(RegExp(r'\bSdkInfo\(').allMatches(manifest), hasLength(1));
    expect(
      manifest,
      stringContainsInOrder([
        "id: 'dart'",
        "name: 'Dart'",
        "path: 'dartpad/dart/'",
        "dartVersion: '3.14.0'",
      ]),
    );
    expect(manifest, isNot(contains('flutterVersion:')));
  });
}
