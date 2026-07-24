// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:codemirror_dart/codemirror_dart.dart';
import 'package:dartpad/dartpad.dart';
import '../workspace/workspace_controller.dart';
import '../workspace/workspace_watcher.dart';
import 'diagnostic.dart';
import 'diagnostic_uri_resolver.dart';

/// Base class for analyzer activity notifications.
sealed class AnalyzerActivity {
  /// Creates an [AnalyzerActivity].
  const AnalyzerActivity();
}

/// Indicates that diagnostics were published for a specific file.
final class AnalyzerDiagnosticsActivity extends AnalyzerActivity {
  /// Creates an [AnalyzerDiagnosticsActivity] for the given [path].
  const AnalyzerDiagnosticsActivity({required this.path});

  /// The workspace-relative path of the file that received new diagnostics.
  final String path;
}

/// Indicates a change in the analyzer's busy/idle status.
final class AnalyzerStatusActivity extends AnalyzerActivity {
  /// Creates an [AnalyzerStatusActivity] with the given [isAnalyzing] flag.
  const AnalyzerStatusActivity({required this.isAnalyzing});

  /// Whether the analyzer is currently performing analysis.
  final bool isAnalyzing;
}

/// Serializes analyzer notifications that require asynchronous preprocessing.
class _AnalyzerNotificationQueue {
  Future<void> _tail = Future<void>.value();

  /// Enqueues an analyzer notification for serial processing.
  ///
  /// If [processDiagnostics] is provided, it is awaited before [processStatus] is called.
  void enqueue({
    Future<void> Function()? processDiagnostics,
    void Function()? processStatus,
  }) {
    _tail = _tail.then((_) async {
      if (processDiagnostics != null) {
        await processDiagnostics();
      }
      processStatus?.call();
    });
  }

  /// A [Future] that completes when all currently enqueued notifications have been processed.
  Future<void> get drained => _tail;
}

/// Coordinates communication with the Dart Language Server Protocol (LSP) worker,
/// handles diagnostics, and processes filesystem edits requested by the LSP.
class LanguageServerClient {
  LanguageServerClient({
    required LanguageServer? languageServer,
    required this.workspaceController,
    void Function(Object? message)? sendToLanguageServer,
    Stream<Object?>? languageServerMessages,
    Stream<WorkspaceChangeEvent>? workspaceChangeEvents,
    CodeMirrorLspClient Function(void Function(String) sendToServer, String rootUri)? createCodeMirrorLspClient,
  }) {
    _sendToLanguageServer = sendToLanguageServer ?? languageServer!.languageServerChannel.sink.add;
    if (createCodeMirrorLspClient != null) {
      _codeMirrorLspClient = createCodeMirrorLspClient(
        (String msg) => _sendToLanguageServer(jsonDecode(msg)),
        workspaceController.workspaceUri.toString(),
      );
    } else {
      _codeMirrorLspClient = CodeMirrorLspClient(
        (String msg) => _sendToLanguageServer(jsonDecode(msg)),
        workspaceController.workspaceUri.toString(),
        onDisplayFile: (String uri) async {
          final handler = _displayFileHandler;
          if (handler != null) {
            await handler(uri);
          }
        },
        language: dart(),
      );
    }
    _languageServerSubscription = (languageServerMessages ?? languageServer!.languageServerChannel.stream).listen(
      _handleMessage,
    );
    _workspaceSubscription = (workspaceChangeEvents ?? workspaceController.watcher.events).listen((event) {
      if (event.type == WorkspaceChangeEventType.move) {
        _handleFileMoved(event.oldPath!, event.path);
      } else if (event.type == WorkspaceChangeEventType.remove) {
        _handleFileDeleted([event.path]);
      }
    });
  }

  final WorkspaceController workspaceController;
  late final void Function(Object? message) _sendToLanguageServer;

  late final StreamSubscription<WorkspaceChangeEvent> _workspaceSubscription;
  final Map<String, List<Diagnostic>> _diagnostics = {};
  final _AnalyzerNotificationQueue _analyzerNotificationQueue = _AnalyzerNotificationQueue();
  bool _isAnalyzing = false;

  /// All current diagnostics across all files, sorted by severity, file, and position.
  List<DiagnosticEntry> get allDiagnostics => sortedDiagnosticEntries(_diagnostics);

  /// Whether the language server is currently performing analysis.
  bool get isAnalyzing => _isAnalyzing;

  late final CodeMirrorLspClient _codeMirrorLspClient;

