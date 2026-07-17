import 'package:dartpad/dartpad.dart';

import '../lsp/language_server_client.dart';
import 'workspace_resource.dart';
import 'workspace_watcher.dart';

/// An abstract controller class that coordinates workspace state,
/// manages file system watching, and communicates with the underlying [LanguageServer].
abstract class WorkspaceController {
  /// Creates a [WorkspaceController] and initializes both the
  /// [watcher] to track file system changes and the [languageServerClient]
  /// to communicate with the language server.
  WorkspaceController({
    required this.workspace,
    required LanguageServer languageServer,
  }) {
    watcher = WorkspaceWatcher(workspace: workspace)..watchFileSystem();
    languageServerClient = LanguageServerClient(
      languageServer: languageServer,
      workspaceController: this,
    );
  }

  /// The underlying [Workspace] environment containing project files and configurations.
  final Workspace workspace;

  /// The watcher responsible for monitoring file system changes in the workspace.
  late final WorkspaceWatcher watcher;

  /// The [Uri] of the workspace folder.
  Uri get workspaceUri => workspace.workspaceFolder;

  /// The root [WorkspaceFolder] of the workspace.
  WorkspaceFolder get root => WorkspaceFolder(workspace: workspace, path: '');

  /// The language server client used to communicate with the [LanguageServer].
  late final LanguageServerClient languageServerClient;
}
