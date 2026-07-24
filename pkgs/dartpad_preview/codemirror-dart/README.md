# codemirror-dart

A private Dart wrapper around the CodeMirror 6 text editor used by client-side DartPad.

This directory contains both a Dart package and the TypeScript sources used to
build the JavaScript bundle consumed through Dart JS interop. It is an internal
workspace package and is not published to npm or pub.dev.

## Setup

Install and build the analyzer-backed language package first, then install this
package's dependencies:

```bash
cd ../codemirror-lang-dart
npm ci
npm run build

cd ../codemirror-dart
dart pub get
npm ci
```

## Build

```bash
npm run build
```

The build produces `lib/assets/codemirror-dart.bundle.js` and its corresponding
`THIRD_PARTY_NOTICES.txt`. Both generated files are checked in. The build script
normalizes them so that rebuilding is deterministic and passes repository
whitespace checks.

## Use from Dart

Load `lib/assets/codemirror-dart.bundle.js` before calling any package API. The
bundle installs the `window._codemirror` namespace used by the Dart bindings.

```dart
import 'dart:js_interop';

import 'package:codemirror_dart/codemirror_dart.dart';
import 'package:web/web.dart' as web;

final state = EditorState.create(
  EditorStateConfig(
    doc: 'void main() {}'.toJS,
    extensions: [basicSetup, dart()].toJS,
  ),
);

final view = EditorView(
  EditorViewConfig(
    state: state,
    parent: web.document.querySelector('#editor') as web.HTMLElement,
  ),
);
```

Create one `CodeMirrorLspClient` per workspace and add the result of
`createExtension(uri)` to each file's editor extensions. Forward outbound JSON-RPC
messages from `sendToServer` to the Dart Language Server, and pass inbound
messages back through `receiveFromServer`.

## Tests and checks

```bash
npm run typecheck
npm test
dart test --platform chrome
dart analyze --fatal-infos
dart format --output=none --set-exit-if-changed lib test
```
