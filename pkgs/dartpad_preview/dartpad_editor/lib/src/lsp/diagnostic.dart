// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// LSP diagnostic severity levels.
enum DiagnosticSeverity {
  error(1),
  warning(2),
  info(3),
  hint(4);

  const DiagnosticSeverity(this.lspValue);

  /// The numeric value used by the LSP protocol.
  final int lspValue;

  /// Human-readable label (e.g. "Error", "Warning").
  String get label => switch (this) {
    error => 'Error',
    warning => 'Warning',
    info => 'Info',
    hint => 'Hint',
  };

  /// CSS class name for styling.
  String get cssClass => switch (this) {
    error => 'error',
    warning => 'warning',
    info => 'info',
    hint => 'hint',
  };

  /// Single-character icon letter.
  String get icon => switch (this) {
    error => 'E',
    warning => 'W',
    info => 'I',
    hint => 'H',
  };

  /// Parses an LSP severity int (nullable) into a [DiagnosticSeverity].
  /// Defaults to [error] for unrecognized or null values.
  static DiagnosticSeverity fromLsp(int? value) => DiagnosticSeverity.values.firstWhere(
    (s) => s.lspValue == value,
    orElse: () => DiagnosticSeverity.error,
  );
}

/// A single LSP diagnostic entry from the language server.
class Diagnostic {
  /// The 0-indexed line number where the diagnostic occurs.
  final int line;

  /// The 0-indexed character offset within the line.
  final int character;

  /// The human-readable diagnostic message.
  final String message;

  /// The severity level of this diagnostic.
  final DiagnosticSeverity severity;

  /// The raw LSP diagnostic payload, if available.
  final Map<String, Object?>? raw;

  const Diagnostic({
    required this.line,
    required this.character,
    required this.message,
    required this.severity,
    this.raw,
  });
}

/// Associates a [Diagnostic] with the file it belongs to.
class DiagnosticEntry {
  /// The relative path of the file this diagnostic belongs to.
  final String fileName;

  /// The diagnostic reported for this file.
  final Diagnostic diagnostic;

  /// Creates a [DiagnosticEntry] linking [fileName] to [diagnostic].
  const DiagnosticEntry(this.fileName, this.diagnostic);
}

/// Flattens a map of file-to-diagnostics into a sorted list of [DiagnosticEntry]s.
///
/// Entries are sorted by severity (most severe first), then by file name,
/// then by line and character position.
List<DiagnosticEntry> sortedDiagnosticEntries(
  Map<String, List<Diagnostic>> diagnostics,
) {
  final entries = [
    for (final fileEntry in diagnostics.entries)
      for (final diagnostic in fileEntry.value) DiagnosticEntry(fileEntry.key, diagnostic),
  ];
  entries.sort((left, right) {
    final severity = left.diagnostic.severity.lspValue.compareTo(
      right.diagnostic.severity.lspValue,
    );
    if (severity != 0) {
      return severity;
    }
    final fileName = left.fileName.compareTo(right.fileName);
    if (fileName != 0) {
      return fileName;
    }
    final line = left.diagnostic.line.compareTo(right.diagnostic.line);
    if (line != 0) {
      return line;
    }
    return left.diagnostic.character.compareTo(right.diagnostic.character);
  });
  return entries;
}
