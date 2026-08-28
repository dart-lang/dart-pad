# DartPad Frontend

This package contains the browser frontend for the client-side DartPad
preview. It combines a multi-file CodeMirror editor, an in-browser Dart
workspace and analyzer, and a sandbox for running Dart and Flutter web code.
The package is part of the private `pkgs/dartpad_preview` workspace and is not
published to pub.dev.

Projects live only in the browser's in-memory workspace. Reloading the page or
choosing another sample creates a fresh workspace; there is currently no
persistent project storage.

## What the frontend provides

- A file tree and reusable editor tabs for Dart, YAML, Markdown, images, and
  other project files.
- Dart analysis, diagnostics, completion, formatting, code actions, and
  navigation through the language server running in the browser worker.
- Dependency resolution with `pub get`, plus `Pub get` and `Pub clean` actions
  when `pubspec.yaml` or `pubspec.lock` is active.
- Compilation and execution in an isolated preview sandbox, with start, stop,
  restart, and hot reload controls.
- Built-in Dart, Flutter, and Flame examples, as well as projects loaded from
  pub.dev packages, GitHub Gists, and remote tar archives.
- Responsive desktop and small-screen layouts, light and dark themes, and an
  embed mode.

Saving writes all dirty tabs to the in-memory workspace. Dart files are
formatted through the language server before they are written; if formatting
cannot complete, the file is not saved. Closing a dirty tab asks for
confirmation before discarding its changes. The root `lib/main.dart` and
`pubspec.yaml` files, and folders containing them, cannot be deleted from the
file tree.

## Development

Resolve the preview workspace dependencies, then run the frontend from its
package directory:

```bash
cd pkgs/dartpad_preview
dart pub get
cd dartpad_frontend
dart run jaspr_cli:jaspr serve -v
```

The development server is normally available at
<http://localhost:8080/>.

### SDK runtime assets

The worker, sandbox, compiler, and SDK assets are supplied by `package:dartpad`
and checked into `web/dartpad/`. To refresh them after changing the resolved
`dartpad` package, run this from `dartpad_frontend`:

```bash
dart run tool/copy_assets.dart
```

The script replaces `web/dartpad/` with the package's web assets. It also
reads the SDK versions from each `sdk.tar` and regenerates `lib/sdks.g.dart`,
which defines the SDK picker and its default. Run the script before serving or
building if those generated assets are missing or out of date.

Built-in example archives are generated separately by
`../examples/build_examples.dart`; see [the examples README](../examples/README.md)
when adding or changing a sample.

### Checks

From `dartpad_frontend`, run:

```bash
dart format --output=none --set-exit-if-changed lib test tool
dart analyze --fatal-infos
dart test
```

Tests run in Chrome as configured by `dart_test.yaml`.

## Query options

### Specifying code to load

Choose one project source per URL: an archive, a pub.dev package, a GitHub
Gist, or a bundled sample. If no source is specified, the frontend loads the
default `counter` sample.

| Query string                             | Description |
| :--------------------------------------- | :--- |
| `?archive=<url>&path=<path>`             | Load a `.tar` or `.tar.gz` archive from `<url>` and initially open `<path>`. DartPad detects gzip compression from the downloaded bytes. |
| `?archive=<url>&path=<path>&main=<main>` | Load an archive, initially open `<path>`, and use `<main>` as the run entrypoint. |
| `?package=<package>`                     | Load the latest version of `<package>` reported by pub.dev and auto-detect a file from its `example/` directory. |
| `?package=<package>&main=<main>`         | Load the latest package version, auto-detect the initially opened file, and use `<main>` as the run entrypoint. |
| `?gist=<gistId>`                         | Load the files of a public GitHub Gist. |
| `?sample=<sampleId>`                     | Load a bundled example. Valid IDs are `counter`, `sunflower`, `fibonacci`, `hello-world`, `flame-game`, `dart`, and `flutter`. |

For an archive, `archive` and `path` must be supplied together. `<path>` and
`<main>` are paths inside the extracted workspace, not URLs.

`package` always resolves the release in
the `latest` field of the pub.dev package API response.

Examples:

```text
http://localhost:8080/?package=material_ui
http://localhost:8080/?gist=b6af57de480a26e2bf98daf235491fbc
http://localhost:8080/?archive=https://pub.dev/api/archives/material_ui-0.0.3.tar.gz&path=example/README.md&main=example/lib/main.dart
```

Or open packages in the deployed preview:

