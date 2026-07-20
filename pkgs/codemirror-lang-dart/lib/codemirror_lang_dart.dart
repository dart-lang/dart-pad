// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:js_interop';
import 'dart:typed_data';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/error/listener.dart';
// ignore: implementation_imports
import 'package:analyzer/src/dart/scanner/scanner.dart';
// ignore: implementation_imports
import 'package:analyzer/src/string_source.dart';

@JS('window._codemirror')
external _CodemirrorNamespace get _codemirrorModule;

/// A JavaScript interop namespace definition for the CodeMirror Dart analyzer extension.
/// Exposes the backend binding hook to the JavaScript module runtime.
extension type _CodemirrorNamespace(JSObject _) implements JSObject {
  /// Binds the given [parseCallback] to the frontend JavaScript `dartLanguage` function exported by the TS layer.
  @JS('dartLanguage')
  external JSObject dartLanguage(JSFunction parseCallback);
}

/// Initializes and constructs the Dart analyzer plugin for CodeMirror 6.
/// This hooks the [parseCodeCallback] directly into the frontend `dartLanguage` module exported by TS.
JSObject dartLanguage() {
  return _codemirrorModule.dartLanguage(parseCodeCallback.toJS);
}

/// Maps a Dart analyzer [Token] to an integer identifier matching the `dartNodeSet` definition
/// established in the `index.ts` JavaScript frontend mapping.
int _mapTokenType(Token token) {
  var type = token.type;
  if (type.isKeyword || token.keyword != null) {
    return 2; // Keyword
  }
  if (type == TokenType.IDENTIFIER) {
    if (token.previous?.type == TokenType.HASH) {
      // Punctuation
      return 7;
    }
    // Identifier
    return 3;
  }
  if (type == TokenType.STRING) {
    return 4; // String
  }
  if (type == TokenType.DOUBLE || type == TokenType.INT || type == TokenType.HEXADECIMAL) {
    return 5; // Number
  }
  if (type.isOperator) {
    return 6; // Operator
  }
  if (type == TokenType.OPEN_PAREN ||
      type == TokenType.CLOSE_PAREN ||
      type == TokenType.OPEN_CURLY_BRACKET ||
      type == TokenType.CLOSE_CURLY_BRACKET ||
      type == TokenType.OPEN_SQUARE_BRACKET ||
      type == TokenType.CLOSE_SQUARE_BRACKET ||
      type == TokenType.COMMA ||
      type == TokenType.SEMICOLON ||
      type == TokenType.COLON ||
      type == TokenType.PERIOD ||
      type == TokenType.QUESTION ||
      type == TokenType.STRING_INTERPOLATION_EXPRESSION ||
      type == TokenType.STRING_INTERPOLATION_IDENTIFIER ||
      type == TokenType.HASH ||
      type == TokenType.AT ||
      type.lexeme == '#' ||
      type.lexeme == '@') {
    return 7; // Punctuation
  }

  if (type.lexeme == '=>') {
    return 6; // Operator
  }

  if (type == TokenType.MULTI_LINE_COMMENT || type == TokenType.SINGLE_LINE_COMMENT) {
    return 8; // Comment
  }
  return 0; // Unknown
}

/// Tracks a pending syntax node (like an open bracket or a TopLevel declaration) whose closing bound
/// has not yet been discovered by the token scanner. Used to reconstruct nested structural trees.
class _PendingNode {
  /// The integer identifying the node type in the CodeMirror `dartNodeSet`.
  final int id;

  /// The absolute starting character offset of the node in the source document.
  final int startOffset;

  /// The index within the flatbuffer payload where this node's children begin.
  final int bufferStartIndex;

  _PendingNode(this.id, this.startOffset, this.bufferStartIndex);
}

