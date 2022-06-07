// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Parses a snippet into multiple file types separated by
/// `{% begin <filename> %}` and `{% end <filename> %}` markers
class InjectParser {
  final String input;
  final RegExp _beginExp = RegExp(r'{\$ begin ([a-z.]*) \$}');
  final RegExp _endExp = RegExp(r'{\$ end ([a-z.]*) \$}');
  int? _currentLine;
  String? _currentFile;
  final Map<String, String> _tokens = {};
  InjectParser(this.input);

  /// Returns filenames and contents that were parsed from the input
  Map<String, String> read() {
    final lines = input.split('\n');
    for (var i = 0; i < lines.length; i++) {
      _currentLine = i;
      _readLine(lines[i]);
    }

    if (_tokens.isEmpty) {
      return {'main.dart': input.trim()};
    }

    return _tokens;
  }

  void _readLine(String line) {
    if (_beginExp.hasMatch(line)) {
      if (_currentFile == null) {
        _currentFile = _beginExp.firstMatch(line)![1];
      } else {
        _error('$_currentLine: unexpected begin');
      }
    } else if (_endExp.hasMatch(line)) {
      if (_currentFile == null) {
        _error('$_currentLine: unexpected end');
      } else {
        final match = _endExp.firstMatch(line)![1];
        if (match != _currentFile) {
          _error('$_currentLine: end statement did not match begin statement');
        } else {
          // add newline
          _addLine('', _currentFile);
          _currentFile = null;
        }
      }
    } else if (_currentFile != null) {
      _addLine(line, _currentFile);
    }
  }

  void _addLine(String line, String? file) {
    if (file != null) {
      final token = _tokens[file];
      if (token == null) {
        _tokens[file] = line;
      } else {
        _tokens[file] = '$token\n$line';
      }
    }
  }

  void _error(String message) {
    final errorMessage =
        'error parsing DartPad scripts on line $_currentLine: $message';
    throw DartPadInjectException(errorMessage);
  }
}

class DartPadInjectException implements Exception {
  final String message;
  DartPadInjectException(this.message);
  @override
  // ignore: unnecessary_string_interpolations
  String toString() => '$message';
}

/// Parses the dartpad CSS class names to extract
class LanguageStringParser {
  final String input;
  final RegExp _validExp = RegExp(r'[a-z-]*run-dartpad(:?[a-z-]*)+');
  final RegExp _optionsExp = RegExp(r':([a-z_]*)-([a-z0-9%_]*)');

  LanguageStringParser(this.input);

  bool get isValid {
    return _validExp.hasMatch(input);
  }

  Map<String, String> get options {
    final opts = <String, String>{};
    if (!isValid) {
      return opts;
    }

    final matches = _optionsExp.allMatches(input);
    for (final match in matches) {
      if (match.groupCount != 2) {
        continue;
      }
      opts[match[1]!] = match[2]!;
    }

    return opts;
  }
}
