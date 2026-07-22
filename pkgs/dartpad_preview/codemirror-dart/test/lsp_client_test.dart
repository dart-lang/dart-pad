// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('browser')
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:codemirror_dart/codemirror_dart.dart';
import 'package:fake_async/fake_async.dart';
import 'package:test/test.dart';

import 'browser_test_utils.dart';

void main() {
  late JSFunction originalCreateLspClient;
  late JSFunction sendToServerCallback;
  late JSFunction initializedCallback;
  late JSFunction displayFileCallback;
  late JSFunction analyzerStatusCallback;
  late JSObject fakeHandle;
  late JSObject language;
  late String capturedRootUri;
  late String createdExtensionUri;
  late String receivedMessage;

  setUpAll(verifyCodeMirrorBundleLoaded);

  setUp(() {
    originalCreateLspClient = codeMirrorNamespace.getProperty<JSFunction>(
      'createLspClient'.toJS,
    );
    fakeHandle = JSObject()
      ..setProperty(
        'createExtension'.toJS,
        ((JSString uri) {
          createdExtensionUri = uri.toDart;
          return {'uri': uri}.jsify() as JSObject;
        }).toJS,
      )
      ..setProperty(
        'receiveFromServer'.toJS,
        ((JSString message) {
          receivedMessage = message.toDart;
        }).toJS,
      );
    language = JSObject();

    codeMirrorNamespace.setProperty(
      'createLspClient'.toJS,
      ((
            JSFunction sendToServer,
            JSString rootUri,
            JSFunction onInitialized,
            JSFunction onDisplayFile,
            JSArray notificationHandlers,
            JSAny capturedLanguage,
          ) {
            sendToServerCallback = sendToServer;
            initializedCallback = onInitialized;
            displayFileCallback = onDisplayFile;
            capturedRootUri = rootUri.toDart;
            expect(capturedLanguage, same(language));

            final handler = notificationHandlers.toDart.single as JSObject;
            expect(
              handler.getProperty<JSString>('method'.toJS).toDart,
              r'$/analyzerStatus',
            );
            analyzerStatusCallback = handler.getProperty<JSFunction>(
              'callback'.toJS,
            );
            return fakeHandle;
          })
          .toJS,
    );
  });

  tearDown(() {
    codeMirrorNamespace.setProperty(
      'createLspClient'.toJS,
      originalCreateLspClient,
    );
  });

  test('bridges callbacks and delegates messages and extensions', () async {
    final outgoingMessages = <String>[];
    final displayedUris = <String>[];
    final displayCompleter = Completer<void>();
    final client = CodeMirrorLspClient(
      outgoingMessages.add,
      'file:///workspace',
      onDisplayFile: (uri) {
        displayedUris.add(uri);
        return displayCompleter.future;
      },
      language: language,
    );

    expect(capturedRootUri, 'file:///workspace');
    var initialized = false;
    unawaited(client.initialized.then((_) => initialized = true));
    await pumpEventQueue();
    expect(initialized, isFalse);

    sendToServerCallback.callAsFunction(null, 'outbound'.toJS);
    expect(outgoingMessages, ['outbound']);

    initializedCallback.callAsFunction();
    initializedCallback.callAsFunction();
    await expectLater(client.initialized, completes);

    final displayPromise =
        displayFileCallback.callAsFunction(
              null,
              'file:///other.dart'.toJS,
            )!
            as JSPromise;
    expect(displayedUris, ['file:///other.dart']);
    var displayCompleted = false;
    final displayFuture = displayPromise.toDart;
    unawaited(displayFuture.then((_) => displayCompleted = true));
    await pumpEventQueue();
    expect(displayCompleted, isFalse);
    displayCompleter.complete();
    await displayFuture;
    expect(displayCompleted, isTrue);

    final extension = client.createExtension('file:///main.dart');
    expect(createdExtensionUri, 'file:///main.dart');
    expect(
      extension.getProperty<JSString>('uri'.toJS).toDart,
      'file:///main.dart',
    );

    client.receiveFromServer('inbound');
    expect(receivedMessage, 'inbound');
  });

  test('reports analyzer status and resolves deferred analysis', () async {
    final client = CodeMirrorLspClient(
      (_) {},
      'file:///workspace',
      onDisplayFile: (_) async {},
      language: language,
    );
    final statuses = <bool>[];
    final subscription = client.analysisStatus.listen(statuses.add);
    addTearDown(subscription.cancel);
    final jsClient = JSObject();

    analyzerStatusCallback.callAsFunction(
      null,
      jsClient,
      {'isAnalyzing': true}.jsify() as JSObject,
    );
    await pumpEventQueue();

    expect(statuses, [isTrue]);
    expect(jsClient.getProperty<JSBoolean>('isAnalyzing'.toJS).toDart, isTrue);
    final analysisFinished = jsClient.getProperty<JSPromise>(
      'analysisFinished'.toJS,
    );
    var analysisCompleted = false;
    final analysisFuture = analysisFinished.toDart;
    unawaited(analysisFuture.then((_) => analysisCompleted = true));
    await pumpEventQueue();
    expect(analysisCompleted, isFalse);

    analyzerStatusCallback.callAsFunction(
      null,
      jsClient,
      {'isAnalyzing': true}.jsify() as JSObject,
    );
    expect(
      jsClient.getProperty<JSPromise>('analysisFinished'.toJS),
      same(analysisFinished),
    );

    analyzerStatusCallback.callAsFunction(
      null,
      jsClient,
      {'isAnalyzing': false}.jsify() as JSObject,
    );
    await analysisFuture;
    await pumpEventQueue();

    expect(statuses, [isTrue, isTrue, isFalse]);
    expect(jsClient.getProperty<JSAny?>('analysisFinished'.toJS), isNull);
  });

  test('releases deferred analysis when the server stops reporting', () async {
    CodeMirrorLspClient(
      (_) {},
      'file:///workspace',
      onDisplayFile: (_) async {},
      language: language,
    );
    final jsClient = JSObject();
    late JSPromise analysisFinished;

    fakeAsync((async) {
      analyzerStatusCallback.callAsFunction(
        null,
        jsClient,
        {'isAnalyzing': true}.jsify() as JSObject,
      );
      analysisFinished = jsClient.getProperty<JSPromise>(
        'analysisFinished'.toJS,
      );

      async.elapse(const Duration(seconds: 30));

      expect(jsClient.getProperty<JSAny?>('analysisFinished'.toJS), isNull);
    });

    await expectLater(analysisFinished.toDart, completes);
  });
}
