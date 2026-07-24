# dartpad_editor

Editor, language-server, and workspace building blocks for client-side DartPad.
This is a private workspace package and is not published to pub.dev.

## Usage

Import the package entrypoint instead of implementation files under `lib/src`:

```dart
import 'package:dartpad_editor/dartpad_editor.dart';
```

The public API provides:

- CodeMirror editor and code-action integration;
- editor tab lifecycle and persistence controllers;
- Dart language-server diagnostics and workspace-edit handling; and
- workspace resources and consolidated file-change events.

A frontend supplies a concrete `WorkspaceController` and `EditorTabAdapter`,
then uses `TabsController` to coordinate the editor state. CodeMirror's
JavaScript bundle must be loaded as described by the sibling
`codemirror-dart` package before constructing a `CodeMirrorEditor`.

## Development

Resolve dependencies from the workspace root and run checks from this directory:

```bash
cd ..
dart pub get
cd dartpad_editor
dart format --output=none --set-exit-if-changed lib test
dart analyze --fatal-infos
dart test
```

Tests run in Chrome because the package and its dependencies use Dart-JavaScript
interop.
