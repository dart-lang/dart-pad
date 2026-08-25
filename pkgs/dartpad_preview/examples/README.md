# DartPad Preview – Example Projects

This package declares example projects that ship with the DartPad preview.

## Snippets vs. Samples

Example projects are categorized as either a **Snippet** or a **Sample**:

- **Snippet**: A minimal starter template with basic boilerplate code designed to give users a clean starting point for writing code from scratch. Snippets are accessible from the **Create** menu (e.g., `Dart snippet`, `Flutter snippet`).
- **Sample**: A complete, runnable demonstration or showcase of a specific widget, feature, or application (e.g., the Flutter `Counter` app). Samples are accessible from the **Samples** menu and can be loaded directly via URL query parameters (e.g., `?sample=counter`).

## Layout

- `examples.json` – list of all examples, each tagged with a category
  (`Snippet` or `Sample`).
- `<id>/` – each example is a self-contained Dart / Flutter project with at
  least `lib/main.dart` and `pubspec.yaml`.
- `build_examples.dart` – reads `examples.json`, packages each project into a
  `.tar.gz` archive, copies them to `../dartpad_frontend/web/examples/`, and
  generates `../dartpad_frontend/lib/features/startup/examples.g.dart`.

## Adding a New Example

1. Create a new project directory at the package root (e.g. `my_example/`)
   with at least `lib/main.dart` and `pubspec.yaml`.
2. Add an entry to `examples.json`:
   ```json
   {
     "category": "Sample",
     "name": "My Example",
     "id": "my-example",
     "projectDir": "my_example"
   }
   ```
   - **category**: `"Snippet"` for small code fragments shown in the Create
     menu, or `"Sample"` for complete applications shown in the Samples menu.
   - **id**: a lowercase kebab-case identifier (used in the URL query
     parameter `?sample=my-example`).
   - **projectDir**: the directory name relative to this package root.
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
