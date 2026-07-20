# codemirror-lang-dart

Dart language support for CodeMirror 6 using the Dart analyzer.

## Overview

This package is implemented as both a Dart and NPM package. It relies on

- a `pubspec.yaml` to manage Dart dependencies (such as the `analyzer` package), with package code inside `lib/`
- a `package.json` for managing Node.js dependencies (such as CodeMirror and testing utilities), with package code inside `src/`

This dual-project structure allows it to use the official Dart analyzer for advanced parsing while integrating into the broader CodeMirror ecosystem.

_In the future this may also be published as a standalone npm package, with the Dart code compiled to JS and bundled with the NPM package. This is currently not supported._

## Setup Requirements

To configure the package locally, ensure you install both its Dart and Node.js dependencies:

1. Run `dart pub get` to install the Dart dependencies.
2. Run `npm install` to install the Node.js dependencies.

## Running Tests

To run the test suite, simply use the following command:

```bash
npm test
```

This command will automatically:

1. Compile the Dart testing environment (`test/dart_test_env.dart`) to a Node-compatible JS bundle.
2. Run the Mocha test suite (`test/test-*.ts`) against the bundled environment using `ts-node`.
