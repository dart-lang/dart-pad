# DartPad Preview – Example Projects

This package declares example projects that ship with the DartPad preview.

## Layout

- `lib/examples.json` – registry of examples, split into `snippets`
  and `samples` lists.
- `lib/projects/<id>/` – each example is a self-contained Dart / Flutter
  project with at least `lib/main.dart` and `pubspec.yaml`.
- `tool/build_examples.dart` – reads `examples.json`, packages each project
  into a `.tar.gz` archive, copies them to
  `../dartpad_frontend/web/examples/`, and generates
  `../dartpad_frontend/lib/features/startup/examples.g.dart`.

## Usage

```bash
dart run tool/build_examples.dart
```

Run this before `jaspr serve` / `jaspr build`.
