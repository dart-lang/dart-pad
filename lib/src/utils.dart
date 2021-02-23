import 'package:path/path.dart' as path;

String stripFilePaths(String s) {
  return s.replaceAllMapped(RegExp(r'(?:package:?)?[a-z]*\/\S*'), (match) {
    final urlString = match.group(0);
    final pathComponents = path.split(urlString);
    final isDartPath = pathComponents.contains('lib');
    final isFlutterPath = isDartPath && pathComponents.contains('flutter');
    final isPackagePath = urlString.contains('package:');
    final basename = path.basename(urlString);

    if (isFlutterPath) {
      return path.join('package:flutter', basename);
    }

    if (isDartPath) {
      return path.join('dart:core', basename);
    }

    if (isPackagePath) {
      return urlString;
    }
    return basename;
  });
}
