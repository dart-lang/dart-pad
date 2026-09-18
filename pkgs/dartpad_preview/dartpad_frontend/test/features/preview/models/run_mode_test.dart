// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dartpad_editor/dartpad_editor.dart';
import 'package:dartpad_frontend/features/preview/models/run_mode.dart';
import 'package:dartpad_frontend/sdks.g.dart';
import 'package:test/test.dart';

void main() {
  group('RunMode', () {
    test('defines mode property matching sandbox protocol identifiers', () {
      expect(RunMode.console.mode, 'console');
      expect(RunMode.flutter.mode, 'flutter');
    });
  });

  final dart = availableSdks.firstWhere((sdk) => !sdk.isFlutter);
  final flutter = availableSdks.firstWhere((sdk) => sdk.isFlutter);
  late MemoryWorkspaceResourceApi workspace;

  setUp(() async {
    workspace = MemoryWorkspaceResourceApi();
    await workspace.writeFileFromText('pubspec.yaml', 'name: project');
    await workspace.writeFileFromText('tool/nested/pubspec.yaml', 'name: nested');
  });
  tearDown(() => workspace.dispose());

  test('resolves the same entrypoint for the selected SDK', () async {
    for (final sdk in [dart, flutter]) {
      final mode = await RunMode.resolve(workspace: workspace, sdk: sdk, entrypoint: 'lib/main.dart');
      expect(mode, sdk.isFlutter ? RunMode.flutter : RunMode.console);
    }
  });

  test('uses the nearest pubspec for Flutter path exclusions', () async {
    for (final path in ['bin/main.dart', 'test/main.dart', 'tool/main.dart', 'tool/nested/tool/check.dart']) {
      expect(
        await RunMode.resolve(workspace: workspace, sdk: flutter, entrypoint: path),
        RunMode.console,
        reason: path,
      );
    }
    expect(
      await RunMode.resolve(workspace: workspace, sdk: flutter, entrypoint: 'tool/nested/lib/main.dart'),
      RunMode.flutter,
    );
  });

  test('an explicit mode takes precedence over inferred mode', () async {
    expect(
      await RunMode.resolve(
        workspace: workspace,
        sdk: flutter,
        entrypoint: 'lib/main.dart',
        modeOverride: RunMode.console,
      ),
      RunMode.console,
    );
    expect(
      await RunMode.resolve(
        workspace: workspace,
        sdk: flutter,
        entrypoint: 'tool/main.dart',
        modeOverride: RunMode.flutter,
      ),
      RunMode.flutter,
    );
  });

  test('a missing entrypoint resolves to console without an override', () async {
    expect(await RunMode.resolve(workspace: workspace, sdk: flutter, entrypoint: null), RunMode.console);
  });

  test('rejects a Flutter override for a Dart SDK during resolution', () async {
    await expectLater(
      RunMode.resolve(workspace: workspace, sdk: dart, entrypoint: 'lib/main.dart', modeOverride: RunMode.flutter),
      throwsFormatException,
    );
  });
}
