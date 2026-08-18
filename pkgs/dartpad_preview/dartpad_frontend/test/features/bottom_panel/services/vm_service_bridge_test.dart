// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('browser')
library;

import 'dart:async';
import 'dart:convert';

import 'package:dartpad/dartpad.dart';
import 'package:dartpad_editor/dartpad_editor.dart';
import 'package:dartpad_frontend/features/bottom_panel/services/vm_service_bridge.dart';
import 'package:dartpad_frontend/features/preview/models/compiler_session.dart';
import 'package:dartpad_frontend/features/preview/models/preview_sandbox.dart';
import 'package:dartpad_frontend/features/preview/view_models/preview_view_model.dart';
import 'package:dartpad_frontend/features/shared/app_event_bus.dart';
import 'package:dartpad_frontend/features/shared/events/open_file_event.dart';
import 'package:dartpad_frontend/features/workspace/data/workspace_repository.dart';
import 'package:test/test.dart';

class MockSandbox implements PreviewSandbox {
  final consoleController = StreamController<ConsoleMessage>.broadcast();
  final errorController = StreamController<({String message})>.broadcast();
  final rejectionController = StreamController<({String message})>.broadcast();
  final extensionEventController = StreamController<({String kind, Map<String, Object?> data})>.broadcast();

  String? lastInvokedMethod;
  Map<String, String>? lastInvokedArgs;
  String extensionResult = '{"result":{"tree":{}}}';

  @override
  void dispose() {
    consoleController.close();
    errorController.close();
    rejectionController.close();
    extensionEventController.close();
  }

  @override
  Future<void> loadModule({required String code}) async {}

  @override
  Future<void> runApp(Uri libraryUri) async {}

  @override
  Future<void> runMain(Uri libraryUri) async {}

  @override
  Future<void> hotReload({required String? code, required List<Uri> librariesToReload}) async {}

  @override
  Stream<ConsoleMessage> get onConsole => consoleController.stream;

  @override
  Stream<({String message})> get onError => errorController.stream;

  @override
  Stream<({String message})> get onUnhandledRejection => rejectionController.stream;

  @override
  Stream<({String kind, Map<String, Object?> data})> get onExtensionEvent => extensionEventController.stream;

  @override
  Future<String> invokeExtension(String method, Map<String, String> args) async {
    lastInvokedMethod = method;
    lastInvokedArgs = args;
    return extensionResult;
  }
}

class FakeWorkspaceResourceApi implements WorkspaceResourceApi {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeCompilerSession implements CompilerSession {
  @override
  Future<({String? code, List<String> compiledLibraryUris, String? log})> compile() async =>
      (code: 'compiled_code', compiledLibraryUris: <String>['package:app/main.dart'], log: 'compiled log');

  @override
  Future<void> close() async {}
}

class FakeWorkspaceRepo extends WorkspaceRepository {
  FakeWorkspaceRepo()
    : super(
        events: AppEventBus(),
        workspaceResourceApi: FakeWorkspaceResourceApi(),
        workspaceFuture: Completer<Workspace>().future,
      );

  @override
  Future<CompilerSession> startHotReloadCompiler(Uri uri) async => FakeCompilerSession();

  @override
  Future<List<PackageMapping>> getPackageMappings([String? filePath]) async {
    return [
      PackageMapping(
        name: 'my_app',
        packageUriRoot: Uri.parse('file:///workspace/pad_1/lib/'),
      ),
      PackageMapping(
        name: 'flutter',
        packageUriRoot: Uri.parse('file:///sdk/packages/flutter/lib/'),
      ),
      PackageMapping(
        name: 'collection',
        packageUriRoot: Uri.parse('file:///pub-cache/hosted/pub.dev/collection-1.0.0/lib/'),
      ),
    ];
  }

  @override
  Future<bool> hasFlutterDependency(String filePath) async => true;

