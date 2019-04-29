final RegExp _flutterUrlExp =
    RegExp(r'(https:[a-zA-Z0-9_=%&\/\-\?\.]+flutter_web\.js)(:\d+:\d+)');
final RegExp _dartUrlExp =
    RegExp(r'(https:[a-zA-Z0-9_=%&\/\-\?\.]+dart_sdk\.js)(:\d+:\d+)');

String filterCloudUrls(String trace) {
  return trace
      .replaceAllMapped(
          _flutterUrlExp, (m) => '[Flutter SDK Source]${m.group(2)}')
      .replaceAllMapped(_dartUrlExp, (m) => '[Dart SDK Source]${m.group(2)}');
}
