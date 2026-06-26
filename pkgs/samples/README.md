[![samples](https://github.com/dart-lang/dart-pad/actions/workflows/samples.yml/badge.svg)](https://github.com/dart-lang/dart-pad/actions/workflows/samples.yml)

Sample code snippets for DartPad.

## Samples

<!-- samples -->
| Category | Name | Sample | ID |
| --- | --- | --- | --- |
| Dart | Fibonacci | [fibonacci.dart](lib/fibonacci.dart) | `fibonacci` |
| Dart | Hello world | [hello_world_dart.dart](lib/hello_world_dart.dart) | `hello-world-dart` |
| Defaults | Dart snippet | [default_dart.dart](lib/default_dart.dart) | `dart` |
| Defaults | Flutter snippet | [default_flutter.dart](lib/default_flutter.dart) | `flutter` |
| Ecosystem | Flame game | [brick_breaker.dart](lib/brick_breaker.dart) | `flame-game` |
| Flutter | Counter | [main.dart](lib/main.dart) | `counter` |
| Flutter | Hello world | [hello_world_flutter.dart](lib/hello_world_flutter.dart) | `hello-world-flutter` |
| Flutter | Sunflower | [sunflower.dart](lib/sunflower.dart) | `sunflower` |
<!-- samples -->

## Contributing

When considering contributing a sample to DartPad, please open an issue first
for discussion.

After the sample is discussed and approved:

- add the code for the sample to a new Dart file in `lib/`
- add an entry for the sample to the [lib/samples.json](lib/samples.json) file
- run `dart tool/samples.dart` to re-generate related files
