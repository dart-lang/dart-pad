# codemirror-dart

A Dart wrapper around the CodeMirror 6 text editor.

> CodeMirror is a code editor component for the web. It can be used in websites to implement a text input field with support for many editing features, and has a rich programming interface to allow further extension. - [codemirror.net](https://codemirror.net)

## Overview

This package acts as both a Dart and NPM package. It utilizes:
- a `pubspec.yaml` for managing Dart dependencies, with package code inside `lib/`
- a `package.json` for managing JavaScript dependencies, with package code inside `src/`

This dual-package architecture allows it to integrate Dart's logic within the JS-based CodeMirror environment.

## Setup Requirements

To set up this package locally, you must install both its Dart and Node.js dependencies:

1. Run `dart pub get` to install Dart dependencies.
2. Run `npm install` to install Node.js dependencies.

## Building

To (re-)build the JS bundle (which is required by the `frontend` package), ensure that the `codemirror-lang-dart` package has been built first (by running `npm run build` in that directory), then run `npm run build` in this directory.

> **Note:** For convenience, the resulting compiled JS bundle has been checked into the repository at `lib/assets/codemirror-dart.bundle.js`.

## Benchmarks

To run the benchmarking suite, you can execute the following command:

```bash
npm run benchmark
```

This command will automatically:
1. Build the JS bundle using `rollup`.
2. Compile the Dart benchmark script to JS (`benchmark.dart` -> `benchmark.dart.js`).
3. Open `benchmark.html` in your default browser to view the benchmark results.
