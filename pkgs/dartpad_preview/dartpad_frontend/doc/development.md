# Development details

For initial setup, serving, testing, and building, see the
[workspace README](../../README.md#develop-locally). The preview packages use the independent
[Dart workspace](../../pubspec.yaml) in `pkgs/dartpad_preview/`; resolve Dart
dependencies there.

## SDK runtime assets

Run from `dartpad_frontend` when runtime assets are missing or to refresh SDKs:

```bash
dart run tool/setup_sdk_assets.dart
```

| Output                   | Purpose                                              |
| ------------------------ | ---------------------------------------------------- |
| `web/dartpad/` (ignored) | Worker, sandbox, compiler, and SDK assets            |
| `lib/sdks.g.dart`        | Available SDK versions and the default SDK selection |

- [setup_sdk_assets.dart](../tool/setup_sdk_assets.dart) downloads the latest Dart
  beta runtime and builds the Flutter beta bundle (`--channel=beta --web-sdk=copy`)
  with its matching Dart SDK.
- Dart and Flutter beta are resolved on each run. When refreshing assets, include the
  regenerated SDK manifest in the change.
- SDK versions come from each bundle's `version.json`. Missing or invalid version
  metadata, including an entirely missing required bundle, fails setup before
  the existing runtime assets are replaced. The current setup requires both Dart
  and Flutter; manifest generation can explicitly request Dart only.

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
