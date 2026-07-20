import 'package:path/path.dart' as p;

/// Resolves an LSP diagnostic URI to a workspace-relative file path.
///
/// If [workspaceFolder] is provided, the URI is resolved relative to it.
/// Otherwise, the last path segment is returned as a fallback.
String pathFromDiagnosticUri(String uri, {Uri? workspaceFolder}) {
  final workspacePath = _pathWithinWorkspace(uri, workspaceFolder);
  if (workspacePath != null) {
    return workspacePath;
  }

  return Uri.decodeFull(uri.split('/').last);
}

String? _pathWithinWorkspace(String uri, Uri? workspaceFolder) {
  if (workspaceFolder == null) {
    return null;
  }

  final parsedUri = Uri.tryParse(uri);
  if (parsedUri == null) {
    return null;
  }

  final workspacePath = workspaceFolder.path.endsWith('/') ? workspaceFolder.path : '${workspaceFolder.path}/';
  final isSameLocation = parsedUri.scheme == workspaceFolder.scheme && parsedUri.authority == workspaceFolder.authority;
  if (isSameLocation && parsedUri.path.startsWith(workspacePath)) {
    final relativePath = parsedUri.path.substring(workspacePath.length);
    return normalizePath(Uri.decodeFull(relativePath));
  }

  return null;
}

/// Normalizes a POSIX-style [path], returning an empty string for the current directory (`.`).
String normalizePath(String path) {
  final normalized = p.posix.normalize(path);
  return normalized == '.' ? '' : normalized;
}
