# DartPad Frontend

This package contains the browser frontend for the client-side DartPad
preview. It combines a multi-file CodeMirror editor, an in-browser Dart
workspace and analyzer, and a sandbox for running Dart and Flutter web code.
The package is part of the private `pkgs/dartpad_preview` workspace and is not
published to pub.dev.

## What the frontend provides

- A file tree and reusable editor tabs for Dart, YAML, Markdown, images, and
  other project files.
- Dart analysis, diagnostics, completion, formatting, code actions, and
  navigation through the language server running in the browser worker.
- Dependency resolution with `pub get`, plus a `Pub get` action when
  `pubspec.yaml` or `pubspec.lock` is active.
- Compilation and execution in an isolated preview sandbox, with start, stop,
  restart, and Flutter-only hot reload controls.
- Built-in Dart, Flutter, and Flame examples, as well as projects loaded from
  pub.dev packages, GitHub Gists, and remote tar archives.
- Responsive desktop and small-screen layouts, light and dark themes, and an
  embed mode.

Save, editor focus loss, and switching editor tabs write dirty tabs to the
in-memory workspace. Dart formatting is attempted before saving; a formatting
failure does not prevent the file from being saved. Workspace changes are
synchronized to the worker and persisted locally as described in
[Persistence](#persistence). Closing a dirty tab asks for confirmation before
discarding its changes. The file tree is restricted to the resolved project `root`.

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

Choose one source. Without a source, DartPad loads the bundled `counter` sample.

| Query                              | Source                                                                                     |
| :--------------------------------- | :----------------------------------------------------------------------------------------- |
| `url=<url>`                        | A tar archive; gzip is detected from its bytes.                                            |
| `package=<name>`                   | The latest version reported by pub.dev.                                                    |
| `package=<name>&version=<version>` | An exact pub.dev package version.                                                          |
| `gist=<id>`                        | A GitHub Gist. `id=<id>` is a deprecated alias.                                            |
| `sample=<id>`                      | A bundled sample: `counter`, `sunflower`, `fibonacci`, `flame-game`, `dart`, or `flutter`. |

The following options apply to every source:

| Query                            | Behavior                                                                                                                                |
| :------------------------------- | :-------------------------------------------------------------------------------------------------------------------------------------- |
| `file=<path>&file=<path>`        | Initial tabs, in order; the first tab is active. Defaults to `<root>/README.md`, then the resolved entrypoint if that README is absent. |
| `root=<path>`                    | Root for the file tree, language server and initial Pub command.                                                                        |
| `sdk=dart` or `sdk=flutter`      | SDK kind, optionally followed by `:<version>`.                                                                                          |
| `entrypoint=<path>`              | The file to execute, independently of the active tab.                                                                                   |
| `mode=console` or `mode=flutter` | Explicit execution mode. Flutter mode requires a Flutter SDK.                                                                           |
| `embed=true`                     | Hides the app bar and footer on desktop and starts with the file tree collapsed.                                                        |

Explicit paths are relative to the loaded source, even when `root` is set.
For Gists, flat Dart files are moved into `lib/`; their original query paths
are mapped to the relocated files. For example, `file=main.dart` opens
`lib/main.dart`. Other Gist files keep their original location.

Defaults are resolved once, in this order:

1. Validate explicitly requested files and the explicit entrypoint. Missing
   explicitly requested files remain errors.
2. Use the explicit root, or find the deepest common ancestor of the explicit
   file paths and entrypoint that contains `pubspec.yaml`. Without one, use
   the source root. Open the requested files, or `<root>/README.md`. If it is absent, open the resolved
   entrypoint instead; if neither exists, start without tabs.
3. Infer Flutter from the root pubspec if `environment.flutter` or the
   top-level `flutter` value is non-null, or any dependency or dev dependency
   uses `sdk: flutter`. For Gists without a root pubspec, infer dependencies from
   Dart imports and exports and use the inferred Flutter dependency when the
   source root is selected. Otherwise select Dart. An explicit `sdk` parameter
   overrides this inference.
4. Find the first initial Dart file declaring a top-level `main`, then try
   `<root>/lib/main.dart`, then `<root>/main.dart`. Without an entrypoint, the project stays editable
   and Run stays disabled for that project session.
5. Use Flutter mode with a Flutter SDK unless the entrypoint is under `bin/`,
   `test/` or `tool/`, relative to its nearest pubspec. Otherwise use console.

The Run button and keyboard shortcut execute the entrypoint resolved at startup.
Changing tabs does not change it.

Multiple sources, conflicting `gist`/`id` values, invalid paths, and unavailable
SDK versions produce a visible error.

Examples:

```text
http://localhost:8080/?sample=counter&file=lib/main.dart
http://localhost:8080/?package=flutter_animate&file=example/lib/main.dart
http://localhost:8080/?package=material_ui&version=0.0.3&root=example&file=example/README.md&entrypoint=example/lib/main.dart
http://localhost:8080/?gist=b6af57de480a26e2bf98daf235491fbc&file=main.dart&entrypoint=main.dart
http://localhost:8080/?url=https://pub.dev/api/archives/material_ui-0.0.3.tar.gz&file=example/README.md&entrypoint=example/lib/main.dart
```

## SDK selection and project state

`InitialProjectState` retains immutable startup metadata: source, original query,
initial tab paths, root, SDK, entrypoint, mode and whether the root had a pubspec.
It is resolved before starting a worker and retained by `WorkspaceSession`.
During resolution, Gists without a root pubspec receive a generated one. Its Dart
SDK constraint uses the selected bundle's `dartVersion` from `lib/sdks.g.dart`,
normalized to `^major.minor.patch-0` to include prereleases. The default language
version therefore follows the bundled SDK as its assets are updated. Existing
pubspecs are preserved.
Editing files, changing tabs or switching
SDKs does not modify the initial metadata. Choosing a sample creates new metadata
and a new workspace.

The generated `lib/sdks.g.dart` lists the available bundles. An explicit
version must match the corresponding Dart or Flutter version in this manifest;
Dart's human-readable build suffix is excluded from matching. No additional SDK
versions are downloaded. Without a version, the first bundle of the selected
kind in the manifest is used.

Switching SDKs from the footer creates a new worker and preserves current
files, tabs, root and entrypoint. SDK kind and execution mode are separate:
a Flutter SDK can run a console entrypoint.

## Dependency resolution

Every source uses the resolved `root` for initial `pub get` and LSP analysis.
If that root has no `pubspec.yaml`, the initial Pub command is skipped.
Pending workspace writes are synchronized before Pub runs. On successful
preparation, the configured entrypoint starts automatically, when present.

For archives, packages declaring `resolution: workspace` are isolated through
package-local `pubspec_overrides.yaml` files containing a null `resolution`.
Their original pubspecs remain unchanged; existing overrides in those packages
are replaced. This applies to all nested packages in the archive.

## Entrypoint detection

All sources use the same deterministic resolution rules described in
[Query options](#query-options). The `file` parameters select the initial editor
tabs; `entrypoint` selects the execution target independently of those tabs.
An explicit `entrypoint` must exist. Without one, the resolver looks for a
top-level `main` in the initial Dart files, in tab order, then in
`<root>/lib/main.dart`, then `<root>/main.dart`. Detection uses the Dart parser, so comments, strings,
getters, and class methods do not count.

For Gists, root-level Dart files move into `lib/`. Both `file` and `entrypoint`
accept their original source paths and use the loader's mapping.

After successful preparation, the resolved entrypoint starts automatically
when present. Run and the keyboard shortcut retain that entrypoint across tab
changes and SDK switches. Without a `mode` override, execution mode is inferred from
the current SDK and the entrypoint's location relative to its nearest pubspec.

Restart recompiles the current run's entrypoint. Hot Reload is available for
running Flutter applications. Console programs return to the Run-ready state
after a successful launch.

## Persistence

IndexedDB retains the ten most recently saved projects. Each project has its
own ID. Autosave updates that entry; opening a fresh project creates another
entry and removes the oldest if needed.

Changes to files in the frontend workspace trigger an IndexedDB save. This
includes saving editor files, creating, moving or deleting files and folders,
and changes received from the worker. Worker synchronization and IndexedDB
persistence run independently.

Snapshots also include binary assets, empty folders, SDK selection, root,
entrypoint, run mode, and open/active tabs. Generated `.dart_tool` and `build`
directories and external SDK/package sources are excluded. Changes to open or
active editor tabs, SDK selection, entrypoint, and run mode also update the
stored project.

Without query parameters, DartPad restores the newest project. With query
parameters, it loads and immediately saves a fresh project. If an older entry
matches all decoded query options, the toolbar offers
**Restore last project** for 30 seconds. The button's bottom border shows
the remaining time. Clicking restores the matching entry's latest stored
contents. The project being left, including edits saved before clicking,
remains in the history (subject to the ten-entry limit).

Project switches wait for the normal editor Save to finish before flushing
pending IndexedDB writes. Stopping an unchanged session does not save it again.

Multiple browser tabs can edit the same project without ownership checks,
warnings, or pausing persistence. The last completed IndexedDB write wins,
replacing the full stored snapshot atomically; snapshots are not merged.
Other browser tabs keep their current editor contents until they restore or
reload, and can overwrite the stored snapshot with their next write.
If an open project's entry was evicted from the ten-project history, its next
save adds it back under the same ID, removing the oldest entry if needed.

Restore failures show **Restoring your project failed.** and **Start fresh**.
Starting fresh retains the failed entry in history. If the URL source fails to
load but a matching saved entry exists, the restore button still offers recovery.
Storage failures are reported without discarding editor contents.

Persistence is disabled in embed mode (`embed=true`): no history reads, writes,
or restore offers occur.

## Startup and workspace lifecycle

The loading UI appears immediately. The frontend loads the source and resolves
`InitialProjectState`, including the SDK, before creating the worker. It then
copies the loaded files into a local workspace, opens the initial tabs, and
waits for worker initialization and synchronization. Preparation continues with:

1. Initial `pub get` at the resolved `root`, if a pubspec exists there.
2. Automatic execution of the selected entrypoint after successful preparation.
3. Language-server initialization using the same root.

A failed project reset removes the previous session and displays an error
dialog with a reload action, including in embed mode. Old session resources
are disposed after the editor has unmounted, and results from superseded loads
cannot reactivate the previous session.
