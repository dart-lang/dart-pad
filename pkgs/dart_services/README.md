# Dart Services

A server backend to support DartPad.

[![Build Status](https://github.com/dart-lang/dart-services/workflows/dart-services/badge.svg)](https://github.com/dart-lang/dart-services/actions?workflow=dart-services)

## What is it? What does it do?

This project is a small, stateless Dart server, which powers the front-end of
DartPad. It provides many of DartPad's features, including static analysis
(errors and warnings), compilation to JavaScript, code completion, dartdoc
information, code formatting, and quick fixes for issues.

## Getting set up

### Initialize Flutter

The Flutter SDK needs to be downloaded and setup; check out
https://flutter.dev/get-started.

### Running

To run the server, run:

```bash
dart bin/server.dart
```

The server will run from port 8080 and export several JSON APIs, like
`/api/v3/analyze` and `/api/v3/compile`.


### Enabling code generation

To test code generation features locally:

1. Get needed API keys:

   * Get a GEMINI_API_KEY key from [Google AI Studio](https://aistudio.google.com)
   * See how to get a GENUI_API_KEY in the internal go/dartpad-manual.

2. Set the needed environment variables before running:

   ```
   export GEMINI_API_KEY=<YOUR_GEMINI_API_KEY>
   export GENUI_API_KEY=<YOUR_GENUI_API_KEY>
   dart bin/server.dart
   ```

### Testing

To run tests:

`dart test`

### Building storage artifacts

Dart services pre-compiles `.dill` files for the Dart SDK and Flutter Web SDK, which
are uploaded to Cloud Storage automatically. These files are located in the
`artifacts/` directory.

If you need to re-generate these files, run the following command.

```
grind build-storage-artifacts
```

Or, if you don't have `grind` on your PATH:

```
dart tool/grind.dart build-storage-artifacts
```

### Modifying supported packages

Package dependencies are pinned using the `pub_dependencies_<CHANNEL>.yaml`
files. To make changes to the list of supported packages, you need to verify
that the dependencies resolve and update the pinned versions specified in the
`tool/dependencies` directory.

1. Edit the `lib/src/project_templates.dart` file to include changes to the
   whitelisted list of packages.
2. Create the Dart and Flutter projects in the `project_templates/` directory:

    ```bash
    grind build-project-templates
    ```

    Or, if you don't have `grind` on your PATH:

   ```
   dart tool/grind.dart build-project-templates
   ```

4. Run `pub upgrade` in the Dart or Flutter project in `project_templates/`
5. Run `grind update-pub-dependencies` to overwrite the
   `tool/dependencies/pub_dependencies_<CHANNEL>.yaml` file for your current
   channel. Or, if you don't have `grind` on your PATH, `dart tool/grind.dart update-pub-dependencies`
6. Repeat the above steps for the latest version of each Flutter channel
   (`main`, `beta` and `stable`)

## Redis

You can install and run a local redis cache. Run `sudo apt-get install redis-server` to install on Ubuntu or `brew install redis` for macOS.

See the [Redis' Quick Start guide](https://redis.io/topics/quickstart) for other platforms.

To configure the server to use the local redis cache, run `dart bin/server.dart` with the `redis-url` flag.

## Issues and bugs

Please report issues at https://github.com/dart-lang/dart-pad/issues.

## License and Contributing

Contributions welcome! Please read this short
[guide](https://github.com/dart-lang/dart-pad/blob/main/CONTRIBUTING.md) first.
You can view our license
[here](https://github.com/dart-lang/dart-pad/blob/main/LICENSE).

## Invoke local backend from local UI

See [dart_services/README](../dartpad_ui/README.md)
