// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library services.scheduler;

import 'dart:collection';
import 'dart:async';

class TaskScheduler {
  Queue<_Task> _taskQueue = new Queue();
  bool _isActive = false;

  int get queueCount => _taskQueue.length;

  Future _performTask(Task task) {
    if (task.timeoutDuration != null) {
      return task.perform().timeout(task.timeoutDuration);
    } else {
      return task.perform();
    }
  }

  Future schedule(Task task) {
    if (!_isActive) {
      _isActive = true;
      return _performTask(task).whenComplete(_next);
    }
    Completer taskResult = new Completer();
    _taskQueue.add(new _Task(task, taskResult));
    return taskResult.future;
  }

  void _next() {
    assert(_isActive);
    if (_taskQueue.isEmpty) {
      _isActive = false;
      return;
    }
    _Task first = _taskQueue.removeFirst();
    first.taskResult.complete(_performTask(first.task).whenComplete(_next));
  }
}

// Internal unit of scheduling.
class _Task {
  final task;
  final Completer taskResult;
  _Task(this.task, this.taskResult);
}

// Public working data structure.
abstract class Task {
  Future perform();
  Duration timeoutDuration;
}

class ClosureTask extends Task {
  var _closure;

  ClosureTask(this._closure, {Duration timeoutDuration}) {
    this.timeoutDuration = timeoutDuration;
  }

  @override
  Future perform() {
    return _closure();
  }
}
