# Development details

For initial setup, serving, testing, and building, see the
[workspace README](../../README.md#develop-locally). The preview packages use the independent
[Dart workspace](../../pubspec.yaml) in `pkgs/dartpad_preview/`; resolve Dart
dependencies there.

## SDK runtime assets

Run from `dartpad_frontend` when runtime assets are missing or SDK revisions change:

```bash
dart run tool/setup_sdk_assets.dart
```

| Output                   | Purpose                                              |
| ------------------------ | ---------------------------------------------------- |
| `web/dartpad/` (ignored) | Worker, sandbox, compiler, and SDK assets            |
| `lib/sdks.g.dart`        | Available SDK versions and the default SDK selection |

- Revisions are pinned in [setup_sdk_assets.dart](../tool/setup_sdk_assets.dart).
- The script downloads the pinned Dart runtime and builds the Flutter runtime
  from a temporary pinned Flutter checkout using its matching Dart SDK.
- When updating the pins, include the regenerated SDK manifest in the change.

## Bundled examples

Run from `pkgs/dartpad_preview/examples`:

```bash
dart run build_examples.dart
```

This generates `web/examples/*.tar.gz` and `lib/features/startup/examples.g.dart`
in `dartpad_frontend`.
See the [examples README](../../examples/README.md) for adding or changing a sample.

## CodeMirror bundles

Rebuild after changing the TypeScript editor or grammar sources. Node.js and npm
are required. From `pkgs/dartpad_preview`:

```bash
cd codemirror-lang-dart
npm ci
npm run build
cd ../codemirror-dart
npm ci
npm run build
```

See [codemirror-dart](../../codemirror-dart/README.md) and
[codemirror-lang-dart](../../codemirror-lang-dart/README.md) for package-specific
checks and generated outputs.
