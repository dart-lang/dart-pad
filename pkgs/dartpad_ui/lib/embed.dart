import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'model.dart';

/// Listen to frame messages if embedded as an iFrame
/// to accept injected snippets.
void handleEmbedMessage(AppServices services, {bool runOnInject = false}) {
  final parent = web.window.parent;
  if (parent == null) return;

  web.window.addEventListener(
    'message',
    (web.MessageEvent event) {
      if (event.data case _SourceCodeMessage(:final type?, :final sourceCode?)
          when type == 'sourceCode') {
        if (sourceCode.isNotEmpty) {
          services.appModel.sourceCodeController.text = sourceCode;
          if (runOnInject) {
            services.performCompileAndRun();
          }
        }
      }
    }.toJS,
  );

  parent.postMessage(
    ({'sender': web.window.name, 'type': 'ready'}).jsify(),
    '*'.toJS,
  );
}

extension type _SourceCodeMessage._(JSObject _) {
  external String? get sourceCode;
  external String? get type;
}
