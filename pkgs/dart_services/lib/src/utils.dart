// Copyright (c) 2021, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:path/path.dart' as path;

/// Normalizes any "paths" from [text], replacing the segments before the last
/// separator with either "dart:core" or "package:flutter", or removes them,
/// according to their content.
///
/// ## Examples:
///
/// "Unused import: '/path/foo.dart'" -> "Unused import: 'foo.dart'"
///
/// "Unused import: '/path/to/dart/lib/core/world.dart'" ->
/// "Unused import: 'dart:core/world.dart'"
///
/// "Unused import: 'package:flutter/material.dart'" ->
/// "Unused import: 'package:flutter/material.dart'"
String normalizeFilePaths(String text) {
  return text.replaceAllMapped(_possiblePathPattern, (match) {
    final possiblePath = match.group(0)!;

    final uri = Uri.tryParse(possiblePath);
    if (uri != null && uri.hasScheme) {
      return possiblePath;
    }

    final pathComponents = path.split(possiblePath);
    final basename = path.basename(possiblePath);

    if (pathComponents.contains('flutter')) {
      return path.join('package:flutter', basename);
    }

    if (pathComponents.contains('lib') && pathComponents.contains('core')) {
      return path.join('dart:core', basename);
    }

    return basename;
  });
}

Future<Process> runWithLogging(
  String executable, {
  List<String> arguments = const [],
  String? workingDirectory,
  Map<String, String> environment = const {},
  required void Function(String) log,
}) async {
  log([
    '${path.basename(executable)} ${arguments.join(' ')}:',
    if (workingDirectory != null) 'cwd: $workingDirectory',
    if (environment.isNotEmpty) 'env: $environment',
  ].join('\n  '));

  final process = await Process.start(executable, arguments,
      workingDirectory: workingDirectory,
      environment: environment,
      includeParentEnvironment: true,
      runInShell: Platform.isWindows);
  process.stdout.listen((out) => log(systemEncoding.decode(out).trimRight()));
  process.stderr.listen((out) => log(systemEncoding.decode(out).trimRight()));
  return process;
}

class TaskScheduler {
  final Queue<_SchedulerTask<Object?>> _taskQueue = Queue();
  bool _isActive = false;

  int get queueCount => _taskQueue.length;

  Future<T> _performTask<T>(SchedulerTask<T> task) {
    return task.perform().timeout(task.timeoutDuration);
  }

  Future<T> schedule<T>(SchedulerTask<T> task) {
    if (!_isActive) {
      _isActive = true;
      return _performTask(task).whenComplete(_next);
    }

    final taskResult = Completer<T>();
    _taskQueue.add(_SchedulerTask<T>(task, taskResult));
    return taskResult.future;
  }

  void _next() {
    assert(_isActive);
    if (_taskQueue.isEmpty) {
      _isActive = false;
      return;
    }

    final first = _taskQueue.removeFirst();
    first.taskResult.complete(_performTask(first.task).whenComplete(_next));
  }
}

// Internal unit of scheduling.
class _SchedulerTask<T> {
  final SchedulerTask<T> task;
  final Completer<T> taskResult;

  _SchedulerTask(this.task, this.taskResult);
}

// Public working data structure.
abstract class SchedulerTask<T> {
  final Duration timeoutDuration;

  SchedulerTask({required this.timeoutDuration});

  Future<T> perform();
}

class ClosureTask<T> extends SchedulerTask<T> {
  final Future<T> Function() _closure;

  ClosureTask(this._closure, {required super.timeoutDuration});

  @override
  Future<T> perform() {
    return _closure();
  }
}

/// A pattern which matches a possible path.
///
/// This pattern is essentially "possibly some letters and colons, followed by a
/// slash, followed by non-whitespace."
final _possiblePathPattern = RegExp(r'[a-zA-Z:]*\/\S*');

class Lines {
  final List<int> _starts = [];

  Lines(String source) {
    final units = source.codeUnits;
    var nextIsEol = true;
    for (var i = 0; i < units.length; i++) {
      if (nextIsEol) {
        nextIsEol = false;
        _starts.add(i);
      }
      if (units[i] == 10) nextIsEol = true;
    }
  }

  /// Return the 1-based line number.
  int lineForOffset(int offset) {
    if (_starts.isEmpty) return 1;
    for (var i = 1; i < _starts.length; i++) {
      if (offset < _starts[i]) return i;
    }
    return _starts.length;
  }

  /// Return the 1-based column number.
  int columnForOffset(int offset) {
    if (_starts.isEmpty) return 1;
    for (var i = _starts.length - 1; i >= 0; i--) {
      if (offset >= _starts[i]) return offset - _starts[i] + 1;
    }
    return 1;
  }
}
