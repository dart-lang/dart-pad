# inline_dartpad_shared_sandbox

The `../inline_dartpad` script with one sandbox per page instead of one per
pad. Same `<pre data-dartpad-filename>` attributes, `<script>` attributes, theming
and build; see the README there.

## What differs

 * **Per page**: one hidden sandboxed `<iframe>` with one `frontend_server`
   instance, next to the session, workspace and language server.
 * **Per pad**: only a CodeMirror `EditorView` and a `<pre>` for the console.

Programs run one at a time. Running a pad writes its code to the workspace,
rewrites a generated entrypoint (`main.dart`, or `main~1.dart` and so on if a
pad has that name) to import and run it in a zone that tags everything it
prints, and any uncaught error, with the position of the pad on the page, and
hot restarts the sandbox. Output is routed back to the pad's console by that tag; untagged
output goes to the pad that ran last.

This is cheaper when a page has many pads that all get run (one DDC runtime
and one compiler instead of one per pad), at the cost of the generated
entrypoint and of pads not running concurrently: an async program keeps
printing until the next run replaces it.

## Building

```sh
dart run tool/build.dart --sdk-assets=<dir with the Dart DartPad SDK assets>
cd build && python3 -m http.server 8768
```
