# Startup design

Contributor notes on project resolution and session lifecycle.

## Main components

| Component                                                                 | Responsibility                                            |
| ------------------------------------------------------------------------- | --------------------------------------------------------- |
| [ProjectRequest](../lib/features/startup/project_request.dart)            | Parse and validate source-relative URL options            |
| [ProjectSource](../lib/features/startup/project_source.dart)              | Load source files                                         |
| [InitialProjectState](../lib/features/startup/initial_project_state.dart) | Resolve immutable startup metadata before worker creation |
| [WorkspaceSession](../lib/features/workspace/workspace_session.dart)      | Coordinate files, tabs, worker, and execution             |
| [App](../lib/app.dart)                                                    | Replace sessions and discard superseded load results      |

## Resolution

1. Map and validate explicit file and entrypoint paths. Gist loaders map
   root-level Dart files to `lib/`; missing explicit files are errors.
2. Select the explicit root, or the deepest common ancestor of the explicit
   files and entrypoint containing `pubspec.yaml`. Fall back to the source root.
3. Select a sample's preferred initial file when no `file`, `root`, or
   `entrypoint` was supplied. Otherwise use explicit tabs, the root README,
   or the resolved entrypoint.
4. Infer the SDK from the root pubspec unless `sdk` overrides it. Flutter is
   detected through `environment.flutter`, a top-level `flutter` value, or
   dependencies using `sdk: flutter`.
5. Use the explicit entrypoint, or detect a top-level `main` in initial files,
   then `lib/main.dart` and `main.dart` under the root. Detection uses the Dart
   parser; comments, strings, getters, and class methods do not count.
6. Infer execution mode unless `mode` overrides it. A Flutter SDK uses Flutter
   mode except for entrypoints under `bin/`, `test/`, or `tool/`, relative to
   their nearest pubspec. Other cases use console mode.

- Gists and generated documentation samples without a root pubspec infer
  dependencies from imports and exports. The generated SDK constraint uses the
  selected bundle's Dart version as `^major.minor.patch-0`. Existing pubspecs stay intact.
- SDK versions must match [sdks.g.dart](../lib/sdks.g.dart); Dart build suffixes
  are excluded from matching. No extra versions are downloaded at runtime.
- Without an explicit version, resolution uses the first bundle of the selected kind.

## Preparation and execution

- Load and resolve the project, copy files into a local workspace, and open tabs.
  Standalone sessions then create a worker and synchronize files; embeds wait for Run.
- Run initial `pub get` at the resolved root if it has a pubspec; synchronize
  pending workspace writes before Pub commands.
- After successful preparation, start the entrypoint outside embed mode, then
  initialize the language server at the same root. Embeds wait for Run.
- Archives isolate packages with `resolution: workspace` through package-local
  `pubspec_overrides.yaml` files with null `resolution`; existing overrides are replaced.
- Run and its shortcut retain the resolved entrypoint across tab changes.
  Restart recompiles the current run's entrypoint; hot reload applies to running Flutter apps.

## Session replacement

- Each load creates a fresh workspace and uses a fresh worker when its runtime
  starts, including restores and reopening the same project. Worker-local changes
  cannot leak into another session.
- Switching SDKs preserves current files, tabs, root, and entrypoint while
  creating a new worker. A Flutter SDK can run a console entrypoint.
- Initial metadata stays immutable as the session changes.
- Dispose the previous session after its editor unmounts. Superseded loads
  cannot reactivate an old session.
- Failed resets remove the previous session and display a load error.

## Embedded runtime lifecycle

Embedded projects (`embed=true`) load their files into the editor without starting
the SDK worker, language server or preview. Run initializes the runtime.
Standalone projects run their resolved entrypoint automatically after successful
preparation. The obsolete `run` query parameter is ignored in all modes.

`WorkspaceSession.suspendRuntime(paused: true)` detaches LSP, removes the preview
iframe and terminates the SDK worker while retaining CodeMirror tabs, unsaved
edits, cursor position, undo history and the local filesystem. Paused previews
show **LSP and Preview paused** and a **Resume** button using the same action as
Run. Editing remains available while paused.

The next Run/Resume saves retained editor buffers, creates a fresh worker,
synchronizes the local files, runs pub get when needed and reattaches LSP before
starting the preview. Pending work from a suspended runtime cannot reactivate
it or overwrite the resumed runtime. Resuming does not wait for old cleanup.

Only active runtimes refresh on interaction, including interaction inside the preview
iframe; editing a paused example does not implicitly resume it.

`maxConcurrentEmbedRuntimes` sets the limit, currently two. The most recently
used runtimes may remain active; older instances pause through the session API.
Activation does not wait for cleanup, so runtimes may briefly overlap during
a handover. Standalone DartPad does not participate.

Each instance removes its own entry on retirement, pagehide and disposal. Entries
older than six hours and malformed entries in this namespace are purged when
the registry is read.
