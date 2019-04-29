import 'package:test/test.dart';
import 'package:dart_pad/experimental/filter_output.dart';

void main() {
  group('filterCloudUrls', () {
    test('cleans dart SDK urls', () {
      var trace =
          '(https://storage.googleapis.com/compilation_artifacts/2.2.0/dart_sdk.js:4537:11)';
      expect(filterCloudUrls(trace), '([Dart SDK Source]:4537:11)');
    });
    test('cleans dart SDK urls', () {
      var trace =
          '(https://storage.googleapis.com/compilation_artifacts/2.2.0/flutter_web.js:96550:21)';
      expect(filterCloudUrls(trace), '([Flutter SDK Source]:96550:21)');
    });
  });
}
