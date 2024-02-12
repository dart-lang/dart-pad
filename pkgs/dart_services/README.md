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

The Flutter SDK needs to be downloaded and setup; see
https://docs.flutter.dev/get-started/install.

### Running

To run the server, run:

```bash
$ dart bin/server.dart
```

The server will run from port 8080 and export several JSON APIs, like
`/api/v3/analyze` and `/api/v3/compile`.

### Testing

To run tests:

`dart test`

### Re-generating source

To rebuild the shelf router, run:

```
dart run build_runner build --delete-conflicting-outputs
```

And to update the shared code from dartpad_shared, run:

```
dart tool/grind.dart copy-shared-source
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

3. Run `pub upgrade` in the Dart or Flutter project in `project_templates/`
4. Run `grind update-pub-dependencies` to overwrite the
   `tool/dependencies/pub_dependencies_<CHANNEL>.yaml` file for your current
   channel.
5. Repeat the above steps for the latest version of each Flutter channel
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
