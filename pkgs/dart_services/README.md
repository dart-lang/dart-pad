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

2. Set the needed environment variables before running:

   ```
   export GEMINI_API_KEY=<YOUR_GEMINI_API_KEY>
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
dart tool/grind.dart build-storage-artifacts
```

### Modifying supported packages

Package dependencies are pinned using the `tool/dependencies/pub_dependencies_<CHANNEL>.yaml`
files. To make changes to the list of supported packages, you need to verify
that the dependencies resolve and update these pinned versions.

Complete the following steps using each Flutter channel (`main`, `beta` and `stable`):

1. Switch to the desired Flutter channel: 
	
	```
	flutter channel <CHANNEL>
	```

2. (Optional) If you are adding or removing a package, first edit the `lib/src/project_templates.dart` file, which contains the
   whitelisted list of packages.
3. Create the Dart and Flutter projects in the `project_templates/` directory/.

   ```bash
   dart tool/grind.dart build-project-templates
   ```

   If this command fails because it can't resolve packages, read the package failure, and edit the `tool/dependencies/pub_dependencies_<CHANNEL>.yaml` file to use the correct package version.

5. Once the `project_templates/dart_project` and `project_templates/flutter_project` directories are created, run `pub upgrade` in each directory.
6. Run `dart tool/grind.dart update-pub-dependencies` to overwrite the 
`tool/dependencies/pub_dependencies_<CHANNEL>.yaml` file for your current 
channel. This will ensure all packages are pinned to the correct version.

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
