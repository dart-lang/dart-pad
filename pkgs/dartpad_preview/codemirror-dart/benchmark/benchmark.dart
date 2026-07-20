import 'dart:js_interop';
import 'package:codemirror_lang_dart/codemirror_lang_dart.dart';

@JS('window.runBenchmark')
external void runBenchmark(JSFunction parseCallback);

void main() {
  runBenchmark(parseCodeCallback.toJS);
}