  /// The CodeMirror LSP client used to bridge CodeMirror extensions with the language server.
  CodeMirrorLspClient get codeMirrorLspClient => _codeMirrorLspClient;

  late final StreamSubscription<Object?> _languageServerSubscription;

  final StreamController<Map<String, Object?>> _diagnosticsController =
      StreamController<Map<String, Object?>>.broadcast();

  /// A broadcast stream of raw diagnostic payloads from the language server.
  Stream<Map<String, Object?>> get diagnosticsStream => _diagnosticsController.stream;

  final StreamController<AnalyzerActivity> _analyzerActivityController = StreamController<AnalyzerActivity>.broadcast();

  /// A broadcast stream of [AnalyzerActivity] events (diagnostics and status changes).
  Stream<AnalyzerActivity> get analyzerActivityStream => _analyzerActivityController.stream;

  /// A handler registered by the editor tab/view model to intercept edits
  /// and apply them in-memory/in-state if the file is currently open in CodeMirror.
  /// Should return `true` if the edits were successfully intercepted and applied.
  FutureOr<bool> Function(String file, List<Object?> edits)? _documentEditsHandler;

  /// Registers [documentEditsHandler] to intercept edits for open files.
  void setDocumentEditsHandler(
    FutureOr<bool> Function(String file, List<Object?> edits)? documentEditsHandler,
  ) {
    _documentEditsHandler = documentEditsHandler;
  }

  Future<void> Function(String uri)? _displayFileHandler;

  /// Registers [displayFileHandler] to switch tabs when the language server requests to display a file.
  void setDisplayFileHandler(Future<void> Function(String uri)? displayFileHandler) {
    _displayFileHandler = displayFileHandler;
  }

  bool Function(String file, String content)? _externalDocumentWriteHandler;

  /// Registers the editor hook used to synchronously mirror external writes
  /// into open CodeMirror documents before analyzer validation begins.
  void setExternalDocumentWriteHandler(
    bool Function(String file, String content)? externalDocumentWriteHandler,
  ) {
    _externalDocumentWriteHandler = externalDocumentWriteHandler;
  }

  /// Mirrors an agent file write into an open editor document.
  bool synchronizeExternalDocument(String file, String content) {
    return _externalDocumentWriteHandler?.call(file, content) ?? false;
  }

  /// Removes cached diagnostics that predate a new mutation of [file].
  void invalidateDiagnostics(String file) {
    _diagnostics.remove(file);
  }

  int _nextRequestId = 1;
  final Map<int, Completer<Map<String, Object?>?>> _pendingRequests = {};

  void _handleMessage(Object? message) {
    if (message is Map) {
      if (message.containsKey('id')) {
        final id = message['id'];
        final method = message['method'];
        if (method == 'workspace/applyEdit') {
          final params = message['params'] as Map<String, Object?>?;
          if (params != null) {
            final edit = params['edit'] as Map<String, Object?>?;
            if (edit != null) {
              applyWorkspaceEdit(edit)
                  .then((_) {
                    _sendToLanguageServer({
                      'jsonrpc': '2.0',
                      'id': id,
                      'result': {'applied': true},
                    });
                  })
                  .catchError((Object err) {
                    _sendToLanguageServer({
                      'jsonrpc': '2.0',
                      'id': id,
                      'error': {'code': -32603, 'message': err.toString()},
                    });
                  });
            }
          }
          return;
        }

        if (id is int && _pendingRequests.containsKey(id)) {
          final completer = _pendingRequests.remove(id)!;
          completer.complete(Map<String, Object?>.from(message));
        }
      } else {
        final method = message['method'];
        final analysisStatus = analysisStatusFromServerMessage(message);
        final diagnosticsParams = method == 'textDocument/publishDiagnostics'
            ? message['params'] as Map<String, Object?>?
            : null;
        if (diagnosticsParams != null || analysisStatus != null) {
          _analyzerNotificationQueue.enqueue(
            processDiagnostics: diagnosticsParams == null ? null : () => _handlePublishDiagnostics(diagnosticsParams),
            processStatus: analysisStatus == null ? null : () => _recordAnalysisStatus(analysisStatus),
          );
        }
      }
    }
    _codeMirrorLspClient.receiveFromServer(jsonEncode(message));
  }

