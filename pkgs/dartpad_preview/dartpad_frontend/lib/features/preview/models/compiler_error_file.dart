// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

final _errorLocation = RegExp(r'^(.+\.dart):\d+:\d+:\s*(.*)$');
final _generatedWrapper = RegExp(r'\.dart\.[\w-]+-wrapper\.dart$');
final _controlCharacters = RegExp(r'[\x00-\x1f\x7f]');

/// Returns the filename from the first recognizable compiler error, or null
/// when the output doesn't identify a user-facing Dart file.
String? compilerErrorFile(String output) {
  final lines = output.split('\n');
  for (var i = 0; i < lines.length; i++) {
    final match = _errorLocation.firstMatch(lines[i].trim());
    if (match == null) {
      continue;
    }
    final diagnostic = match.group(2)!.trimLeft();
    final nextLine = i + 1 < lines.length ? lines[i + 1].trimLeft() : '';
    if (!diagnostic.startsWith('Error:') && !(diagnostic.isEmpty && nextLine.startsWith('Error:'))) {
      continue;
    }
    try {
      final uri = Uri.tryParse(match.group(1)!.replaceAll('\\', '/'));
      if (uri == null || uri.pathSegments.isEmpty) {
        continue;
      }
      final filename = uri.pathSegments.last;
      if (filename.isNotEmpty && !_generatedWrapper.hasMatch(filename) && !_controlCharacters.hasMatch(filename)) {
        return filename;
      }
    } on FormatException {
      // Malformed paths are not suitable for display.
    }
  }
  return null;
}
