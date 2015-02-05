# Dart Services

The pre-alpha server backend to support interactive Dart services.

[![Build Status](https://travis-ci.org/dart-lang/dart-services.svg?branch=master)](https://travis-ci.org/dart-lang/dart-services)
[![Coverage Status](https://coveralls.io/repos/dart-lang/dart-services/badge.svg?branch=master)](https://coveralls.io/r/dart-lang/dart-services?branch=master)
[![Uptime Status](https://img.shields.io/badge/uptime-StatusCake-blue.svg)](http://uptime.statuscake.com/?TestID=6FVej0AP1A)

## What is it? What does it do?

This project is a small, stateless Dart server, which exposes a RESTful API.
The API provides services to:

- compile Dart code
- analyze Dart code (for errors and warnings)
- perform code completion for a snippet of Dart code
- get dartdoc tooltip information for a snippet of Dart code

## Project status

It is currently in a pre-alpha state, partially complete, and very much under active development.

## Running

To run the server, run:

    dart bin/services.dart --port 8082

The server will run from port 8082 and export several JSON APIs, like
`/api/compile` and `/api/analyze`.

## See also

The [Dart Pad](https://github.com/dart-lang/dart-pad) repo.

## Issues and bugs

Please file reports on the
[GitHub Issue Tracker](https://github.com/dart-lang/dart-services/issues).

## License and Contributing

Contributions welcome! Please read this short
[guide](https://github.com/dart-lang/dart-services/wiki/Contributing) first.
You can view our license
[here](https://github.com/dart-lang/dart-services/blob/master/LICENSE).