  /// Sends a `workspace/willRenameFiles` request to the LSP server to let it
  /// perform refactoring (e.g. updating imports/references) before a file or folder
  /// actually gets renamed/moved in the filesystem.
  ///
  /// Any returned workspace edits are applied to the relevant files.
  Future<void> willRenameFiles(String oldPath, String newPath) async {
    final oldUri = workspaceController.workspaceUri.resolve(oldPath).toString();
    final newUri = workspaceController.workspaceUri.resolve(newPath).toString();

    final response = await sendLspRequest('workspace/willRenameFiles', {
      'files': [
        {'oldUri': oldUri, 'newUri': newUri},
      ],
    });

    if (response == null) {
      return;
    }
    final error = response['error'];
    if (error != null) {
      throw StateError('workspace/willRenameFiles failed: $error');
    }
    if (response.containsKey('result')) {
      final result = response['result'] as Map<String, Object?>?;
      if (result != null) {
        await applyWorkspaceEdit(result);
      }
    }
  }

  /// Sends a request to execute a command on the LSP server.
  Future<void> executeCommand(String command, List<Object?>? arguments) async {
    try {
      await sendLspRequest('workspace/executeCommand', {'command': command, 'arguments': ?arguments});
    } catch (e) {
      print('LSP workspace/executeCommand failed: $e');
    }
  }

  /// Sends a raw LSP JSON-RPC request and returns the parsed response map.
  Future<Map<String, Object?>?> sendLspRequest(String method, Map<String, Object?> params) {
    return _sendLspRequest(method, params);
  }

  Future<Map<String, Object?>?> _sendLspRequest(String method, Object? params) {
    final id = _nextRequestId++;
    final completer = Completer<Map<String, Object?>?>();
    _pendingRequests[id] = completer;

    final request = <String, Object?>{
      'jsonrpc': '2.0',
      'id': id,
      'method': method,
    };
    if (params != null) {
      request['params'] = params;
    }
    _sendToLanguageServer(request);
    return completer.future;
  }

  /// Applies LSP WorkspaceEdit structure (which may contain `changes` or `documentChanges`).
  Future<void> applyWorkspaceEdit(Map<String, Object?> edit) async {
    if (edit.containsKey('changes')) {
      final changes = edit['changes'] as Map?;
      if (changes != null) {
        for (final entry in changes.entries) {
          final uri = entry.key as String;
          final edits = entry.value as List<Object?>;
          await _applyEditsToFile(uri, edits);
        }
      }
    }

    if (edit.containsKey('documentChanges')) {
      final docChanges = edit['documentChanges'] as List<Object?>?;
      if (docChanges != null) {
        for (final change in docChanges) {
          if (change is Map && change.containsKey('textDocument') && change.containsKey('edits')) {
            final textDoc = change['textDocument'] as Map;
            final uri = textDoc['uri'] as String;
            final edits = change['edits'] as List<Object?>;
            await _applyEditsToFile(uri, edits);
          }
        }
      }
    }
  }

  /// Applies a list of text edits to a specific file URI.
  ///
  /// If the file is currently open in the editor, [_documentEditsHandler] intercepts
  /// and applies the edits in-memory/in-state; otherwise, the edits are applied
  /// directly to the file on disk.
  Future<void> _applyEditsToFile(String uri, List<Object?> edits) async {
    final relativePath = getRelativePath(uri, workspaceController.workspaceUri.path);
    final handler = _documentEditsHandler;
    final wasChanged = handler == null ? false : await handler(relativePath, edits);
    if (wasChanged) {
      return;
    } else {
      final file = workspaceController.root.getFile(relativePath);
      await file.writeContent(applyEdits(await file.readContent(), edits));
    }
  }

  /// Extracts the workspace-relative path from [uriString] by stripping the [folderPath] prefix.
  static String getRelativePath(String uriString, String folderPath) {
    final uri = Uri.parse(uriString);
    if (uri.path.startsWith(folderPath)) {
      return uri.path.substring(folderPath.length);
    }
    return uri.path;
  }

  /// Applies a list of LSP text edits to [text] and returns the resulting string.
  ///
  /// Edits are sorted in reverse document order so they can be applied without
  /// invalidating earlier offsets.
  static String applyEdits(String text, List<Object?> edits) {
    if (edits.isEmpty) {
      return text;
    }

    final parsedEdits = edits.map((e) => Map<String, Object?>.from(e as Map)).toList();

    parsedEdits.sort((a, b) {
      final startA = (a['range'] as Map)['start'] as Map;
      final startB = (b['range'] as Map)['start'] as Map;
      final lineA = startA['line'] as int;
      final lineB = startB['line'] as int;
      if (lineA != lineB) {
        return lineB.compareTo(lineA);
      }
      final charA = startA['character'] as int;
      final charB = startB['character'] as int;
      return charB.compareTo(charA);
    });

    final lines = text.split('\n');
    for (final edit in parsedEdits) {
      applyEdit(lines, edit);
    }
    return lines.join('\n');
  }