/// The primary bridge function invoked by CodeMirror's `DartParser` across the JS-Interop boundary.
///
/// Efficiently tokenizes the Dart [codeStr] using the `analyzer` package, while skipping over regions
/// marked as unchanged in [cleanRangesJs] to drastically optimize incremental typing performance.
/// Returns an Int32Array representing a flattened Lezer flatbuffer syntax tree structure.
/// This needs to be exposed for benchmarking.
JSInt32Array parseCodeCallback(JSString codeStr, [JSArray<JSNumber>? cleanRangesJs]) {
  final code = codeStr.toDart;
  final cleanRanges = cleanRangesJs?.toDart.map((e) => e.toDartInt).toList() ?? <int>[];

  final buffer = <int>[];
  var stack = <_PendingNode>[];
  _PendingNode? currentTopLevel;
  int lastValidOffset = 0;
  int cleanIdx = 0;
  int bleedAttemptCount = 0;

  /// Helper to extract comments (which the scanner attaches to subsequent tokens).
  /// Enforces bounds checking so we don't accidentally emit comments belonging to skipped clean regions.
  void addCommentsBetween(Token? comment, int minOffset, int maxOffset, int offsetShift) {
    while (comment != null) {
      int absOffset = comment.offset + offsetShift;
      int absEnd = comment.end + offsetShift;
      if (absOffset >= minOffset && absEnd <= maxOffset) {
        if (comment.type == TokenType.MULTI_LINE_COMMENT || comment.type == TokenType.SINGLE_LINE_COMMENT) {
          buffer.add(8); // Node ID 8 = Comment
          buffer.add(absOffset);
          buffer.add(absEnd);
          buffer.add(4); // Flat node size = 4 ints
        }
      }
      comment = comment.next;
    }
  }

  // Main incremental parsing loop walking through the source code.
  while (lastValidOffset < code.length) {
    // Fast-forward the clean ranges array to ignore any ranges we've already bypassed.
    while (cleanIdx < cleanRanges.length && cleanRanges[cleanIdx] < lastValidOffset) {
      cleanIdx += 3;
    }

    // Determine the boundaries of the current "dirty" (edited) chunk that MUST be tokenized.
    int dirtyStart = lastValidOffset;
    int dirtyEnd = code.length;
    bool hasCleanRange = cleanIdx < cleanRanges.length;

    if (hasCleanRange) {
      // The dirty chunk ends exactly where the next known structurally clean range begins.
      dirtyEnd = cleanRanges[cleanIdx];
    }

    if (dirtyStart < dirtyEnd) {
      // Snapshot the parser state before analyzing the dirty chunk.
      // If the dirty chunk contains unclosed syntax (e.g. an unclosed bracket or unescaped string),
      // it "bleeds" into the clean range, forcefully invalidating it. We use these saved states to rollback!
      int savedBufferLength = buffer.length;
      var savedStack = stack.toList();
      var savedTopLevel = currentTopLevel;
      int savedLastValidOffset = lastValidOffset;

      // Extract only the modified source text span.
      String substring = code.substring(dirtyStart, dirtyEnd);
      var source = StringSource(substring, '');
      var diagnosticCollector = RecordingDiagnosticListener();
      var diagnosticReporter = DiagnosticReporter(diagnosticCollector, source);

      // Initialize the Dart token scanner isolated to just this dirty substring.
      var scanner = Scanner(substring, diagnosticReporter)
        ..configureFeatures(
          featureSetForOverriding: FeatureSet.latestLanguageVersion(),
          featureSet: FeatureSet.latestLanguageVersion(),
        );
      var token = scanner.tokenize();

      while (token.type != TokenType.EOF) {
        int absOffset = token.offset + dirtyStart;
        int absEnd = token.end + dirtyStart;

        if (stack.isEmpty && currentTopLevel == null) {
          int startOffset = absOffset;
          if (token.precedingComments != null) {
            startOffset = token.precedingComments!.offset + dirtyStart;
          }
          currentTopLevel = _PendingNode(12, startOffset, buffer.length);
          addCommentsBetween(token.precedingComments, lastValidOffset, absOffset, dirtyStart);
          lastValidOffset = absOffset;
        } else {
          addCommentsBetween(token.precedingComments, lastValidOffset, absOffset, dirtyStart);
          lastValidOffset = absOffset;
        }

        int id = _mapTokenType(token);

        if (token.type == TokenType.OPEN_CURLY_BRACKET || token.type == TokenType.STRING_INTERPOLATION_EXPRESSION) {
          stack.add(_PendingNode(9, absOffset, buffer.length));
        } else if (token.type == TokenType.OPEN_SQUARE_BRACKET) {
          stack.add(_PendingNode(10, absOffset, buffer.length));
        } else if (token.type == TokenType.OPEN_PAREN) {
          stack.add(_PendingNode(11, absOffset, buffer.length));
        }

        // If the token matches a known syntax highlighting node, emit a flatbuffer record natively.
        // Format: [NodeID, StartOffset, EndOffset, ByteSizeOfSubtree]
        if (id != 0) {
          buffer.add(id);
          buffer.add(absOffset);
          buffer.add(absEnd);
          buffer.add(4); // Flat nodes have a static size of 4 integers.
        }
        lastValidOffset = absEnd;

        // Resolve structural scope closures by scanning the stack backwards for the matching opener.
        if (token.type == TokenType.CLOSE_CURLY_BRACKET) {
          int idx = stack.lastIndexWhere((n) => n.id == 9);
          if (idx != -1) {
            var node = stack.removeAt(idx);
            // Calculate total size of the block including all its children mapped into the flat buffer.
            int size = buffer.length - node.bufferStartIndex + 4;
            buffer.add(node.id);
            buffer.add(node.startOffset);
            buffer.add(absEnd);
            buffer.add(size);
            stack.length = idx; // Truncate out-of-order bounds if necessary
          }
        } else if (token.type == TokenType.CLOSE_SQUARE_BRACKET) {
          int idx = stack.lastIndexWhere((n) => n.id == 10);
          if (idx != -1) {
            var node = stack.removeAt(idx);
            int size = buffer.length - node.bufferStartIndex + 4;
            buffer.add(node.id);
            buffer.add(node.startOffset);
            buffer.add(absEnd);
            buffer.add(size);
            stack.length = idx;
          }
        } else if (token.type == TokenType.CLOSE_PAREN) {
          int idx = stack.lastIndexWhere((n) => n.id == 11);
          if (idx != -1) {
            var node = stack.removeAt(idx);
            int size = buffer.length - node.bufferStartIndex + 4;
            buffer.add(node.id);
            buffer.add(node.startOffset);
            buffer.add(absEnd);
            buffer.add(size);
            stack.length = idx;
          }
        }

        if (stack.isEmpty && currentTopLevel != null) {
          if (token.type == TokenType.SEMICOLON || token.type == TokenType.CLOSE_CURLY_BRACKET) {
            int size = buffer.length - currentTopLevel.bufferStartIndex + 4;
            buffer.add(currentTopLevel.id);
            buffer.add(currentTopLevel.startOffset);
            buffer.add(absEnd);
            buffer.add(size);
            currentTopLevel = null;
          }
        }

        if (token.next != null) {
          token = token.next!;
        } else {
          break;
        }
      }

      addCommentsBetween(token.precedingComments, lastValidOffset, dirtyEnd, dirtyStart);
      lastValidOffset = dirtyEnd;

      // Validate structural integrity of the dirty chunk to prevent invalid reuse bounds.
      bool chunkBleeds = false;

      // If the scanner emitted any lexical errors (like an unclosed multi-line comment), it bleeds.
      if (diagnosticCollector.diagnostics.isNotEmpty) {
        chunkBleeds = true;
      }
      // If we crossed into a clean range while holding an open parenthesis or unresolved top-level bracket, it bleeds!
      if (stack.isNotEmpty || currentTopLevel != null) {
        chunkBleeds = true;
      }

      if (chunkBleeds && hasCleanRange) {
        // Rollback the buffer state to before we parsed the dirty chunk.
        buffer.length = savedBufferLength;
        stack = savedStack;
        currentTopLevel = savedTopLevel;
        lastValidOffset = savedLastValidOffset;

        // Discard exponentially more clean chunks and restart the parse over a larger contiguous dirty region!
        int chunksToDiscard = 1 << bleedAttemptCount;
        bleedAttemptCount++;
        for (int i = 0; i < chunksToDiscard && cleanIdx < cleanRanges.length; i++) {
          cleanIdx += 3;
        }
        continue; // Re-evaluate the widened dirty chunk payload!
      }

      bleedAttemptCount = 0;
    }

    // Splice in the clean, unedited structural blocks gracefully natively.
    if (hasCleanRange) {
      int cleanStart = cleanRanges[cleanIdx];
      int cleanEnd = cleanRanges[cleanIdx + 1];
      int reusedIndex = cleanRanges[cleanIdx + 2];

      buffer.add(reusedIndex);
      buffer.add(cleanStart);
      buffer.add(cleanEnd);
      buffer.add(-1); // Size -1 is Lezer's 'SpecialRecord.Reuse' identifier pointing to previous fragment nodes.

      lastValidOffset = cleanEnd;
      cleanIdx += 3;
    }
  }

  // Flush any unclosed nodes naturally reaching EOF
  if (currentTopLevel != null || stack.isNotEmpty) {
    for (var node in stack.reversed) {
      int size = buffer.length - node.bufferStartIndex + 4;
      buffer.add(node.id);
      buffer.add(node.startOffset);
      buffer.add(code.length);
      buffer.add(size);
    }
    if (currentTopLevel != null) {
      int size = buffer.length - currentTopLevel.bufferStartIndex + 4;
      buffer.add(currentTopLevel.id);
      buffer.add(currentTopLevel.startOffset);
      buffer.add(code.length);
      buffer.add(size);
    }
  }

  buffer.add(1); // Program ID
  buffer.add(0);
  buffer.add(code.length);
  buffer.add(buffer.length + 1);

  return Int32List.fromList(buffer).toJS;
}
