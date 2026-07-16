import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

extension type _LspClientHandle(JSObject _) implements JSObject {
  external JSObject createExtension(JSString uri);
  external void receiveFromServer(JSString msg);
}

@JS('window._codemirror.createLspClient')
external _LspClientHandle _createLspClient(
  JSFunction sendToServer,
  JSString rootUri,
  JSFunction onInitialized,
  JSFunction onDisplayFile,
  JSArray<NotificationHandler> notificationHandlers,
  JSAny language,
);

extension LSPClientProperties on JSObject {
  external bool get isAnalyzing;
  external set isAnalyzing(bool value);

  external JSPromise? get analysisFinished;
  external set analysisFinished(JSPromise? value);
}

@anonymous
extension type NotificationHandler._(JSObject _) implements JSObject {
  external factory NotificationHandler({JSString method, JSFunction callback});
}

@anonymous
extension type AnalyzerStatusParams._(JSObject _) implements JSObject {
  external bool get isAnalyzing;
}

/// A bidirectional JS-interop tunnel bounding the CodeMirror LSP Client logic
/// to a backend Dart LanguageServer RPC connection.
///
/// One [CodeMirrorLspClient] represents the shared language-server connection
/// for a workspace. Call [createExtension] for every editor/file that should
/// participate in that shared connection.
class CodeMirrorLspClient {
  final _LspClientHandle _handle;
  final Completer<void> _initializedCompleter = Completer<void>();
  final StreamController<bool> _analysisStatusController = StreamController<bool>.broadcast();

  CodeMirrorLspClient._(this._handle);

  /// Stream of analysis status changes (isAnalyzing).
  Stream<bool> get analysisStatus => _analysisStatusController.stream;

  /// Resolves when the LSP client successfully completes the initial
  /// `initialize` handshake with the Dart Language Server.
  Future<void> get initialized => _initializedCompleter.future;

  /// Creates a new LSP client that connects to the language server and
  /// performs the initialize handshake.
  ///
  /// The [sendToServer] callback fires whenever any editor sends an LSP
  /// request or notification.
  ///
  /// The [rootUri] anchors the virtual workspace directory used during the
  /// initialize handshake.
  factory CodeMirrorLspClient(
    void Function(String) sendToServer,
    String rootUri, {
    required Future<void> Function(String) onDisplayFile,
    required JSAny language,
  }) {
    late final CodeMirrorLspClient instance;

    Completer<void>? analysisFinishedCompleter;
    Timer? analysisTimeout;

    final notificationHandlers = [
      NotificationHandler(
        method: r'$/analyzerStatus'.toJS,
        callback: ((JSObject client, AnalyzerStatusParams params) {
          final isAnalyzing = params.isAnalyzing;

          client.isAnalyzing = isAnalyzing;
          instance._analysisStatusController.add(isAnalyzing);

          if (isAnalyzing) {
            if (client.analysisFinished == null) {
              analysisFinishedCompleter ??= Completer();
              client.analysisFinished = analysisFinishedCompleter!.future.toJS;

              analysisTimeout = Timer(const Duration(seconds: 30), () {
                final completer = analysisFinishedCompleter;
                if (completer != null && !completer.isCompleted) {
                  web.console.warn('Analyzer status timeout reached. Resolving deferred requests.'.toJS);
                  completer.complete();
                  client.analysisFinished = null;
                }
              });
            }
          } else {
            final timeout = analysisTimeout;
            if (timeout != null) {
              timeout.cancel();
              analysisTimeout = null;
            }

            final completer = analysisFinishedCompleter;
            if (completer != null && !completer.isCompleted) {
              completer.complete();
              analysisFinishedCompleter = null;
            }
            client.analysisFinished = null;
          }
          return true.toJS;
        }).toJS,
      ),
    ].toJS;

    final handle = _createLspClient(
      ((JSString msg) {
        sendToServer(msg.toDart);
      }).toJS,
      rootUri.toJS,
      (() {
        if (!instance._initializedCompleter.isCompleted) {
          instance._initializedCompleter.complete();
        }
      }).toJS,
      ((JSString uri) {
        return onDisplayFile(uri.toDart).toJS;
      }).toJS,
      notificationHandlers,
      language,
    );

    instance = CodeMirrorLspClient._(handle);
    return instance;
  }

  /// Creates a file-specific CodeMirror extension to mount into an editor.
  JSObject createExtension(String uri) => _handle.createExtension(uri.toJS);

  /// Pipes inbound JSON-RPC responses retrieved from the backend language
  /// server straight into the frontend CodeMirror evaluator.
  void receiveFromServer(String msg) {
    _handle.receiveFromServer(msg.toJS);
  }
}
