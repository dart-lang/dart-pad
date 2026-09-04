# DartPad Preview – Example Projects

This package declares example projects that ship with the DartPad preview.

## Layout

- `examples.json` – list of all examples.
- `<id>/` – each example is a self-contained Dart / Flutter project with at
  least `lib/main.dart`, `pubspec.yaml`, and `README.md`.
- `build_examples.dart` – reads `examples.json`, packages each project into a
  `.tar.gz` archive, copies them to `../dartpad_frontend/web/examples/`, and
  generates `../dartpad_frontend/lib/features/startup/examples.g.dart`.

## Adding a New Example

1. Create a new project directory at the package root (e.g. `my_example/`)
   with at least `lib/main.dart`, `pubspec.yaml`, and `README.md`.
2. Add an entry to `examples.json`:
   ```json
   {
     "name": "My Example",
     "id": "my-example",
     "projectDir": "my_example",
     "subcategory": "Flutter",
     "icon": "images/flutter_logo_192.png"
   }
   ```
   - **id**: a lowercase kebab-case identifier (used in the URL query
     parameter `?sample=my-example`).
   - **projectDir**: the directory name relative to this package root.
   - **subcategory** *(optional)*: section divider label in the New menu.
   - **icon** *(optional)*: path to the icon image.
   - **entryPath** *(optional)*: defaults to `lib/main.dart`.
3. Run the build script:
   ```bash
   dart run build_examples.dart
   ```
4. The script validates the entry, packages the project, and regenerates
   `examples.g.dart`.

## Usage

```bash
dart run build_examples.dart
```

Run this before `jaspr serve` / `jaspr build`.
