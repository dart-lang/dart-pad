# Dart Services

A (beta) server backend to support interactive Dart services.

[![Build Status](https://travis-ci.org/dart-lang/dart-services.svg?branch=master)](https://travis-ci.org/dart-lang/dart-services)
[![Coverage Status](https://coveralls.io/repos/dart-lang/dart-services/badge.svg?branch=master)](https://coveralls.io/r/dart-lang/dart-services?branch=master)
[![Uptime Status](https://img.shields.io/badge/uptime-Pingdom-blue.svg)](http://stats.pingdom.com/8n3tfpl1u0j9)

## What is it? What does it do?

This project is a small, stateless Dart server, which exposes a RESTful API.
The API provides services to:

- analyze Dart code for errors and warnings (`/api/dartservices/v1/analyze`)
- compile Dart code (`/api/dartservices/v1/compile`)
- perform code completion for a snippet of Dart code (`/api/dartservices/v1/complete`)
- get dartdoc tooltip information for a snippet of Dart code (`/api/dartservices/v1/document`)
- format Dart code (`/api/dartservices/v1/format`)
- get quick fixes for problems in code (`/api/dartservices/v1/fixes`)

## Project status

Beta - the services APIa are available to play with, but still a work in progress.

## Try it!

A simple DartPad example of how to use the library is here:
https://dartpad.dartlang.org/2a7fd9328e0a567ee79b

## The API

The discovery doc for the server's REST API is available here:
http://dart-services.appspot.com/api/discovery/v1/apis/dartservices/v1/rest.

## Runningd

To run the server, run:

    dart bin/services.dart --port 8082

The server will run from port 8082 and export several JSON APIs, like
`/api/compile` and `/api/analyze`.

## Related projects

See also the [dart-pad](https://github.com/dart-lang/dart-pad) repo.

## Issues and bugs

Please file reports on the
[GitHub Issue Tracker](https://github.com/dart-lang/dart-services/issues).

## License and Contributing

Contributions welcome! Please read this short
[guide](https://github.com/dart-lang/dart-services/wiki/Contributing) first.
You can view our license
[here](https://github.com/dart-lang/dart-services/blob/master/LICENSE).
