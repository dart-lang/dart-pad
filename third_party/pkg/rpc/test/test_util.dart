library rpc.test.test_util;

import 'dart:mirrors';

import 'package:path/path.dart' as p;

String getPackageDir() {
  // Locate the "test" directory. Use mirrors so that this works with the test
  // package, which loads this suite into an isolate.
  var testDir = p.dirname(
      currentMirrorSystem().findLibrary(#rpc.test.test_util).uri.toFilePath());

  return p.dirname(testDir);
}
