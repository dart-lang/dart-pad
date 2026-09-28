// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('browser')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:dartpad_frontend/features/workspace/embed_runtime_controller.dart';
import 'package:test/test.dart';
import 'package:web/web.dart' as web;

const prefix = EmbedRuntimeController.storageKeyPrefix;

List<String> entryKeys() => [
  for (var i = 0; i < web.window.localStorage.length; i++)
    if (web.window.localStorage.key(i) case final key? when key.startsWith(prefix)) key,
];

Future<web.HTMLIFrameElement> createFrame({web.Element? parent}) async {
  final frame = web.HTMLIFrameElement()
    ..style.width = '200px'
    ..style.height = '100px'
    ..srcdoc = '<!doctype html><body style="margin:0;height:100px">Example</body>'.toJS;
  final loaded = web.EventStreamProviders.loadEvent.forTarget(frame).first;
  (parent ?? web.document.body!).appendChild(frame);
  await loaded;
  // JS interop methods cannot be used as tear-offs.
  // ignore: unnecessary_lambdas
  addTearDown(() => frame.remove());
  return frame;
}

void main() {
  setUp(() {
    for (final key in entryKeys()) {
      web.window.localStorage.removeItem(key);
    }
  });
  tearDown(() {
    for (final key in entryKeys()) {
      web.window.localStorage.removeItem(key);
    }
  });

  Future<({EmbedRuntimeController controller, web.Window window})> instance(void Function() onPause) async {
    final frame = await createFrame();
    final controller = EmbedRuntimeController(window: frame.contentWindow, onPause: onPause);
    addTearDown(controller.dispose);
    return (controller: controller, window: frame.contentWindow!);
  }

  test('two activations coexist; a third retires the oldest without waiting for cleanup', () async {
    var retired = 0;
    final cleanup = Completer<void>();
    final first = await instance(() {
      retired++;
      unawaited(cleanup.future);
    });
    final second = await instance(() => fail('Second should remain active'));
    final third = await instance(() => fail('Third should remain active'));
    expect(entryKeys(), isEmpty);
    first.controller.activate();
    second.controller.activate();
    await pumpEventQueue();
    expect(retired, 0);
    expect(entryKeys(), hasLength(2));
    third.controller.activate();
    expect(entryKeys(), hasLength(3));
    await pumpEventQueue();
    expect(retired, 1);
    expect(entryKeys(), hasLength(2));
    expect(cleanup.isCompleted, isFalse);
    cleanup.complete();
  });

  for (final eventType in ['focus', 'pointerdown', 'keydown']) {
    test('$eventType protects the recently used runtime; paused interaction does not reclaim a place', () async {
      var secondRetired = 0;
      final first = await instance(() => fail('Interacted instance should remain active'));
      final second = await instance(() => secondRetired++);
      final third = await instance(() => fail('Newest instance should remain active'));
      first.controller.activate();
      second.controller.activate();
      first.window.dispatchEvent(web.Event(eventType));
      third.controller.activate();
      await pumpEventQueue();
      expect(secondRetired, 1);
      final retained = entryKeys().toSet();
      second.window.dispatchEvent(web.Event(eventType));
      await pumpEventQueue();
      expect(entryKeys().toSet(), retained);
    });
  }

  test('interaction inside the preview iframe updates recency', () async {
    var secondRetired = 0;
    final first = await instance(() => fail('Preview interaction should keep the first runtime'));
    final second = await instance(() => secondRetired++);
    final third = await instance(() {});
    final container = web.HTMLDivElement();
    first.window.document.body!.appendChild(container);
    first.controller.observePreview(container);
    final preview = await createFrame(parent: container);
    await pumpEventQueue();
    first.controller.activate();
    second.controller.activate();
    preview.contentWindow!.dispatchEvent(web.Event('pointerdown'));
    third.controller.activate();
    await pumpEventQueue();
    expect(secondRetired, 1);
  });

  test('rapid writes keep separate entries and stale events cannot retire a reactivated instance', () async {
    var secondRetired = 0;
    final first = await instance(() => fail('Reactivated first instance should survive'));
    final second = await instance(() => secondRetired++);
    final third = await instance(() => fail('Third instance should survive'));
    first.controller.activate();
    second.controller.activate();
    third.controller.activate();
    first.controller.activate();
    expect(entryKeys(), hasLength(3));
    await pumpEventQueue();
    expect(secondRetired, 1);
    expect(entryKeys(), hasLength(2));
  });

  test('equal timestamps use the same UUID order in every listener', () async {
    final retired = <int>[];
    final instances = [for (var i = 0; i < 3; i++) await instance(() => retired.add(i))];
    final keys = <String>[];
    for (final item in instances) {
      final previous = entryKeys().toSet();
      item.controller.activate();
      keys.add(entryKeys().firstWhere((key) => !previous.contains(key)));
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final key in keys) {
      web.window.localStorage.setItem(key, jsonEncode({'lastSeen': now}));
    }
    await pumpEventQueue();
    final oldestKey = (keys.toList()..sort()).first;
    expect(retired, [keys.indexOf(oldestKey)]);
    expect(entryKeys(), hasLength(2));
  });

  test('purges expired and malformed entries without changing unrelated storage', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final storage = web.window.localStorage;
    storage.setItem('${prefix}expired', jsonEncode({'lastSeen': now - const Duration(hours: 7).inMilliseconds}));
    storage.setItem('${prefix}broken', '{');
    storage.setItem('embed-test-unrelated', 'keep');
    addTearDown(() => storage.removeItem('embed-test-unrelated'));
    final first = await instance(() {});
    first.controller.activate();
    expect(entryKeys(), hasLength(1));
    expect(storage.getItem('embed-test-unrelated'), 'keep');
  });

  test('pagehide releases its own entry and pauses; dispose never removes another instance', () async {
    var retired = 0;
    final first = await instance(() => retired++);
    final second = await instance(() => fail('Other instance must remain active'));
    first.controller.activate();
    second.controller.activate();
    first.window.dispatchEvent(web.Event('pagehide'));
    await pumpEventQueue();
    expect(retired, 1);
    expect(entryKeys(), hasLength(1));
    first.controller.dispose();
    expect(entryKeys(), hasLength(1));
  });
}