| Source                  | URL |
| :---------------------- | :--- |
| flutter_animate package | [https://preview.dartpad.dev/?package=flutter_animate](https://preview.dartpad.dev/?package=flutter_animate) |
| uuid package            | [https://preview.dartpad.dev/?package=uuid](https://preview.dartpad.dev/?package=uuid) |
| example GitHub Gist     | [https://preview.dartpad.dev/?gist=b6af57de480a26e2bf98daf235491fbc](https://preview.dartpad.dev/?gist=b6af57de480a26e2bf98daf235491fbc) |
| material_ui archive     | [https://preview.dartpad.dev/?archive=https://pub.dev/api/archives/material_ui-0.0.3.tar.gz&path=example/README.md&main=example/lib/main.dart](https://preview.dartpad.dev/?archive=https://pub.dev/api/archives/material_ui-0.0.3.tar.gz&path=example/README.md&main=example/lib/main.dart) |

### Editor options

| Option or feature | Behavior |
| :---------------- | :--- |
| `?embed=true`     | Hides the app bar and footer on desktop and starts with the file tree collapsed. On small screens, only the Code/Output tab bar remains as the header. |

## SDK detection

The generated `lib/sdks.g.dart` lists the available Dart and Flutter runtime
bundles. The `tool/copy_assets.dart` script prefers the SDK with the ID `flutter`
as the default when it is present. Users can switch SDKs from the footer;
switching creates a new worker but preserves the current in-memory files.

The selected SDK determines how compiled code is started:

- The Flutter SDK uses the sandbox's Flutter bootstrap (`runApp`).
- The Dart SDK invokes the program entrypoint directly (`runMain`).

This choice is based on the selected SDK, not on the contents of
`pubspec.yaml`. Separately, the frontend searches the resolved
`.dart_tool/package_config.json` for a `flutter` package. That result controls
how output is presented: a project with Flutter resolved displays the sandbox
canvas, while a project without Flutter displays its output in the inline
console.

## Dependency resolution

The package directory used for the initial `pub get` depends on the project
source:

- For a bundled sample, the loader uses the nearest `pubspec.yaml` above its
  configured entry file. All current samples are packages rooted at the
  archive root.
- For a pub.dev package or a remote archive, the loader searches upward from
  the initially opened file for the nearest `pubspec.yaml`. If none is found,
  it treats the workspace root as the package directory and still attempts
  `pub get` there.
- For a Gist, the same upward search is used. If no `pubspec.yaml` is found,
  the package directory remains unknown and the initial `pub get` is skipped.

Before invoking `pub get`, pending in-memory changes are flushed to the worker.
Pub output is streamed to the Console panel. Once this step finishes, or fails
and is reported, startup continues with automatic execution and language-server
initialization. Opening `pubspec.yaml` or `pubspec.lock` exposes manual `Pub
get` and `Pub clean` actions for that file's directory.

When the frontend maps the executed Dart file to its library URI, it searches
upward for `.dart_tool/package_config.json`, then for `pubspec.yaml`. Files
below the resolved package's `lib/` directory receive a `package:` URI. Other
files use their workspace URI; if no package metadata exists, `lib/` files use
the fallback package name `app`.

## Entrypoint detection

The frontend distinguishes between two paths:

- the **initial editor file**, which is opened after the project is loaded;
- the **run entrypoint**, which is passed to the compiler and executed.

They are usually the same file. The `main` query parameter lets archive and
package links show one file while running another.

| Project source  | Initial editor file                                                                                  | Run entrypoint |
| :-------------- | :--------------------------------------------------------------------------------------------------- | :--- |
| Archive         | The required `path` query parameter.                                                                 | `main` when supplied; otherwise `path`. |
| pub.dev package | The first recognized example file listed below.                                                      | `main` when supplied; otherwise the detected example file. |
| GitHub Gist     | `lib/main.dart`, then `main.dart`; otherwise the only Dart file; otherwise `README.md` when present. | The same detected path. It is auto-run only when it is a Dart file. |
| Bundled sample  | The entry file recorded in `examples.g.dart`; currently `lib/main.dart` for every sample.           | The same configured entry file. |

For a pub.dev package, example-file detection checks these paths in order and
uses the first one present in the downloaded archive:

1. `example/main.dart`
2. `example/lib/main.dart`
3. `example/<package>.dart`
4. `example/lib/<package>.dart`
5. `example/<package>_example.dart`
6. `example/lib/<package>_example.dart`
7. `example/example.dart`
8. `example/lib/example.dart`
9. `example/example.md`
10. `example/README.md`

When loading a Gist, root-level Dart files are first moved under `lib/` while
non-Dart files stay at the workspace root. Detection then prefers
`lib/main.dart`, followed by `main.dart`. If neither exists, it uses the only
Dart file when there is exactly one; if there are zero or multiple Dart files,
it opens `README.md` when available. Otherwise no initial file is opened. Gist
and sample URLs do not currently support a `main` override.

After dependency resolution, the frontend automatically runs the resolved
entrypoint only if its path ends in `.dart`. The Start button is independent
of that startup choice: it runs the currently active editor file, or
`lib/main.dart` if no file is active. It does not replace an active non-Dart
file with `lib/main.dart`. Restart uses the entrypoint of the current run and
reuses the last successful compilation when one is available; Hot Reload
recompiles changes for that same running entrypoint.

Whether that entrypoint is presented as a Flutter application or a console
program is determined as described in [SDK detection](#sdk-detection).

## Startup and workspace lifecycle

The UI is rendered immediately while the dedicated WebAssembly worker and the
selected project are initialized. Once the worker is ready and the detected
entry file has been opened, the file tree and editor are usable. Initialization
then continues in the background:

1. If the loader identified a package root, the frontend flushes pending file
   changes to the worker and runs `pub get` in that directory.
2. If the resolved run entrypoint is a Dart file, it is run automatically.
3. The language server starts and publishes analysis and diagnostics to the
   editor.
