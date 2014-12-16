
library dartpad_serve.common;

import 'dart:io';

final String sampleCode = """
void main() {
  print("hello");
}
""";

final String sampleCodeWeb = """
import 'dart:html';

void main() {
  print("hello");
  querySelector('#foo').text = 'bar';
}
""";

class Lines {
  List<int> _starts = [];

  Lines(String source) {
    List<int> units = source.codeUnits;
    for (int i = 0; i < units.length; i++) {
      if (units[i] == 10) _starts.add(i);
    }
  }

  /// Return the 0-based line number.
  int getLineForOffset(int offset) {
    for (int i = 0; i < _starts.length; i++) {
      if (offset <= _starts[i]) return i;
    }
    return _starts.length;
  }
}

// TODO: switch to the one from grinder.

/**
 * Return the path to the current Dart SDK. This will return `null` if we are
 * unable to locate the Dart SDK.
 */
Directory getSdkDir([List<String> cliArgs]) {
  // Look for --dart-sdk on the command line.
  if (cliArgs != null && cliArgs.contains('--dart-sdk')) {
    return new Directory(cliArgs[cliArgs.indexOf('dart-sdk') + 1]);
  }

  // Look in env['DART_SDK']
  if (Platform.environment['DART_SDK'] != null) {
    return new Directory(Platform.environment['DART_SDK']);
  }

  // Look relative to the dart executable.
  Directory sdkDirectory = new File(Platform.executable).parent.parent;
  File versionFile = new File(
      '${sdkDirectory.path}${Platform.pathSeparator}version');
  if (versionFile.existsSync()) return sdkDirectory;

  // TODO: handle things like symlinked paths to the VM
  return null;
}
