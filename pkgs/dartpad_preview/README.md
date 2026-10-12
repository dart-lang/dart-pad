# DartPad Preview

DartPad Preview lets users edit and run Dart and Flutter code in the browser,
with analysis and compilation running locally in a WebWorker. This workspace
contains the Jaspr frontend, CodeMirror integration, editor package, and bundled
examples.

## Link or embed

### Project source

Choose one source per URL.

| Query                              | Source                                                                                  |
| ---------------------------------- | --------------------------------------------------------------------------------------- |
| `sample=<id>`                      | Bundled sample: `counter`, `sunflower`, `fibonacci`, `flame-game`, `dart`, or `flutter` |
| `gist=<id>`                        | GitHub Gist                                                                             |
| `package=<name>`                   | Latest version of a pub.dev package                                                     |
| `package=<name>&version=<version>` | Exact pub.dev package version; `version` requires `package`                             |
| `url=<url>`                        | Tar archive, optionally gzip compressed;                                                |

### Project configuration

| Query                            | Effect                                                                                            | Default                                                                                               |
| -------------------------------- | ------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------- |
| `file=<path>`                    | Initial editor tab; repeat for multiple tabs in order, with the first active                      | The root README or resolved entrypoint                                                                |
| `root=<path>`                    | Directory for the file tree, analysis, and dependency resolution; `root=` selects the source root | Common package root of explicit files and entrypoint, otherwise source root                           |
| `entrypoint=<path>`              | File executed by Run, independent of the active tab                                               | First initial Dart file with a top-level `main`, then `<root>/lib/main.dart`, then `<root>/main.dart` |
| `sdk=dart` or `sdk=flutter`      | SDK kind; append `:<version>` to select an exact bundled version                                  | Inferred from the root pubspec or Gist imports; first available bundle of that kind                   |
| `mode=console` or `mode=flutter` | Execution mode; Flutter mode requires a Flutter SDK                                               | Flutter with a Flutter SDK, except entrypoints under `bin/`, `test/`, or `tool/`; otherwise console   |

- All paths are source-relative, including when `root` is set. For example,
  `root=example&file=example/lib/main.dart`.
- Gists move root-level Dart files into `lib/`; original paths such as
  `file=main.dart&entrypoint=main.dart` still work.
- SDK versions must be available in the [bundled SDK list](dartpad_frontend/lib/sdks.g.dart).

### Appearance and execution

| Query                         | Effect                                                                                        | Default                                          |
| ----------------------------- | --------------------------------------------------------------------------------------------- | ------------------------------------------------ |
| `embed=true`                  | Hide the app bar, footer, and file navigation; wait for Run before runtime startup            | Standalone layout; Run the preview automatically |
| `panels=<panel-list>`         | Initial panel configuration; `+` expands, `-` collapses in standalone mode or hides in embeds | Inferred from the context; see below             |
| `theme=dark` or `theme=light` | Initial theme                                                                                 | Saved preference, otherwise system theme         |

### Panel configuration

The URL sets each panel's initial state, but these are interpreted as hints and there are exceptions.
In the app, users can then expand or collapse panels.

Use comma-separated panel names, each prefixed with `+` or `-`:

```text
?embed=true&panels=+tabs,-file_tree,-preview
```

`+` expands a panel. `-` collapses it in standalone mode and hides it in embeds,
except that `tabs` stay visible in standalone mode and can only be hidden in
embeds. `bottom_panels` remain accessible as described below.

| Panel           | Group                       | Standalone default | Embed default                                               |
| --------------- | --------------------------- | ------------------ | ----------------------------------------------------------- |
| `bottom_panels` | Console and Problems        | Expanded           | Collapsed                                                   |
| `preview`       | Preview / output            | Expanded           | Expanded                                                    |
| `tabs`          | Editor tabs and breadcrumbs | Expanded           | Hidden, unless multiple distinct `file` values are supplied |
| `file_tree`     | File tree                   | Expanded           | Hidden                                                      |
| `status_bar`    | Status footer               | Expanded           | Hidden                                                      |
| `app_bar`       | App header                  | Expanded           | Hidden                                                      |

In embeds, `-bottom_panels` collapses instead of hiding so Console and Problems
remain accessible.

### Examples

```html
<iframe
  src="https://preview.dartpad.dev/?sample=counter&amp;embed=true&amp;theme=light"
  title="Flutter counter example"
  width="100%"
  height="600"
  style="border: 0"
></iframe>
```

## Develop locally

Requirements:

- Dart 3.12 or later.
- Jaspr CLI (installed by `dart pub get`, invoked via `dart run`).
- Chrome for tests.

From the repository root:

```bash
cd pkgs/dartpad_preview
dart pub get
cd dartpad_frontend
dart run tool/setup_sdk_assets.dart
cd ../examples
dart run build_examples.dart
cd ../dartpad_frontend
dart run jaspr_cli:jaspr serve -v
```

- Open <http://localhost:8080/>.
- SDK assets and example archives only need regenerating when missing or changed.
- See [Development details](dartpad_frontend/doc/development.md) for asset updates and CodeMirror builds.

Frontend checks and builds, from `dartpad_frontend`:

| Task             | Command                                                         |
| ---------------- | --------------------------------------------------------------- |
| Check formatting | `dart format --output=none --set-exit-if-changed lib test tool` |
| Analyze          | `dart analyze --fatal-infos`                                    |
| Test in Chrome   | `dart test`                                                     |
| Build            | `dart run jaspr_cli:jaspr build`                                |

## Further reading

| Document                                                   | Audience                                                       |
| ---------------------------------------------------------- | -------------------------------------------------------------- |
| [Development details](dartpad_frontend/doc/development.md) | Contributors updating generated assets                         |
| [Startup design](dartpad_frontend/doc/startup-design.md)   | Contributors working on project loading and execution          |
| [Frontend UI](dartpad_frontend/README.md)                  | Contributors working on the Jaspr UI                           |
| [Editor package](dartpad_editor/README.md)                 | Contributors working on editor and language-server integration |
| [Examples](examples/README.md)                             | Contributors adding bundled samples                            |
