# DartPad Frontend

The first browser frame renders the editor shell while the DartPad worker
creates the transient in-memory Flutter project. As soon as that workspace is
available, the file tree appears and `lib/main.dart` and `pubspec.yaml` are
opened in reusable editor tabs. `pub get` continues in the background without
blocking the workspace UI, and LSP initialization starts once dependencies are
ready.

Ctrl/Cmd+S saves every dirty tab and formats Dart files before writing. Closing
a dirty tab requires confirmation before its changes are discarded. Reloading
resets the transient project.

## Running

Run the project using:

```bash
dart run jaspr_cli:jaspr serve -v
```

## Query Parameters

The frontend supports loading external projects at startup using URL query
parameters.

### Loading from Archive

To load a project from an arbitrary archive URL, you must provide both of the
following parameters:

* `archive`: A URI-encoded URL of a `.tar` or `.tar.gz` archive containing the
project files. The frontend downloads and extracts this project into the workspace.
* `path`: A URI-encoded relative path of the file to open in the editor workspace
once the project is loaded (e.g., `lib/main.dart`).

> [!NOTE]
> Both `archive` and `path` query parameters must be provided together. If
> either is missing, the application will fall back to loading the default
> sample project unless a `package` or `gist` parameter is provided.

Example:
```url
http://localhost:8080/?archive=https://pub.dev/api/archives/material_ui-0.0.3.tar.gz&path=example/README.md
```

### Loading from Package Name

To load the example project of a package published on pub.dev, use the
following parameter:

* `package`: The name of the package. The frontend fetches the latest version
of the package, extracts its archive, automatically locates the package's example
file (e.g., `example/main.dart` or `example/example.dart`), and opens it.

Example:
```url
http://localhost:8080/?package=material_ui
```

### Loading from Gist

To load a GitHub gist, provide its ID using the following parameter:

* `gist`: The ID from the GitHub Gist URL. Dart files from the gist's flat
file list are placed under `lib/`, so `main.dart` becomes `lib/main.dart`;
non-Dart files such as `pubspec.yaml` remain at the workspace root. The
resulting `lib/main.dart`, then the sole Dart file, or finally `README.md` is
opened automatically when present.

Example:
```url
http://localhost:8080/?gist=b6af57de480a26e2bf98daf235491fbc
```

> [!NOTE]
> If none of these parameter combinations is matched at startup, the
application falls back to loading the default sample project.

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
