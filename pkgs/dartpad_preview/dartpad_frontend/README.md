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

## Example Links

| Package / Source | Type | Description | Link |
| :--- | :--- | :--- | :--- |
| `flutter_animate` | Package | Declarative animations for Flutter | [http://localhost:8080/?package=flutter_animate](http://localhost:8080/?package=flutter_animate) |
| `fl_chart` | Package | Charts and data visualization | [http://localhost:8080/?package=fl_chart](http://localhost:8080/?package=fl_chart) |
| `provider` | Package | State management for Flutter | [http://localhost:8080/?package=provider](http://localhost:8080/?package=provider) |
| `uuid` | Package | UUID generator (Dart console output) | [http://localhost:8080/?package=uuid](http://localhost:8080/?package=uuid) |
| `material_ui` | Package | Material UI components example | [http://localhost:8080/?package=material_ui](http://localhost:8080/?package=material_ui) |
| Gist Example | Gist | Example loaded from a GitHub Gist | [http://localhost:8080/?gist=b6af57de480a26e2bf98daf235491fbc](http://localhost:8080/?gist=b6af57de480a26e2bf98daf235491fbc) |

## Running

Run the project using:

```bash
dart run jaspr_cli:jaspr serve -v
```

## Query Parameters

The frontend supports loading external projects at startup using URL query
parameters.

### Loading from Archive

To load a project from an arbitrary archive URL, you must provide the
following parameters:

* `archive`: A URI-encoded URL of a `.tar` or `.tar.gz` archive containing the
project files. The frontend downloads and extracts this project into the workspace.
* `path`: A URI-encoded relative path of the file to open in the editor workspace
once the project is loaded (e.g., `lib/main.dart`).
* `main` (optional): A URI-encoded relative path of the entrypoint file to be
executed (defaults to `path`).

> [!NOTE]
> Both `archive` and `path` query parameters must be provided together. If
> either is missing, the application will fall back to loading the default
> example project unless a `package` or `gist` parameter is provided.

Example:
```url
http://localhost:8080/?archive=https://pub.dev/api/archives/material_ui-0.0.3.tar.gz&path=example/README.md&main=example/lib/main.dart
```

When `main` is omitted, the file opened by `path` is also executed:

```url
http://localhost:8080/?archive=https://pub.dev/api/archives/material_ui-0.0.3.tar.gz&path=example/lib/main.dart
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
application falls back to loading the default example project.

## SDK assets

The precompiled Dart and Flutter SDK runtime assets are shipped with `package:dartpad`.
To copy them into `web/dartpad/`:

```text
dart run tool/copy_assets.dart
```

This copies the assets from the resolved `dartpad` package into `web/dartpad/` and
generates `versions.json` in each SDK folder.

Build the client with `dart run jaspr_cli:jaspr build` after the assets have
been copied.