  @override
  Future<Uri> get workspaceFolder async => Uri.parse('file:///workspace/pad_1/');
}

void main() {
  group('VmServiceBridge', () {
    late PreviewViewModel previewViewModel;
    late MockSandbox sandbox;
    late VmServiceBridge bridge;

    setUp(() {
      sandbox = MockSandbox();
      previewViewModel = PreviewViewModel(
        workspaceRepository: FakeWorkspaceRepo(),
        eventBus: AppEventBus(),
        createSandbox: (node, {required assetBaseUrl}) async => sandbox,
      );
      bridge = VmServiceBridge(previewViewModel: previewViewModel);
    });

    tearDown(() {
      bridge.dispose();
      previewViewModel.dispose();
    });

    test('responds to getSupportedProtocols', () async {
      String? response;
      await bridge.handleMessage(
        jsonEncode(<String, Object?>{
          'jsonrpc': '2.0',
          'id': '0',
          'method': 'getSupportedProtocols',
          'params': <String, Object?>{},
        }),
        (res) => response = res,
      );

      expect(response, isNotNull);
      final decoded = jsonDecode(response!);
      expect(decoded['id'], '0');
      expect(decoded['result']['type'], 'ProtocolList');
      expect(decoded['result']['protocols'][0]['protocolName'], 'VM Service');
    });

    test('responds to getVersion', () async {
      String? response;
      await bridge.handleMessage(
        jsonEncode(<String, Object?>{
          'jsonrpc': '2.0',
          'id': '1',
          'method': 'getVersion',
          'params': <String, Object?>{},
        }),
        (res) => response = res,
      );

      expect(response, isNotNull);
      final decoded = jsonDecode(response!);
      expect(decoded['id'], '1');
      expect(decoded['result']['type'], 'Version');
      expect(decoded['result']['major'], 3);
    });

    test('responds to getVM and getIsolate', () async {
      String? response;
      await bridge.handleMessage(
        jsonEncode(<String, Object?>{'jsonrpc': '2.0', 'id': '2', 'method': 'getVM', 'params': <String, Object?>{}}),
        (res) => response = res,
      );

      expect(response, isNotNull);
      var decoded = jsonDecode(response!);
      expect(decoded['result']['type'], 'VM');
      expect(decoded['result']['isolates'], isNotEmpty);

      await bridge.handleMessage(
        jsonEncode(<String, Object?>{
          'jsonrpc': '2.0',
          'id': '3',
          'method': 'getIsolate',
          'params': <String, Object?>{'isolateId': 'isolates/main'},
        }),
        (res) => response = res,
      );

      expect(response, isNotNull);
      decoded = jsonDecode(response!);
      expect(decoded['result']['type'], 'Isolate');
      expect(decoded['result']['extensionRPCs'], contains('ext.flutter.inspector.getRootWidget'));
    });

    test('routes extension method calls to sandbox', () async {
      // Simulate running app to have sandbox active
      await previewViewModel.runCode('package:app/main.dart');

      String? response;
      await bridge.handleMessage(
        jsonEncode(<String, Object?>{
          'jsonrpc': '2.0',
          'id': '10',
          'method': 'ext.flutter.inspector.getRootWidget',
          'params': <String, Object?>{'isolateId': 'isolates/main', 'groupName': 'tree_0'},
        }),
        (res) => response = res,
      );

      expect(sandbox.lastInvokedMethod, 'ext.flutter.inspector.getRootWidget');
      expect(sandbox.lastInvokedArgs?['groupName'], 'tree_0');
      expect(response, isNotNull);
      final decoded = jsonDecode(response!);
      expect(decoded['id'], '10');
      expect(decoded['result'], <String, Object?>{
        'result': <String, Object?>{'tree': <String, Object?>{}},
      });
    });

    test('forwards extension events on Extension stream', () async {
      final messages = <String>[];
      bridge.attachSender(messages.add);

      // Listen to Extension stream
      await bridge.handleMessage(
        jsonEncode({
          'jsonrpc': '2.0',
          'id': '100',
          'method': 'streamListen',
          'params': {'streamId': 'Extension'},
        }),
        messages.add,
      );

      await previewViewModel.runCode('package:app/main.dart');

      sandbox.extensionEventController.add((
        kind: 'Flutter.Frame',
        data: {'number': 1},
      ));

      await Future<void>.delayed(Duration.zero);

      final eventMsg = messages.firstWhere((m) => m.contains('Flutter.Frame'));
      final decoded = jsonDecode(eventMsg) as Map<String, dynamic>;
      expect(decoded['method'], 'streamNotify');
      expect(decoded['params']['streamId'], 'Extension');
      expect(decoded['params']['event']['extensionKind'], 'Flutter.Frame');
      expect(decoded['params']['event']['extensionData'], {'number': 1});
    });

    test('publishes OpenFileEvent on event bus when receiving navigate event', () async {
      OpenFileEvent? receivedEvent;
      previewViewModel.eventBus.on<OpenFileEvent>().listen((e) => receivedEvent = e);

      await previewViewModel.runCode('lib/main.dart');

      sandbox.extensionEventController.add((
        kind: 'navigate',
        data: {
          'fileUri': 'file:///workspace/pad_1/lib/main.dart',
          'line': 53,
          'column': 13,
          'source': 'flutter.inspector',
          '__destinationStream': 'ToolEvent',
        },
      ));

      await Future<void>.delayed(Duration.zero);

      expect(receivedEvent, isNotNull);
      expect(receivedEvent!.path, 'lib/main.dart');
      expect(receivedEvent!.line, 53);
      expect(receivedEvent!.column, 13);
    });

    test('lookupResolvedPackageUris converts package URIs to resolved file URIs', () async {
      final result = await bridge.lookupResolvedPackageUris('isolates/main', [
        'package:my_app/main.dart',
        'package:flutter/material.dart',
        'package:collection/collection.dart',
        'package:unknown/foo.dart',
        'file:///workspace/pad_1/lib/main.dart',
      ]);

      expect(result.uris, [
        'file:///workspace/pad_1/lib/main.dart',
        'file:///sdk/packages/flutter/lib/material.dart',
        'file:///pub-cache/hosted/pub.dev/collection-1.0.0/lib/collection.dart',
        null,
        'file:///workspace/pad_1/lib/main.dart',
      ]);
    });

    test('lookupPackageUris converts file URIs to package URIs', () async {
      final result = await bridge.lookupPackageUris('isolates/main', [
        'file:///workspace/pad_1/lib/main.dart',
        'file:///workspace/pad_1/lib/src/widget.dart',
        'file:///sdk/packages/flutter/lib/material.dart',
        'file:///pub-cache/hosted/pub.dev/collection-1.0.0/lib/src/algorithms.dart',
        'file:///workspace/pad_1/test/test.dart',
      ]);

      expect(result.uris, [
        'package:my_app/main.dart',
        'package:my_app/src/widget.dart',
        'package:flutter/material.dart',
        'package:collection/src/algorithms.dart',
        null,
      ]);
    });

    test('getSourceReport returns empty SourceReport', () async {
      final result = await bridge.getSourceReport('isolates/main', ['PossibleBreakpoints']);

      expect(result.type, 'SourceReport');
      expect(result.ranges, isEmpty);
      expect(result.scripts, isEmpty);
    });
  });
}
