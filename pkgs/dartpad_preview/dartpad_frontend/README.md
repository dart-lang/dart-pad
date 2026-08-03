# DartPad Frontend

The first browser frame renders the editor shell while the DartPad worker
creates the transient in-memory Flutter project. As soon as that workspace is
available, the file tree appears and `lib/main.dart` and `pubspec.yaml` are
opened in reusable editor tabs. LSP initialization and `pub get` continue in
the background and do not block the workspace UI.

Ctrl/Cmd+S saves every dirty tab and formats Dart files before writing. Closing
a dirty tab requires confirmation before its changes are discarded. Reloading
resets the transient project.

## Running

Run the project using:

```bash
dart run jaspr_cli:jaspr serve -v
```

## SDK assets

The generated worker and Flutter SDK artifacts are collected under the single
ignored directory `web/dartpad/`. They must be built from this exact compatible
pair:

- Dart SDK `682f45325f17dc10c33dd07c485256154715ddb9`
- Flutter `d776076fe2f7470f4da43cc6084137e5bbe35b6d`

From this package directory run:

```text
dart run tool/build_sdk_assets.dart <path-to-dart-sdk-checkout> <path-to-flutter-checkout>
```

The script rejects other revisions, builds the worker, creates the Flutter SDK
bundle, copies the outputs into `web/dartpad/`, and writes
`web/dartpad/dartpad-assets.json` with byte sizes and SHA-256 checksums. CI or
local verification can use:

```text
dart run tool/build_sdk_assets.dart --validate-only
```

Build the client with `dart run jaspr_cli:jaspr build` after the assets have
been generated.
