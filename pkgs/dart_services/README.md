# Dart Services

A server backend to support DartPad.

[![Build Status](https://github.com/dart-lang/dart-services/workflows/dart-services/badge.svg)](https://github.com/dart-lang/dart-services/actions?workflow=dart-services)

## What is it? What does it do?

This project is a small, stateless Dart server, which powers the front-end of DartPad.
It provides many of DartPad's features, including static analysis (errors and warnings),
compilation to JavaScript, code completion, dartdoc information, code formatting, and
quick fixes for issues.

## Getting set up

This project is built with [grinder](https://pub.dev/packages/grinder). To install, please run:

```bash
$ dart pub global activate grinder
```

The dart-services v2 API is defined in terms of Protobuf, which requires the
installation of the Protobuf `protoc` compiler. Please see [Protocol
Buffers](https://developers.google.com/protocol-buffers/) for detailed
installation instructions. On macOS, you may also install with Homebrew via:

```bash
$ brew install protobuf
```

The Dart protoc plugin is also required for the above `protoc` compiler
to generate Dart code. To install, please run:

```bash
$ dart pub global activate protoc_plugin
```

## Initialize Flutter

The Flutter SDK needs to be downloaded and setup.

```bash
$ dart pub get
$ dart run tool/update_sdk.dart stable
```

## Build the subsidiary files

The Dart Services server depends on generated files. Run the following to generate all the required binaries.

```bash
$ dart tool/grind.dart deploy
```

## Running

To run the server, run:

```bash
$ dart tool/grind.dart serve
```

The server will run from port 8080 and export several JSON APIs, like
`/api/v3/compile` and `/api/v3/analyze`.

## Testing

To run tests:

`dart tool/grind.dart test`

or:

`grind deploy` for all tests and checks.

## Issues and bugs

Please file reports on the
[GitHub Issue Tracker for DartPad](https://github.com/dart-lang/dart-pad/issues).

## License and Contributing

Contributions welcome! Please read this short
[guide](https://github.com/dart-lang/dart-services/wiki/Contributing) first.
You can view our license
[here](https://github.com/dart-lang/dart-services/blob/master/LICENSE).
