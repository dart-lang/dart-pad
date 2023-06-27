[![samples](https://github.com/dart-lang/dart-pad/actions/workflows/samples.yml/badge.svg)](https://github.com/dart-lang/dart-pad/actions/workflows/samples.yml)

Sample code snippets for DartPad.

## Samples

<!-- samples -->
| Category | Name | ID | Source |
| --- | --- | --- | --- |
| Dart | Hello world | `hello-world` | [lib/hello_world.dart](lib/hello_world.dart) |
| Dart | Fibonacci | `fibonacci` | [lib/fibonacci.dart](lib/fibonacci.dart) |
| Flutter | Counter example | `counter-example` | [lib/main.dart](lib/main.dart) |
<!-- samples -->

## Contributing

When considering contributing a sample to DartPad, please open an issue first
for discussion.

After the sample is discussed and approved:

- add the code for the sample to a new Dart file in `lib/`
- add an entry for the sample to the [lib/samples.json](lib/samples.json) file
- run `dart tool/samples.dart` to re-generate related files