  /// Applies a single LSP text edit to a mutable list of [lines] in-place.
  static void applyEdit(List<String> lines, Map<String, Object?> edit) {
    final range = edit['range'] as Map;
    final start = range['start'] as Map;
    final end = range['end'] as Map;
    final newText = edit['newText'] as String;

    final startLine = start['line'] as int;
    final startChar = start['character'] as int;
    final endLine = end['line'] as int;
    final endChar = end['character'] as int;

    final newLines = newText.split('\n');

    final prefix = lines[startLine].substring(0, startChar);
    final suffix = lines[endLine].substring(endChar);

    if (newLines.isEmpty) {
      lines.replaceRange(startLine, endLine + 1, [prefix + suffix]);
    } else {
      newLines[0] = prefix + newLines[0];
      newLines[newLines.length - 1] = newLines[newLines.length - 1] + suffix;
      lines.replaceRange(startLine, endLine + 1, newLines);
    }
  }

  void _handleFileMoved(String oldPath, String newPath) {
    final diagnostics = _diagnostics.remove(oldPath);
    if (diagnostics != null) {
      _diagnostics[newPath] = diagnostics;
    }
  }

  void _handleFileDeleted(List<String> deletedFiles) {
    for (final fileName in deletedFiles) {
      _diagnostics.remove(fileName);
    }
  }

  Future<void> _handlePublishDiagnostics(Map<String, Object?> map) async {
    try {
      final uri = map['uri'] as String? ?? '';
      final fileName = pathFromDiagnosticUri(uri, workspaceFolder: workspaceController.workspaceUri);
      if (!await workspaceController.root.getFile(fileName).exists()) {
        return;
      }

      final rawList = map['diagnostics'] as List? ?? const [];
      final diagnostics = rawList
          .map((diagnostic) {
            final diagnosticMap = diagnostic as Map;
            final range = diagnosticMap['range'] as Map? ?? const {};
            final start = range['start'] as Map? ?? const {};
            return Diagnostic(
              line: (start['line'] as num?)?.toInt() ?? 0,
              character: (start['character'] as num?)?.toInt() ?? 0,
              message: diagnosticMap['message'] as String? ?? '',
              severity: DiagnosticSeverity.fromLsp(
                (diagnosticMap['severity'] as num?)?.toInt(),
              ),
              raw: Map<String, Object?>.from(diagnosticMap),
            );
          })
          .toList(growable: false);

      if (diagnostics.isEmpty) {
        _diagnostics.remove(fileName);
      } else {
        _diagnostics[fileName] = diagnostics;
      }
      _diagnosticsController.add(map);
      _analyzerActivityController.add(AnalyzerDiagnosticsActivity(path: fileName));
    } catch (_) {
      // Ignore malformed diagnostics payloads.
    }
  }

  void _recordAnalysisStatus(bool isAnalyzing) {
    _isAnalyzing = isAnalyzing;
    _analyzerActivityController.add(
      AnalyzerStatusActivity(isAnalyzing: isAnalyzing),
    );
  }

  /// Parses analyzer status from an LSP server [message].
  ///
  /// Returns `true` if analysis started, `false` if it ended, or `null` if the
  /// message is unrelated to analysis status.
  static bool? analysisStatusFromServerMessage(Map<Object?, Object?> message) {
    final method = message['method'];
    if (method == r'$/analyzerStatus') {
      final params = message['params'];
      if (params is Map) {
        final isAnalyzing = params['isAnalyzing'];
        if (isAnalyzing is bool) {
          return isAnalyzing;
        }
      }
      return null;
    }

    if (method == r'$/progress') {
      final params = message['params'];
      if (params is! Map || params['token'] != 'ANALYZING') {
        return null;
      }
      final value = params['value'];
      if (value is! Map) {
        return null;
      }
      final kind = value['kind'];
      if (kind == 'begin') {
        return true;
      }
      if (kind == 'end') {
        return false;
      }
    }
    return null;
  }

  /// Cancels all subscriptions and closes the diagnostic and activity stream controllers.
  Future<void> dispose() async {
    await _languageServerSubscription.cancel();
    await _workspaceSubscription.cancel();
    await _diagnosticsController.close();
    await _analyzerActivityController.close();
  }
}
