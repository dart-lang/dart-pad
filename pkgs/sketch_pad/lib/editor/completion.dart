// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:codemirror/hints.dart';

import '../src/dart_services.dart' as services;

class AnalysisCompletion implements Comparable<AnalysisCompletion> {
  final int offset;
  final int length;

  final Map<String, dynamic> _map;

  AnalysisCompletion(this.offset, this.length, services.Completion completion)
      : _map = Map<String, dynamic>.from(completion.completion) {
    // TODO: We need to pass this completion info better.
    _convert('element');
    _convert('parameterNames');
    _convert('parameterTypes');

    if (_map.containsKey('element')) {
      _element!.remove('location');
    }
  }

  Map<String, dynamic>? get _element =>
      _map['element'] as Map<String, dynamic>?;

  // Convert maps and lists that have been passed as json.
  void _convert(String key) {
    if (_map[key] is String) {
      _map[key] = jsonDecode(_map[key] as String);
    }
  }

  String? get kind => _map['kind'] as String?;

  bool get isMethod =>
      _element?['kind'] == 'FUNCTION' || _element?['kind'] == 'METHOD';

  bool get isConstructor => type == 'CONSTRUCTOR';

  String? get parameters =>
      isMethod ? _element!['parameters'] as String? : null;

  int? get parameterCount =>
      isMethod ? _map['parameterNames'].length as int? : null;

  String get text {
    final str = _map['completion'] as String;
    if (str.startsWith('(') && str.endsWith(')')) {
      return str.substring(1, str.length - 1);
    } else {
      return str;
    }
  }

  String? get returnType => _map['returnType'] as String?;

  bool get isDeprecated => _map['isDeprecated'] == 'true';

  int get selectionOffset => _int(_map['selectionOffset'] as String?);

  // FUNCTION, GETTER, CLASS, ...
  String? get type =>
      _map.containsKey('element') ? _element!['kind'] as String? : kind;

  HintResult toCodemirrorHint() {
    var displayText = isMethod ? '$text$parameters' : text;
    if (isMethod && returnType != null) {
      displayText += ' → $returnType';
    }

    var replaceText = text;
    if (isMethod) {
      replaceText += '()';
    }
    if (isConstructor) {
      displayText += '()';
    }

    return HintResult(
      replaceText,
      displayText: displayText,
      className: isDeprecated ? 'deprecated' : null,
    );
  }

  @override
  int compareTo(AnalysisCompletion other) {
    return text.compareTo(other.text);
  }

  @override
  String toString() => text;

  int _int(String? val) => val == null ? 0 : int.parse(val);
}
