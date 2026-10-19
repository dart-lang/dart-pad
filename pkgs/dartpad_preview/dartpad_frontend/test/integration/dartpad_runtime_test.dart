// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('browser')
@Timeout(Duration(minutes: 2))
library;

import 'package:dartpad/dartpad.dart';
import 'package:dartpad_editor/dartpad_editor.dart';
import 'package:dartpad_frontend/features/preview/models/preview_sandbox.dart';
import 'package:dartpad_frontend/features/shared/app_event_bus.dart';
import 'package:dartpad_frontend/features/shared/task_status.dart';
import 'package:dartpad_frontend/features/workspace/data/workspace_repository.dart';
import 'package:dartpad_frontend/sdks.g.dart';
import 'package:test/test.dart';
import 'package:web/web.dart' as web;

void main() {
  for (final sdkId in ['dart', 'flutter']) {
    final sdk = availableSdks.firstWhere((sdk) => sdk.id == sdkId);
    group('${sdk.name} SDK integration', () {
      // Use the generated bundles served directly by package:test.
      final assetBaseUrl = Uri.base.resolve('../../web/${sdk.path}');
      const specialPath = 'notes #100%?.txt';
      late Workspace workspace;

      setUp(() async {
        final worker = await DartPadSdk(assetBaseUrl: assetBaseUrl).dedicatedWorker();
        addTearDown(worker.close);
        workspace = await worker.createWorkspace();
      });

      WorkspaceRepository createRepository() {
        final events = AppEventBus();
        addTearDown(events.dispose);
        final tasks = TaskStatusController();
        addTearDown(tasks.dispose);
        final repository = WorkspaceRepository(
          events: events,
          taskStatus: tasks,
          workspaceResourceApi: MemoryWorkspaceResourceApi(),
          sdk: sdk,
          workspaceFuture: Future.value(workspace),
        );
        addTearDown(repository.close);
        return repository;
      }

      test('preserves workspace paths on round-trip', () async {
        final api = WorkerWorkspaceResourceApi(workspace);
        addTearDown(api.dispose);

        await workspace.writeFileFromText(specialPath, 'notes');
        expect(await api.readFileAsText(specialPath), 'notes');
        expect((await api.listDirectory(path: '')).map((entry) => entry.path), contains(specialPath));
      });

      test('preserves change event paths', () async {
        final api = WorkerWorkspaceResourceApi(workspace);
        addTearDown(api.dispose);

        final changes = api.changeEvents.where((event) => event.path == specialPath).take(2).toList();
        await api.changeEventsReady;
        await workspace.writeFileFromText(specialPath, 'notes');
        await workspace.deleteFileSystemEntity(specialPath);
        expect((await changes).map((event) => event.type), [
          WorkspaceChangeEventType.add,
          WorkspaceChangeEventType.remove,
        ]);
      });

      test('decodes system file URIs for worker reads', () async {
        await workspace.writeFileFromText(specialPath, 'notes');
        final repository = createRepository();

        // System tabs retain the encoded URI; only the worker read decodes it.
        final systemUri = Uri.file(workspacePath.join(workspace.workspaceFolder, specialPath), windows: false);
        expect(await repository.readSystemFile(systemUri), 'notes');
        expect(await repository.workspaceResourceApi.listDirectory(path: ''), isEmpty);
      });

      group('sandbox', () {
        late PreviewSandbox sandbox;

        setUp(() async {
          final pubspec = StringBuffer('name: runtime_test\nenvironment:\n  sdk: ^3.12.0\n');
          if (sdk.isFlutter) {
            pubspec.write('dependencies:\n  flutter:\n    sdk: flutter\n');
          }
          await workspace.writeFileFromText('pubspec.yaml', pubspec.toString());
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
        if (sdk.isFlutter) {
          test('renders a Flutter frame', () async {
            await workspace.writeFileFromText('main.dart', '''
import 'package:flutter/widgets.dart';

void main() {
  runApp(const SizedBox());
  WidgetsBinding.instance.addPostFrameCallback((_) {
    print('flutter-frame-rendered');
  });
}
''');
            final rendered = sandbox.console.firstWhere((message) => message.contains('flutter-frame-rendered'));

            await sandbox.run('main.dart', mode: 'flutter');

            expect(await rendered, contains('flutter-frame-rendered'));
          });
        }
      });
    });
  }
}
