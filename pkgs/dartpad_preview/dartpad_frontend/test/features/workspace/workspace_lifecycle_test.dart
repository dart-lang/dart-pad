// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('browser')
library;

import 'dart:async';

import 'package:dartpad_frontend/features/workspace/workspace_lifecycle.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_test/client_test.dart';
import 'package:web/web.dart' as web;

void main() {
  test('workspace remains initializing until workspace and entry file are ready', () async {
    final workspaceReady = Completer<String>();
    final entryFileReady = Completer<String>();
    var usable = false;

    final resultFuture = waitForWorkspaceUsable(
      workspaceReady: workspaceReady.future,
      projectReady: entryFileReady.future,
    );
    unawaited(resultFuture.then((_) => usable = true));

    workspaceReady.complete('workspace');
    await pumpEventQueue();
    expect(usable, isFalse);

    entryFileReady.complete('lib/main.dart');
    expect(await resultFuture, (
      workspace: 'workspace',
      project: 'lib/main.dart',
    ));
    expect(usable, isTrue);
  });

  testClient('unmounts the keyed subtree before disposing its session', (
    tester,
  ) async {
    final operations = <String>[];
    tester.pumpComponent(_ResetHarness(operations));

    (web.document.querySelector('button')! as web.HTMLButtonElement).click();
    await pumpEventQueue();

    expect(operations, ['unmount:0', 'dispose:0', 'create:1']);
  });
}

final class _ResetHarness extends StatefulComponent {
  const _ResetHarness(this.operations);

  final List<String> operations;

  @override
  State<_ResetHarness> createState() => _ResetHarnessState();
}

final class _ResetHarnessState extends State<_ResetHarness> {
  int generation = 0;

  void reset() {
    final oldGeneration = generation;
    final previousWorkspaceDisposed = Completer<void>();
    unawaited(
      previousWorkspaceDisposed.future.then((_) {
        component.operations.add('create:${oldGeneration + 1}');
      }),
    );
    setState(() {
      generation++;
    });
    disposeAfterWorkspaceUnmount(context, () async {
      component.operations.add('dispose:$oldGeneration');
      previousWorkspaceDisposed.complete();
    });
  }

  @override
  Component build(BuildContext context) {
    return div([
      button(onClick: reset, const [.text('Reset')]),
      _TrackedWorkspace(
        key: ValueKey(generation),
        generation: generation,
        operations: component.operations,
      ),
    ]);
  }
}

final class _TrackedWorkspace extends StatefulComponent {
  const _TrackedWorkspace({
    required this.generation,
    required this.operations,
    super.key,
  });

  final int generation;
  final List<String> operations;

  @override
  State<_TrackedWorkspace> createState() => _TrackedWorkspaceState();
}

final class _TrackedWorkspaceState extends State<_TrackedWorkspace> {
  @override
  Component build(BuildContext context) => const div([]);

  @override
  void dispose() {
    component.operations.add('unmount:${component.generation}');
    super.dispose();
  }
}
