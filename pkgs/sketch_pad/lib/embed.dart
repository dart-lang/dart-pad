import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'model.dart';

/// Listen to frame messages if embedded as an iFrame
/// to accept injected snippets.
void handleEmbedMessage(AppModel model) {
  final parent = web.window.parent;
  if (parent == null) return;

  web.window.addEventListener(
    'message',
    (web.Event event) {
      if (event is web.MessageEvent) {
        final data = event.data.dartify() as Map<Object?, Object?>?;
        if (data == null || data['sender'] == 'frame') {
          return;
        }

        if ((data['type'] as String?) != 'sourceCode') {
          return;
        }

        final sourceCode = data['sourceCode'];
        if (sourceCode is String && sourceCode.isNotEmpty) {
          model.sourceCodeController.text = sourceCode;
        }
      }
    }.toJS,
  );

  parent.postMessage(
    (const {'sender': 'frame', 'type': 'ready'}).jsify(),
    '*'.toJS,
  );
}
