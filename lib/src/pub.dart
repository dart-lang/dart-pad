// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// ignore_for_file: implementation_imports

import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/error/listener.dart';
import 'package:analyzer/src/dart/scanner/reader.dart';
import 'package:analyzer/src/dart/scanner/scanner.dart';
import 'package:analyzer/src/string_source.dart';

import 'common.dart';

Set<String> getAllImportsFor(String dartSource) {
  if (dartSource == null) return <String>{};

  final scanner = Scanner(
    StringSource(dartSource, kMainDart),
    CharSequenceReader(dartSource),
    AnalysisErrorListener.NULL_LISTENER,
  );
  var token = scanner.tokenize();

  final imports = <String>{};

  while (token.type != TokenType.EOF) {
    if (_isLibrary(token)) {
      token = _consumeSemi(token);
    } else if (_isImport(token)) {
      token = token.next;

      if (token.type == TokenType.STRING) {
        imports.add(stripMatchingQuotes(token.lexeme));
      }

      token = _consumeSemi(token);
    } else {
      break;
    }
  }

  return imports;
}

/// Return the list of packages that are imported from the given imports. These
/// packages are sanitized defensively.
Set<String> filterSafePackagesFromImports(Set<String> allImports) {
  return Set<String>.from(allImports.where((String import) {
    return import.startsWith('package:');
  }).map((String import) {
    return import.substring(8);
  }).map((String import) {
    final index = import.indexOf('/');
    return index == -1 ? import : import.substring(0, index);
  }).map((String import) {
    return import.replaceAll('..', '');
  }).where((String import) {
    return import.isNotEmpty;
  }));
}

bool _isLibrary(Token token) {
  return token.isKeyword && token.lexeme == 'library';
}

bool _isImport(Token token) {
  return token.isKeyword && token.lexeme == 'import';
}

Token _consumeSemi(Token token) {
  while (token.type != TokenType.SEMICOLON) {
    if (token.type == TokenType.EOF) return token;
    token = token.next;
  }

  // Skip past the semi-colon.
  token = token.next;

  return token;
}
