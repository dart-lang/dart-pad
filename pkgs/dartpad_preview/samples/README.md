# DartPad Preview – Sample Projects

This package declares sample projects that ship with the DartPad preview.

## Layout

- `lib/samples.json` – registry of samples, split into `create` (snippets)
  and `examples` lists.
- `lib/projects/<id>/` – each sample is a self-contained Dart / Flutter
  project with at least `lib/main.dart` and `pubspec.yaml`.
- `tool/build_samples.dart` – reads `samples.json`, packages each project
  into a `.tar.gz` archive, copies them to
  `../dartpad_frontend/web/samples/`, and generates
  `../dartpad_frontend/lib/features/startup/samples.g.dart`.

## Usage

```bash
dart run tool/build_samples.dart
```

Run this before `jaspr serve` / `jaspr build`.
