// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/**
 * This library is a wrapper around the Dart to JavaScript (dart2js) compiler.
 */
library endpoints.compiler;

import 'dart:async';

import 'package:compiler_unsupported/compiler.dart' as compiler;
import 'package:compiler_unsupported/sdk_io.dart' as sdk;
import 'package:logging/logging.dart';

import 'common.dart';

Logger _logger = new Logger('compiler');

// TODO: Are there any options we can pass in to speed up compilation time?

/**
 * An interface to the dart2js compiler. A compiler object can process one
 * compile at a time. They are heavy-weight objects, and can be re-used once
 * a compile finishes. Subsequent compiles after the first one will be faster,
 * on the order of a 2x speedup.
 */
class Compiler {
  final sdk.DartSdk _sdk;

  Compiler(String sdkPath) : _sdk = new sdk.DartSdkIO();

  Future warmup([bool useHtml = false]) =>
      compile(useHtml ? sampleCodeWeb : sampleCode);

  /// Compile the given string and return the resulting [CompilationResults].
  Future<CompilationResults> compile(String input) {
    _CompilerProvider provider = new _CompilerProvider(_sdk, input);
    Lines lines = new Lines(input);

    CompilationResults result = new CompilationResults(lines);

    // --incremental-support, --disable-type-inference
    return compiler.compile(
        provider.getInitialUri(),
        new Uri(scheme: 'sdk', path: '/'),
        new Uri(scheme: 'package', path: '/'),
        provider.inputProvider,
        result._diagnosticHandler,
        ['--no-source-maps'],
        result._outputProvider).then((_) {
      result._problems.sort();
      return result;
    });
  }
}

/// The result of a dart2js compile.
class CompilationResults {
  final StringBuffer _output = new StringBuffer();
  final List<CompilationProblem> _problems = [];
  final Lines _lines;

  CompilationResults(this._lines);

  bool get hasOutput => _output.isNotEmpty;

  String getOutput() => _output.toString();

  List<CompilationProblem> get problems => _problems;

  /// This is true if none of the reported problems were errors.
  bool get success => !_problems.any((p) => p.severity == CompilationProblem.ERROR);

  void _diagnosticHandler(Uri uri, int begin, int end, String message,
      compiler.Diagnostic kind) {
    // Convert dart2js crash types to our error type.
    if (kind == compiler.Diagnostic.CRASH) kind = compiler.Diagnostic.ERROR;

    if (kind == compiler.Diagnostic.ERROR ||
        kind == compiler.Diagnostic.WARNING ||
        kind == compiler.Diagnostic.HINT) {
      _problems.add(new CompilationProblem._(
          uri, begin, end, message, kind, _lines));
    }
  }

  EventSink<String> _outputProvider(String name, String extension) {
    return extension == 'js' ? new _StringSink(_output) : new _NullSink();
  }
}

/// An error, warning, hint, or into associated with a [CompilationResults].
class CompilationProblem implements Comparable {
  static const int INFO = 0;
  static const int WARNING = 1;
  static const int ERROR = 2;

  /// The Uri for the compilation unit; can be `null`.
  final Uri uri;

  /// The starting (0-based) character offset; can be `null`.
  final int begin;

  /// The ending (0-based) character offset; can be `null`.
  final int end;

  int _line;

  final String message;

  final compiler.Diagnostic _diagnostic;

  CompilationProblem._(this.uri, this.begin, this.end, this.message,
      this._diagnostic, Lines lines) {
    _line = begin == null ? 0 : lines.getLineForOffset(begin) + 1;
  }

  /// The 1-based line number.
  int get line => _line;

  String get kind => _diagnostic.name;

  int get severity {
    if (_diagnostic == compiler.Diagnostic.ERROR) return ERROR;
    if (_diagnostic == compiler.Diagnostic.WARNING) return WARNING;
    return INFO;
  }

  int compareTo(CompilationProblem other) {
    return severity == other.severity
        ? line - other.line : other.severity - severity;
  }

  String toString() {
    if (uri == null) {
      return "[${kind}] ${message}";
    } else {
      return "[${kind}] ${message} (${uri}:${line})";
    }
  }
}

/// A sink that drains into /dev/null.
class _NullSink implements EventSink<String> {
  _NullSink();

  add(String value) { }
  void addError(Object error, [StackTrace stackTrace]) { }
  void close() { }
}

/// Used to hold the output from dart2js.
class _StringSink implements EventSink<String> {
  final StringBuffer buffer;

  _StringSink(this.buffer);

  add(String value) => buffer.write(value);
  void addError(Object error, [StackTrace stackTrace]) { }
  void close() { }
}

/// Instances of this class allow dart2js to resolve Uris to input sources.
class _CompilerProvider {
  static const String resourceUri = 'resource:/main.dart';

  final String text;
  final sdk.DartSdk sdk;

  _CompilerProvider(this.sdk, this.text);

  Uri getInitialUri() => Uri.parse(_CompilerProvider.resourceUri);

  Future<String> inputProvider(Uri uri) {
    if (uri.scheme == 'resource') {
      if (uri.toString() == resourceUri) {
        return new Future.value(text);
      }
    } else if (uri.scheme == 'sdk') {
      String contents = sdk.getSourceForPath(uri.path);

      if (contents != null) {
        return new Future.value(contents);
      }
    }
//    } else if (uri.scheme == 'package') {
//      // Convert `package:/foo/foo.dart` to `package:foo/foo.dart`.
//      return provider.getPackageContents('package:${uri.path.substring(1)}');
//    }

    return new Future.error('file not found');
  }
}
