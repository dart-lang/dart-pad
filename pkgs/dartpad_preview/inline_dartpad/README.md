# inline_dartpad

Lightweight DartPads for documentation pages: a script and a stylesheet
upgrade every `<pre data-dartpad-filename>` code block on a page into an editor with
analysis (diagnostics, hover, completion), a run button and a console.

Resource usage is what makes this different from embedding `dartpad.dev` in an
`<iframe>` per sample:

 * **Per origin**: one `SharedWorker` running the DartPad worker, shared by
   every tab on the site (`DartPadSdk.sharedWorker` from `package:dartpad`).
   Browsers without `SharedWorker` get a dedicated worker per page instead,
   and then nothing runs until the user asks for it.
 * **Per page**: one worker _session_ with one workspace and one language
   server for all editors.
 * **Per pad**: a CodeMirror `EditorView`, a `<pre>` for the console and, once
   it has run, a sandboxed `<iframe>` with its own `frontend_server` in the
   worker. Only the three most recently run pads keep their sandbox.

Only the `dart:` libraries are available, there are no `pub.dev` dependencies.
See `../inline_dartpad_shared_sandbox` for the variant with a single sandbox
per page and `../inline_dartpad_flutter` for the Flutter variant.

## Usage

```html
<link rel="stylesheet" href="inline_dartpad.css">
<script src="inline_dartpad.js" defer></script>

<pre data-dartpad-filename="hello.dart" data-dartpad-preview="start"><code>
void main() => print('Hello, world!');
</code></pre>
```

`data-dartpad-filename` is what marks a `<pre>` as a pad, the rest is
optional:

| attribute               | values                        | default    |
| ----------------------- | ----------------------------- | ---------- |
| `data-dartpad-filename` | a file name                   | required   |
| `data-dartpad-preview`  | `start` \| `pause` \| `none`  | `pause`    |
| `data-dartpad-layout`   | `vertical` \| `horizontal`    | `vertical` |
| `data-dartpad-output`   | text                          |            |

`start` runs the program the first time the pad scrolls into view (only with
a `SharedWorker`), `pause` waits for the run button or `Ctrl`+`Enter`, and
`none` is an editor without a run button or console. `horizontal` puts the
console to the right of the editor, wrapping below it when the pad is narrow.
`data-dartpad-output` is shown in the console until the program runs, for
pages that want to show output without running anything. A reset button
appears once the code differs from the original.

Every pad is a file in one workspace, named by `data-dartpad-filename`; when
two pads on a page use the same name, the later ones get `~1`, `~2`, ...
before the extension (`main.dart`, `main~1.dart`).

Attributes on the `<script>` say where things are hosted, resolved relative to
the script itself:

| attribute     | default            | notes                        |
| ------------- | ------------------ | ---------------------------- |
| `data-sdk`    | `dartpad/dart/`    | DartPad SDK assets for Dart  |
| `data-worker` | `shared-worker.js` | must be on the page's origin |

The DartPad SDK assets (`worker.js`, `worker.wasm`, `sdk.tar`, `dart_sdk.js`,
`sandbox.js`, ...) are fetched by the shared worker and the sandbox, so unless
they are served with CORS headers they have to be on the page's origin too.

## Theming

`inline_dartpad.css` has the colors of dart.dev's code blocks. It follows
`prefers-color-scheme`, and a `dartpad-light` or `dartpad-dark` class on any
ancestor (`<html>`, typically) forces one palette. Include it before the
site's own stylesheets so those win.

Everything else is `--inline-dartpad-*` custom properties, all listed at the
top of the stylesheet (fonts, radius, border, editor, console and accent
colors, `--inline-dartpad-cm-*` for syntax highlighting,
`--inline-dartpad-line-numbers: none | flex` for the line-number gutter, off
by default like dart.dev's code blocks) that a site sets on any ancestor, and
the DOM is plain enough to restyle:

```
.inline-dartpad[data-layout][data-preview][data-state=idle|running][data-modified]
  .inline-dartpad-editor   > .cm-editor
  .inline-dartpad-output   > .inline-dartpad-status + .inline-dartpad-console
  .inline-dartpad-controls > .inline-dartpad-filename + .inline-dartpad-reset + .inline-dartpad-run
```

`web/themes.css` has eight looks built this way, selectable in the demo page.

## Building

```sh
dart run tool/build.dart --sdk-assets=<dir with the Dart DartPad SDK assets>
```

writes a self-contained `build/` folder (`inline_dartpad.js`, the prebuilt
CodeMirror bundle from `codemirror_dart` followed by the compiled Dart; the
stylesheets; `shared-worker.js` from `dart run dartpad setup shared-worker`;
SDK assets and the demo `index.html`) that any static file server can host,
for example:

```sh
cd build && python3 -m http.server 8765
```

The SDK assets are the ones `dartpad setup dart` produces; the preview frontend
downloads them with `../dartpad_frontend/tool/setup_sdk_assets.dart`.

## Life cycle

Editors are the only state a page keeps. The session closes itself when the
page is hidden (`pagehide`), the worker drops sessions that stop pinging, and
if the worker goes away the page drops its session; the next run, or the tab
becoming visible again, connects anew with the code currently in the editors.
The browser terminates the `SharedWorker` itself once the last page on the
origin is gone.
