// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:js_interop';

import 'package:dartpad_frontend/features/workspace/embed_message_controller.dart';
import 'package:test/test.dart';
import 'package:web/web.dart' as web;

void send(Object? data, {bool fromParent = true}) {
  web.window.dispatchEvent(
    web.MessageEvent(
      'message',
      web.MessageEventInit(
        data: data.jsify(),
        source: fromParent ? web.window.parent : null,
        origin: 'https://docs.flutter.dev',
      ),
    ),
  );
}

void main() {
  test('ignores malformed, empty, unrelated, and non-parent messages', () async {
    final received = <String>[];
    final controller = EmbedMessageController(onSourceCode: (code) async => received.add(code));
    addTearDown(controller.dispose);
    controller.ready();
    for (final data in [
      null,
      'sourceCode',
      1,
      true,
      <Object?>[],
      <String, Object?>{},
      {'type': 'ready', 'sourceCode': 'ignored'},
      {'type': 1, 'sourceCode': 'ignored'},
      {'type': 'sourceCode'},
      {'type': 'sourceCode', 'sourceCode': null},
      {'type': 'sourceCode', 'sourceCode': 42},
      {'type': 'sourceCode', 'sourceCode': ''},
    ]) {
      send(data);
    }
    send({'type': 'sourceCode', 'sourceCode': 'wrong sender'}, fromParent: false);
    send({'type': 'sourceCode', 'sourceCode': 'accepted'});
    await pumpEventQueue();
    expect(received, ['accepted']);
  });

  test('ignores messages from a cross-origin child without accessing its properties', () async {
    final received = <String>[];
    final controller = EmbedMessageController(onSourceCode: (code) async => received.add(code));
    addTearDown(controller.dispose);
    controller.ready();
    final message = web.EventStreamProviders.messageEvent.forTarget(web.window).firstWhere(
      (event) {
        final data = event.data.dartify();
        return data is Map && data['sourceCode'] == 'cross-origin child';
      },
    );
    final child = web.HTMLIFrameElement()
      ..setAttribute('sandbox', 'allow-scripts')
      ..srcdoc = "<script>parent.postMessage({type:'sourceCode',sourceCode:'cross-origin child'}, '*');</script>".toJS;
    web.document.body!.appendChild(child);
    // JS interop methods cannot be used as tear-offs.
    // ignore: unnecessary_lambdas
    addTearDown(() => child.remove());
    await message;
    await pumpEventQueue();
    expect(received, isEmpty);
  });

  test('serializes updates and retains the latest pending code', () async {
    final received = <String>[];
    final applying = Completer<void>();
    final controller = EmbedMessageController(
      onSourceCode: (code) async {
        received.add(code);
        await applying.future;
      },
    );
    addTearDown(controller.dispose);
    send({'type': 'sourceCode', 'sourceCode': 'early'});
    await pumpEventQueue();
    expect(received, isEmpty);
    controller.ready();
    await pumpEventQueue();
    send({'type': 'sourceCode', 'sourceCode': 'intermediate'});
    send({'type': 'sourceCode', 'sourceCode': 'latest'});
    await pumpEventQueue();
    expect(received, ['early']);
    applying.complete();
    await pumpEventQueue();
    expect(received, ['early', 'latest']);
  });

  test('disposal removes the listener and discards pending code', () async {
    final received = <String>[];
    final applying = Completer<void>();
    final controller = EmbedMessageController(
      onSourceCode: (code) async {
        received.add(code);
        await applying.future;
      },
    );
    controller.ready();
    send({'type': 'sourceCode', 'sourceCode': 'first'});
    send({'type': 'sourceCode', 'sourceCode': 'pending'});
    controller.dispose();
    applying.complete();
    send({'type': 'sourceCode', 'sourceCode': 'after disposal'});
    await pumpEventQueue();
    expect(received, ['first']);
  });
}
