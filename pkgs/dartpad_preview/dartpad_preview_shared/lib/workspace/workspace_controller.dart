import 'dart:typed_data';

import 'package:dartpad/dartpad.dart';

import '../lsp/language_server_client.dart';
import 'workspace_resource.dart';
import 'workspace_watcher.dart';

/// An abstract controller class that coordinates workspace state,
/// manages file system watching, and communicates with the underlying [LanguageServer].
abstract class WorkspaceController implements WorkspaceApi {
  /// Creates a [WorkspaceController] and initializes both the
  /// [watcher] to track file system changes and the [languageServerClient]
  /// to communicate with the language server.
  WorkspaceController({
    required this.workspace,
    required LanguageServer languageServer,
  }) {
    watcher = WorkspaceChangeWatcher(fileChanges: workspace.watch(workspace.workspaceFolder.toString()).changes)..watchFileSystem();
    languageServerClient = LanguageServerClient(
      languageServer: languageServer,
      workspaceController: this,
    );
  }

  /// The underlying [Workspace] environment containing project files and configurations.
  final Workspace workspace;

  /// The watcher responsible for monitoring file system changes in the workspace.
  late final WorkspaceChangeWatcher watcher;

  /// The [Uri] of the workspace folder.
  Uri get workspaceUri => workspace.workspaceFolder;

  /// The root [WorkspaceFolder] of the workspace.
  WorkspaceFolder get root => WorkspaceFolder(workspace: this, path: '');

  /// The language server client used to communicate with the [LanguageServer].
  late final LanguageServerClient languageServerClient;

  // -- WorkspaceApi implementation --

  @override
  int get id => workspace.id;

  @override
  Future<bool> fileExist(String uri) => workspace.fileExist(uri);

  @override
  Future<bool> folderExist(String uri) => workspace.folderExist(uri);

  @override
  Future<String> readFileAsText(String uri) => workspace.readFileAsText(uri);

  @override
  Future<Uint8List> readFileAsBytes(String uri) => workspace.readFileAsBytes(uri);

  @override
  Future<void> writeFileFromText(String uri, String content) => workspace.writeFileFromText(uri, content);

  @override
  Future<void> writeFileFromBytes(String uri, Uint8List bytes) => workspace.writeFileFromBytes(uri, bytes);

  @override
  Future<void> createFolder(String uri) => workspace.createFolder(uri);

  @override
  Future<void> deleteFileSystemEntity(String uri) => workspace.deleteFileSystemEntity(uri);

  @override
  Future<List<({String path, String type})>> listDirectory({required String uri, bool recursive = false}) =>
      workspace.listDirectory(uri: uri, recursive: recursive);

  @override
  void addMoveIntention(String oldPath, String newPath) {
    watcher.addMoveIntention(oldPath, newPath);
  }
}
