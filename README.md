# Dart Services

A server backend to support DartPad.

[![Build Status](https://travis-ci.org/dart-lang/dart-services.svg?branch=master)](https://travis-ci.org/dart-lang/dart-services)
[![Coverage Status](https://coveralls.io/repos/dart-lang/dart-services/badge.svg?branch=master)](https://coveralls.io/r/dart-lang/dart-services?branch=master)
[![Uptime Status](https://img.shields.io/badge/uptime-Pingdom-blue.svg)](http://stats.pingdom.com/8n3tfpl1u0j9)

## What is it? What does it do?

This project is a small, stateless Dart server, which powers the front-end of DartPad.
It provides many of DartPad's features, including static analysis (errors and warnings),
compilation to JavaScript, code completion, dartdoc information, code formatting, and
quick fixes for issues.

## Running

To run the server, run:

    dart bin/server_dev.dart --port 8082

The server will run from port 8082 and export several JSON APIs, like
`/api/compile` and `/api/analyze`.

## Testing

To run tests:

`grind test` for unit tests

or:

`grind deploy` for all tests and checks.

dart-services requires the `redis` package, including the `redis-server` binary,
to be installed to run tests.  sudo apt-get install redis-server will install
this on Ubuntu, but see https://redis.io/topics/quickstart for other platforms.

## Deploying

To deploy the server to Dart on AppEngine, follow the instructions [here](https://www.dartlang.org/server/google-cloud-platform/app-engine/).

Modify `warmup.dart` to point the BASE_URI to your AppEngine project.

Then run

    ./tools/deploy.sh

The will deploy the server, and run the warmup sequence and sanity checks.

## Related projects

See also the [dart-pad](https://github.com/dart-lang/dart-pad) repo.

## Issues and bugs

Please file reports on the
[GitHub Issue Tracker for DartPad](https://github.com/dart-lang/dart-pad/issues).

## License and Contributing

Contributions welcome! Please read this short
[guide](https://github.com/dart-lang/dart-services/wiki/Contributing) first.
You can view our license
[here](https://github.com/dart-lang/dart-services/blob/master/LICENSE).
