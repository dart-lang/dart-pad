// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('browser')
library;

import 'dart:async';

import 'package:dartpad_frontend/features/editor/components/main_editor_actions.dart';
import 'package:dartpad_frontend/features/shared/run_availability.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_test/client_test.dart';
import 'package:web/web.dart' as web;

final class _RunState extends ChangeNotifier implements RunAvailability {
  @override
  bool canRun = true;
}

void main() {
  late _RunState runState;

  setUp(() => runState = _RunState());
  tearDown(() => runState.dispose());

  MainEditorActions createActions({
    required String activeFile,
    required String Function() getContent,
    required Future<void> Function(String path) onRun,
    Stream<void> tabUpdates = const Stream.empty(),
  }) => MainEditorActions(
    activeFile: activeFile,
    getContent: getContent,
    tabUpdates: tabUpdates,
    runAvailability: runState,
    onRun: onRun,
  );

  Future<void> waitForContentDebounce() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    await pumpEventQueue();
  }

  testClient('renders Run action for a Dart file containing main()', (tester) {
    tester.pumpComponent(
      createActions(
        activeFile: 'lib/main.dart',
        getContent: () => 'void main() { print("hello"); }',
        onRun: (_) async {},
      ),
    );

    expect(web.document.querySelector('.main-editor-actions'), isNotNull);
    final button = web.document.querySelector('[aria-label="Run"]') as web.HTMLButtonElement?;
    expect(button, isNotNull);
    expect(button!.textContent?.trim(), 'Run');
    expect(button.disabled, isFalse);
  });

  testClient('does not render action for a Dart file without main()', (tester) {
    tester.pumpComponent(
      createActions(
        activeFile: 'lib/utils.dart',
        getContent: () => 'void helper() {}',
        onRun: (_) async {},
      ),
    );

    expect(web.document.querySelector('.main-editor-actions'), isNull);
    expect(web.document.querySelector('[aria-label="Run"]'), isNull);
  });

  testClient('does not render action for non-Dart files even if content has main', (tester) {
    tester.pumpComponent(
      createActions(
        activeFile: 'pubspec.yaml',
        getContent: () => 'name: my_app\n# void main() {}',
        onRun: (_) async {},
      ),
    );

    expect(web.document.querySelector('.main-editor-actions'), isNull);
  });

  testClient('updates dynamically via tabUpdates stream and getContent callback', (tester) async {
    final updatesController = StreamController<void>.broadcast();
    String liveContent = 'int a = 1;';

    tester.pumpComponent(
      createActions(
        activeFile: 'lib/main.dart',
        getContent: () => liveContent,
        tabUpdates: updatesController.stream,
        onRun: (_) async {},
      ),
    );
    await waitForContentDebounce();
    expect(web.document.querySelector('.main-editor-actions'), isNull);

    // User types main() into the editor
    liveContent = 'void main() {}';
    updatesController.add(null);
    await waitForContentDebounce();

    expect(web.document.querySelector('.main-editor-actions'), isNotNull);

    // User deletes main()
    liveContent = 'int a = 2;';
    updatesController.add(null);
    await waitForContentDebounce();

    expect(web.document.querySelector('.main-editor-actions'), isNull);
    await updatesController.close();
  });

  testClient('debounces rapid editor updates', (tester) async {
    final updatesController = StreamController<void>.broadcast();
    var contentReads = 0;
    var liveContent = 'int a = 1;';

    tester.pumpComponent(
      createActions(
        activeFile: 'lib/main.dart',
        getContent: () {
          contentReads++;
          return liveContent;
        },
        tabUpdates: updatesController.stream,
        onRun: (_) async {},
      ),
    );
    expect(contentReads, 1);

    for (final content in ['void m', 'void main(', 'void main() {}']) {
      liveContent = content;
      updatesController.add(null);
    }
    await waitForContentDebounce();

    expect(contentReads, 2);
    expect(web.document.querySelector('.main-editor-actions'), isNotNull);
    await updatesController.close();
  });

  testClient('renders action after updating content to include main()', (tester) async {
    tester.pumpComponent(
      createActions(
        activeFile: 'lib/main.dart',
        getContent: () => 'int counter = 0;',
        onRun: (_) async {},
      ),
    );
    await pumpEventQueue();
    expect(web.document.querySelector('.main-editor-actions'), isNull);

    tester.pumpComponent(
      createActions(
        activeFile: 'lib/main.dart',
        getContent: () => 'void main() => runApp();',
        onRun: (_) async {},
      ),
    );
    await pumpEventQueue();

    expect(web.document.querySelector('.main-editor-actions'), isNotNull);
    expect(web.document.querySelector('[aria-label="Run"]'), isNotNull);
  });

  testClient('hides action after removing main()', (tester) async {
    tester.pumpComponent(
      createActions(
        activeFile: 'lib/main.dart',
        getContent: () => 'void main() {}',
        onRun: (_) async {},
      ),
    );
    await pumpEventQueue();
    expect(web.document.querySelector('.main-editor-actions'), isNotNull);

    tester.pumpComponent(
      createActions(
        activeFile: 'lib/main.dart',
        getContent: () => '// void main() {} removed',
        onRun: (_) async {},
      ),
    );
    await pumpEventQueue();

    expect(web.document.querySelector('.main-editor-actions'), isNull);
  });

  testClient('runs active file when clicked', (tester) async {
    String? executedPath;
    tester.pumpComponent(
      createActions(
        activeFile: 'lib/main.dart',
        getContent: () => 'void main() {}',
        onRun: (path) async => executedPath = path,
      ),
    );

    final button = web.document.querySelector('[aria-label="Run"]')! as web.HTMLButtonElement;
    button.click();
    await pumpEventQueue();

    expect(executedPath, 'lib/main.dart');
  });

  testClient('disables action when the preview cannot run', (tester) {
    runState.canRun = false;
    tester.pumpComponent(
      createActions(
        activeFile: 'lib/main.dart',
        getContent: () => 'void main() {}',
        onRun: (_) async {},
      ),
    );

    final button = web.document.querySelector('[aria-label="Run"]')! as web.HTMLButtonElement;
    expect(button.disabled, isTrue);
  });

  testClient('disables action while run is in progress', (tester) async {
    final completer = Completer<void>();
    tester.pumpComponent(
      createActions(
        activeFile: 'bin/server.dart',
        getContent: () => 'Future<void> main() async {}',
        onRun: (_) => completer.future,
      ),
    );

    final button = web.document.querySelector('[aria-label="Run"]')! as web.HTMLButtonElement;
    expect(button.disabled, isFalse);

    button.click();
    await pumpEventQueue();

    expect(button.disabled, isTrue);

    completer.complete();
    await pumpEventQueue();

    expect(button.disabled, isFalse);
  });

  testClient('ignores repeated clicks while run is in progress', (tester) async {
    final completer = Completer<void>();
    final runs = <String>[];
    tester.pumpComponent(
      createActions(
        activeFile: 'bin/server.dart',
        getContent: () => 'void main() {}',
        onRun: (path) async {
          runs.add(path);
          await completer.future;
        },
      ),
    );

    final button = web.document.querySelector('[aria-label="Run"]')! as web.HTMLButtonElement;
    button.click();
    await pumpEventQueue();
    button.click();
    await pumpEventQueue();

    expect(runs, ['bin/server.dart']);

    completer.complete();
    await pumpEventQueue();
  });
}
