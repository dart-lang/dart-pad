import 'dart:async';

import 'package:codemirror_dart/codemirror_dart.dart';
import 'package:dartpad/dartpad.dart';
import 'package:dartpad_preview_shared/lsp/language_server_client.dart';
import 'package:dartpad_preview_shared/workspace/workspace_controller.dart';
import 'package:dartpad_preview_shared/workspace/workspace_resource.dart';
import 'package:dartpad_preview_shared/workspace/workspace_watcher.dart';
import 'package:test/test.dart';

Map<String, dynamic> _edit(
  int startLine,
  int startChar,
  int endLine,
  int endChar,
  String newText,
) => {
  'range': {
    'start': {'line': startLine, 'character': startChar},
    'end': {'line': endLine, 'character': endChar},
  },
  'newText': newText,
};

class FakeWorkspace implements WorkspaceApi {
  final Map<String, String> files = {};
  Error? writeError;

  @override
  int get id => 0;

  @override
  Uri get workspaceFolder => Uri.parse('file:///workspace/');



  @override
  Future<bool> fileExist(String uri) async => files.containsKey(uri);

  @override
  Future<String> readFileAsText(String uri) async => files[uri]!;

  @override
  Future<void> writeFileFromText(String uri, String text) async {
    if (writeError case final error?) {
      throw error;
    }
    files[uri] = text;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeWorkspaceController implements WorkspaceController {
  FakeWorkspaceController(this.fakeWorkspace);

  final FakeWorkspace fakeWorkspace;

  @override
  Workspace get workspace => throw UnimplementedError('Use fakeWorkspace in tests');

  @override
  Uri get workspaceUri => fakeWorkspace.workspaceFolder;

  @override
  WorkspaceFolder get root => WorkspaceFolder(workspace: this, path: '');

  // WorkspaceApi delegates
  @override
  int get id => fakeWorkspace.id;
  @override
  Uri get workspaceFolder => fakeWorkspace.workspaceFolder;
  @override
  Future<bool> fileExist(String uri) => fakeWorkspace.fileExist(uri);
  @override
  Future<String> readFileAsText(String uri) => fakeWorkspace.readFileAsText(uri);
  @override
  Future<void> writeFileFromText(String uri, String content) => fakeWorkspace.writeFileFromText(uri, content);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeCodeMirrorLspClient implements CodeMirrorLspClient {
  final List<String> receivedMessages = [];

  @override
  void receiveFromServer(String msg) => receivedMessages.add(msg);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('LanguageServerClient integration', () {
    late FakeWorkspace workspace;
    late FakeCodeMirrorLspClient codeMirrorClient;
    late StreamController<Object?> serverMessages;
    late StreamController<WorkspaceChangeEvent> workspaceEvents;
    late List<Object?> sentMessages;
    late StreamController<Object?> outgoingMessages;
    late LanguageServerClient client;

    setUp(() {
      workspace = FakeWorkspace();
      codeMirrorClient = FakeCodeMirrorLspClient();
      serverMessages = StreamController<Object?>();
      workspaceEvents = StreamController<WorkspaceChangeEvent>(sync: true);
      sentMessages = [];
      outgoingMessages = StreamController<Object?>.broadcast();
      client = LanguageServerClient(
        languageServer: null,
        workspaceController: FakeWorkspaceController(workspace),
        sendToLanguageServer: (message) {
          sentMessages.add(message);
          outgoingMessages.add(message);
        },
        languageServerMessages: serverMessages.stream,
        workspaceChangeEvents: workspaceEvents.stream,
        createCodeMirrorLspClient: (_, _) => codeMirrorClient,
      );
    });

    tearDown(() async {
      client.dispose();
      await serverMessages.close();
      await workspaceEvents.close();
      await outgoingMessages.close();
    });

    test('serializes diagnostics and analyzer status into observable state', () async {
      workspace.files['lib/main.dart'] = 'void main() {}';
      final activitiesFuture = client.analyzerActivityStream.take(2).toList();

      serverMessages.add({
        'method': 'textDocument/publishDiagnostics',
        'params': {
          'uri': 'file:///workspace/lib/main.dart',
          'diagnostics': [
            {
              'range': {
                'start': {'line': 2, 'character': 4},
                'end': {'line': 2, 'character': 8},
              },
              'message': 'A problem',
              'severity': 2,
            },
          ],
        },
      });
      serverMessages.add({
        'method': r'$/analyzerStatus',
        'params': {'isAnalyzing': true},
      });

      final activities = await activitiesFuture;
      expect(activities[0], isA<AnalyzerDiagnosticsActivity>());
      expect(activities[1], isA<AnalyzerStatusActivity>());
      expect(client.isAnalyzing, isTrue);
      expect(client.allDiagnostics, hasLength(1));
      expect(client.allDiagnostics.single.fileName, 'lib/main.dart');
      expect(client.allDiagnostics.single.diagnostic.message, 'A problem');
      expect(client.allDiagnostics.single.diagnostic.severity.name, 'warning');
      expect(codeMirrorClient.receivedMessages, hasLength(2));

      serverMessages.add({
        'method': 'textDocument/publishDiagnostics',
        'params': {
          'uri': 'file:///workspace/missing.dart',
          'diagnostics': [
            {'message': 'stale'},
          ],
        },
      });
      await pumpEventQueue();
      expect(client.allDiagnostics.single.fileName, 'lib/main.dart');
    });

    test('moves and removes cached diagnostics with workspace events', () async {
      workspace.files['old.dart'] = '';
      final diagnosticActivity = client.analyzerActivityStream.first;
      serverMessages.add({
        'method': 'textDocument/publishDiagnostics',
        'params': {
          'uri': 'file:///workspace/old.dart',
          'diagnostics': [
            {
              'range': {
                'start': {'line': 0, 'character': 0},
              },
              'message': 'problem',
            },
          ],
        },
      });
      await diagnosticActivity;

      workspaceEvents.add(
        WorkspaceChangeEvent(
          type: WorkspaceChangeEventType.move,
          path: 'new.dart',
          oldPath: 'old.dart',
        ),
      );
      expect(client.allDiagnostics.single.fileName, 'new.dart');

      workspaceEvents.add(
        WorkspaceChangeEvent(
          type: WorkspaceChangeEventType.remove,
          path: 'new.dart',
        ),
      );
      expect(client.allDiagnostics, isEmpty);
    });

    test('routes workspace edits to open documents or persistent files', () async {
      workspace.files['closed.dart'] = 'hello world';
      final intercepted = <String, List<dynamic>>{};
      client.setDocumentEditsHandler((file, edits) {
        if (file != 'open.dart') {
          return false;
        }
        intercepted[file] = edits;
        return true;
      });

      await client.applyWorkspaceEdit({
        'changes': {
          'file:///workspace/open.dart': [_edit(0, 0, 0, 0, 'open')],
          'file:///workspace/closed.dart': [_edit(0, 6, 0, 11, 'Dart')],
        },
      });

      expect(intercepted['open.dart'], hasLength(1));
      expect(workspace.files['closed.dart'], 'hello Dart');
      expect(workspace.files, isNot(contains('open.dart')));
    });

    test('applies documentChanges and completes matching JSON-RPC requests', () async {
      workspace.files['main.dart'] = 'old';
      await client.applyWorkspaceEdit({
        'documentChanges': [
          {
            'textDocument': {'uri': 'file:///workspace/main.dart'},
            'edits': [_edit(0, 0, 0, 3, 'new')],
          },
        ],
      });
      expect(workspace.files['main.dart'], 'new');

      final responseFuture = client.sendLspRequest('example/request', {'value': 1});
      expect(sentMessages.single, {
        'jsonrpc': '2.0',
        'id': 1,
        'method': 'example/request',
        'params': {'value': 1},
      });
      serverMessages.add({
        'jsonrpc': '2.0',
        'id': 1,
        'result': {'ok': true},
      });
      expect(await responseFuture, containsPair('result', {'ok': true}));
    });

    test('answers server-initiated workspace edit requests', () async {
      workspace.files['main.dart'] = 'old';
      final response = outgoingMessages.stream.first;
      serverMessages.add({
        'jsonrpc': '2.0',
        'id': 42,
        'method': 'workspace/applyEdit',
        'params': {
          'edit': {
            'changes': {
              'file:///workspace/main.dart': [_edit(0, 0, 0, 3, 'new')],
            },
          },
        },
      });

      await response;
      expect(workspace.files['main.dart'], 'new');
      expect(sentMessages, [
        {
          'jsonrpc': '2.0',
          'id': 42,
          'result': {'applied': true},
        },
      ]);
    });

    test('reports failed server-initiated workspace edits as JSON-RPC errors', () async {
      workspace
        ..files['main.dart'] = 'old'
        ..writeError = StateError('write failed');
      final response = outgoingMessages.stream.first;

      serverMessages.add({
        'jsonrpc': '2.0',
        'id': 43,
        'method': 'workspace/applyEdit',
        'params': {
          'edit': {
            'changes': {
              'file:///workspace/main.dart': [_edit(0, 0, 0, 3, 'new')],
            },
          },
        },
      });

      expect(await response, {
        'jsonrpc': '2.0',
        'id': 43,
        'error': {
          'code': -32603,
          'message': contains('write failed'),
        },
      });
      expect(workspace.files['main.dart'], 'old');
    });
  });

  group('text edit helpers', () {
    test('applyEdit handles insertion, deletion, and multiline replacement', () {
      final cases = <(List<String>, Map<String, dynamic>, List<String>)>[
        (['hello world'], _edit(0, 6, 0, 11, 'dart'), ['hello dart']),
        (['ab'], _edit(0, 1, 0, 1, 'XY'), ['aXYb']),
        (['hello world'], _edit(0, 5, 0, 11, ''), ['hello']),
        (['aaa', 'bbb', 'ccc'], _edit(0, 1, 2, 2, 'X'), ['aXc']),
        (['abc'], _edit(0, 1, 0, 2, 'X\nY\nZ'), ['aX', 'Y', 'Zc']),
        (['hello'], _edit(0, 0, 0, 0, 'OK '), ['OK hello']),
        (['hello'], _edit(0, 5, 0, 5, '!'), ['hello!']),
      ];

      for (final (input, edit, expected) in cases) {
        LanguageServerClient.applyEdit(input, edit);
        expect(input, expected, reason: 'edit: $edit');
      }
    });

    test('applyEdits returns unchanged text for an empty edit list', () {
      expect(LanguageServerClient.applyEdits('hello\nworld', []), 'hello\nworld');
    });

    test('applyEdits sorts edits in reverse document order', () {
      expect(
        LanguageServerClient.applyEdits(
          'aaa\nbbb\nccc',
          [
            _edit(0, 0, 0, 0, 'new\n'),
            _edit(2, 0, 2, 3, 'CCC'),
          ],
        ),
        'new\naaa\nbbb\nCCC',
      );
      expect(
        LanguageServerClient.applyEdits(
          'abcdef',
          [
            _edit(0, 0, 0, 1, 'AAAA'),
            _edit(0, 4, 0, 6, 'EF'),
          ],
        ),
        'AAAAbcdEF',
      );
    });
  });

  test('getRelativePath strips only matching folder prefixes', () {
    final cases = <(String, String, String)>[
      ('file:///workspace/project/lib/main.dart', '/workspace/project/', 'lib/main.dart'),
      ('file:///other/path/main.dart', '/workspace/project/', '/other/path/main.dart'),
      ('/workspace/project/lib/main.dart', '/workspace/project/', 'lib/main.dart'),
      ('file:///src/main.dart', '/', 'src/main.dart'),
      ('file:///workspace-extra/main.dart', '/workspace/', '/workspace-extra/main.dart'),
    ];

    for (final (uri, folder, expected) in cases) {
      expect(LanguageServerClient.getRelativePath(uri, folder), expected);
    }
  });

  group('analysisStatusFromServerMessage', () {
    test('parses supported analyzer status messages', () {
      final cases = <(Map<String, Object?>, bool)>[
        (
          {
            'method': r'$/analyzerStatus',
            'params': {'isAnalyzing': true},
          },
          true,
        ),
        (
          {
            'method': r'$/analyzerStatus',
            'params': {'isAnalyzing': false},
          },
          false,
        ),
        (
          {
            'method': r'$/progress',
            'params': {
              'token': 'ANALYZING',
              'value': {'kind': 'begin'},
            },
          },
          true,
        ),
        (
          {
            'method': r'$/progress',
            'params': {
              'token': 'ANALYZING',
              'value': {'kind': 'end'},
            },
          },
          false,
        ),
      ];

      for (final (message, expected) in cases) {
        expect(LanguageServerClient.analysisStatusFromServerMessage(message), expected);
      }
    });

    test('rejects malformed and unrelated status messages', () {
      final messages = <Map<String, Object?>>[
        {'method': r'$/analyzerStatus'},
        {
          'method': r'$/analyzerStatus',
          'params': {'isAnalyzing': 'yes'},
        },
        {'method': r'$/analyzerStatus', 'params': 'invalid'},
        {
          'method': r'$/progress',
          'params': {
            'token': 'OTHER',
            'value': {'kind': 'begin'},
          },
        },
        {
          'method': r'$/progress',
          'params': {'token': 'ANALYZING', 'value': 'invalid'},
        },
        {
          'method': r'$/progress',
          'params': {
            'token': 'ANALYZING',
            'value': {'kind': 'report'},
          },
        },
        {'method': 'textDocument/didOpen'},
        {'id': 1},
      ];

      for (final message in messages) {
        expect(LanguageServerClient.analysisStatusFromServerMessage(message), isNull);
      }
    });
  });
}
