# endpoints

The pre-alpha server backend to support interactive Dart services.

[![Build Status](https://travis-ci.org/dart-lang/endpoints.svg?branch=master)](https://travis-ci.org/dart-lang/endpoints)
[![Coverage Status](https://img.shields.io/coveralls/dart-lang/endpoints.svg)](https://coveralls.io/r/dart-lang/endpoints?branch=master)
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

    dart bin/endpoints.dart --port 8082

The server will run from port 8082 and export several JSON APIs, like
`/api/compile` and `/api/analyze`.

## See also

The [codepad](https://github.com/dart-lang/codepad) repo.

## Issues and bugs

Please file reports on the
[GitHub Issue Tracker](https://github.com/dart-lang/endpoints/issues).

## License and Contributing

Contributions welcome! Please read this short
[guide](https://github.com/dart-lang/endpoints/wiki/Contributing) first.
You can view our license
[here](https://github.com/dart-lang/endpoints/blob/master/LICENSE).
