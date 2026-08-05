// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('browser')
library;

import 'package:dartpad_frontend/features/editor/components/pubspec_editor_actions.dart';
import 'package:jaspr_test/client_test.dart';
import 'package:web/web.dart' as web;

void main() {
  testClient('runs root pubspec actions in the workspace root', (tester) async {
    String? pubGetPath;
    String? pubCleanPath;
    tester.pumpComponent(
      PubspecEditorActions(
        activeFile: 'pubspec.yaml',
        busy: false,
        onPubGet: (path) async => pubGetPath = path,
        onPubClean: (path) async => pubCleanPath = path,
      ),
    );

    (web.document.querySelector('[aria-label="Pub get"]')! as web.HTMLButtonElement).click();
    (web.document.querySelector('[aria-label="Pub clean"]')! as web.HTMLButtonElement).click();
    await pumpEventQueue();

    expect(pubGetPath, '');
    expect(pubCleanPath, '');
  });

  testClient('uses the directory of a nested pubspec lock', (tester) async {
    String? pubGetPath;
    tester.pumpComponent(
      PubspecEditorActions(
        activeFile: 'packages/example/pubspec.lock',
        busy: false,
        onPubGet: (path) async => pubGetPath = path,
        onPubClean: (_) async {},
      ),
    );

    (web.document.querySelector('[aria-label="Pub get"]')! as web.HTMLButtonElement).click();
    await pumpEventQueue();

    expect(pubGetPath, 'packages/example');
  });

  testClient('does not render actions for other active files', (tester) {
    tester.pumpComponent(
      PubspecEditorActions(
        activeFile: 'packages/example/analysis_options.yaml',
        busy: false,
        onPubGet: (_) async {},
        onPubClean: (_) async {},
      ),
    );

    expect(web.document.querySelector('.pubspec-editor-actions'), isNull);
  });

  testClient('disables both actions while busy', (tester) {
    tester.pumpComponent(
      PubspecEditorActions(
        activeFile: 'packages/example/pubspec.yaml',
        busy: true,
        onPubGet: (_) async {},
        onPubClean: (_) async {},
      ),
    );

    final pubGet = web.document.querySelector('[aria-label="Pub get"]')! as web.HTMLButtonElement;
    final pubClean = web.document.querySelector('[aria-label="Pub clean"]')! as web.HTMLButtonElement;
    expect(pubGet.disabled, isTrue);
    expect(pubClean.disabled, isTrue);
  });
}
