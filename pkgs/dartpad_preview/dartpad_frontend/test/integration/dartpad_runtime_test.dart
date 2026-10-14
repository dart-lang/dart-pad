// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('browser')
@Timeout(Duration(minutes: 2))
library;

import 'package:dartpad/dartpad.dart';
import 'package:dartpad_editor/dartpad_editor.dart';
import 'package:dartpad_frontend/features/preview/models/preview_sandbox.dart';
import 'package:dartpad_frontend/sdks.g.dart';
import 'package:test/test.dart';
import 'package:web/web.dart' as web;

void main() {
  final sdk = availableSdks.firstWhere((sdk) => sdk.id == 'dart');
  final assetBaseUrl = Uri.base.resolve('../../web/${sdk.path}');
  late Workspace workspace;

  setUp(() async {
    final worker = await DartPadSdk(assetBaseUrl: assetBaseUrl).dedicatedWorker();
    addTearDown(worker.close);
    workspace = await worker.createWorkspace();
  });

  test('SDK integration preserves workspace paths and change events', () async {
    final api = WorkerWorkspaceResourceApi(workspace);
    addTearDown(api.dispose);

    const path = 'notes #100%?.txt';
    final changes = api.changeEvents.where((event) => event.path == path).take(2).toList();
    await api.changeEventsReady;
    await workspace.writeFileFromText(path, 'notes');
    expect(await api.readFileAsText(path), 'notes');
    expect((await api.listDirectory(uri: '')).map((entry) => entry.path), contains(path));
    await workspace.deleteFileSystemEntity(path);
    expect((await changes).map((event) => event.type), [
      WorkspaceChangeEventType.add,
      WorkspaceChangeEventType.remove,
    ]);
  });

  group('SDK sandbox integration', () {
    late PreviewSandbox sandbox;

    setUp(() async {
      await workspace.writeFileFromText('pubspec.yaml', 'name: runtime_test\nenvironment:\n  sdk: ^3.12.0\n');
      await workspace.pub(command: 'get');

      final container = web.HTMLDivElement();
      web.document.body!.appendChild(container);
      // JS interop methods cannot be used as tear-offs.
      // ignore: unnecessary_lambdas
      addTearDown(() => container.remove());
      sandbox = await IframePreviewSandbox.create(
        container,
        assetBaseUrl: assetBaseUrl,
        workspace: workspace,
      );
      addTearDown(sandbox.close);
    });

    test('preserves console output', () async {
      await workspace.writeFileFromText('main.dart', '''
void main() {
  print('runtime-output');
}
''');
      final output = sandbox.console.firstWhere((message) => message.contains('runtime-output'));

      await sandbox.run('main.dart', mode: 'console');

      expect(await output, contains('runtime-output'));
    });

    test('forwards unhandled asynchronous errors', () async {
      await workspace.writeFileFromText('main.dart', '''
void main() {
  Future<void>.delayed(Duration.zero, () => throw StateError('runtime-async-error'));
}
''');
      final error = sandbox.errors.firstWhere((message) => message.contains('runtime-async-error'));

      await sandbox.run('main.dart', mode: 'console');

      expect(await error, contains('runtime-async-error'));
    });
  });
}
