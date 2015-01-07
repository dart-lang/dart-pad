# dartpad_server

The pre-alpha server backend for a web based interactive Dart service.

## What is it? What does it do?

This project is a small, stateless Dart server, which exposes a RESTful API.
The API provides services to:

- compile Dart code
- analyze Dart code (for errors and warnings)
- perform code completion for a snippet of Dart code
- get dartdoc tooltip information for a snippet of Dart code

It is currently in a pre-alpha state, partially complete and very much under active development.

## Running

To run the server, run:

    dart bin/dartpad_server.dart --port 8082

The server will run from port 8082 and export several JSON APIs, like `/api/compile`
and `/api/analyze`.

## See also

The [dartpad_ui](https://github.com/dart-lang/dartpad_ui) repo.

## Issues and bugs

Please file reports on the
[GitHub Issue Tracker](https://github.com/dart-lang/dartpad_server/issues).

## License and Contributing

Contributions welcome! Please read this short
[guide](https://github.com/dart-lang/dartpad_server/wiki/Contributing) first. You can view
our license [here](https://github.com/dart-lang/dartpad_server/blob/master/LICENSE).
