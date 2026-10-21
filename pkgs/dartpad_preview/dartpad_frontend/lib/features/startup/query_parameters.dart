// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../preview/models/run_mode.dart';
import 'project_loader.dart';

/// The validated dartpad URL query.
///
/// Owns every recognized parameter name as a static `const` key, and validates
/// them in a private `_validate` on each model. [QueryParameters.fromUri] composes the models.
/// Presentation and channel values never throw; they fall back to a default.
final class QueryParameters {
  static const sessionId = 's';
  static const url = 'url';
  static const package = 'package';
  static const version = 'version';
  static const gist = 'gist';
  static const id = 'id';
  static const sample = 'sample';
  static const sampleId = 'sample_id';
  static const channel = 'channel';
  static const file = 'file';
  static const sdk = 'sdk';
  static const mode = 'mode';
  static const root = 'root';
  static const entrypoint = 'entrypoint';
  static const embed = 'embed';
  static const theme = 'theme';
  static const split = 'split';

  /// Keys from retired URLs. Any of them makes the query invalid.
  static const obsolete = ['archive', 'path', 'main'];

  QueryParameters._({
    required this.source,
    required this.project,
    required this.appearance,
    required this.session,
  });

  /// Parses and validates a dartpad [uri]'s query.
  factory QueryParameters.fromUri(Uri uri) {
    final raw = {
      for (final entry in uri.queryParametersAll.entries) entry.key: List<String>.unmodifiable(entry.value),
    };
    for (final key in obsolete) {
      if (raw.containsKey(key)) {
        throw FormatException('Unsupported query parameter: $key.');
      }
    }
    return QueryParameters._(
      source: SourceSelection._validate(raw),
      project: ProjectParameters._validate(raw),
      appearance: PresentationParameters._validate(raw),
      session: SessionId.parse(_lenient(raw, sessionId)),
    );
  }

  /// The selected source, or null for a bare URL.
  final SourceSelection? source;

  /// Options that configure the project contents and run target.
  final ProjectParameters project;

  /// Options that change only how the page is presented.
  final PresentationParameters appearance;

  /// The per-tab session id from the `s` parameter.
  final SessionId? session;

  /// Whether the URL names a source, rather than a bare URL.
  bool get isSourced => source != null;
}

/// Source-selecting options. At most one variant is present per URL.
sealed class SourceSelection {
  const SourceSelection();

  static SourceSelection? _validate(Map<String, List<String>> raw) {
    final candidates = <SourceSelection?>[
      UrlSourceSelection._validate(raw),
      PackageSourceSelection._validate(raw),
      GistSourceSelection._validate(raw),
      ApiDocsSourceSelection._validate(raw),
      SampleSourceSelection._validate(raw),
    ];
    final selected = candidates.nonNulls.toList();
    if (selected.length > 1) {
      throw const FormatException('Choose only one project source.');
    }
    return selected.singleOrNull;
  }
}

/// An archive location, resolved against the page URL when relative.
final class UrlSourceSelection extends SourceSelection {
  const UrlSourceSelection(this.url);

  final Uri url;

  static UrlSourceSelection? _validate(Map<String, List<String>> raw) {
    final value = _single(raw, QueryParameters.url);
    return value == null ? null : UrlSourceSelection(Uri.parse(value));
  }
}

/// A package on pub.dev, with an optional exact version.
final class PackageSourceSelection extends SourceSelection {
  const PackageSourceSelection(this.package, {this.version});

  final String package;
  final String? version;

  static PackageSourceSelection? _validate(Map<String, List<String>> raw) {
    final package = _single(raw, QueryParameters.package);
    final version = _single(raw, QueryParameters.version);
    if (version != null && package == null) {
      throw const FormatException('version requires package.');
    }
    return package == null ? null : PackageSourceSelection(package, version: version);
  }
}

/// A GitHub gist, from either `gist` or its `id` alias.
final class GistSourceSelection extends SourceSelection {
  const GistSourceSelection(this.gistId);

  final String gistId;

  static GistSourceSelection? _validate(Map<String, List<String>> raw) {
    final gist = _single(raw, QueryParameters.gist);
    final id = _single(raw, QueryParameters.id);
    if (gist != null && id != null) {
      throw const FormatException('Choose either gist or id, not both.');
    }
    final gistId = gist ?? id;
    return gistId == null ? null : GistSourceSelection(gistId);
  }
}

/// A generated Flutter API documentation snippet, from `sample_id`.
final class ApiDocsSourceSelection extends SourceSelection {
  const ApiDocsSourceSelection(this.sampleId, {this.channel = FlutterApiChannel.stable});

  final String sampleId;
  final FlutterApiChannel channel;

  static ApiDocsSourceSelection? _validate(Map<String, List<String>> raw) {
    final sampleId = _single(raw, QueryParameters.sampleId);
    if (sampleId == null) {
      return null;
    }
    return ApiDocsSourceSelection(
      sampleId,
      channel: FlutterApiChannel.parse(_lenient(raw, QueryParameters.channel)),
    );
  }
}

/// A built-in sample, from `sample`.
final class SampleSourceSelection extends SourceSelection {
  const SampleSourceSelection(this.sampleId);

  final String sampleId;

  static SampleSourceSelection? _validate(Map<String, List<String>> raw) {
    final sampleId = _single(raw, QueryParameters.sample);
    return sampleId == null ? null : SampleSourceSelection(sampleId);
  }
}

/// Which Flutter API docs host serves a `sample_id`. Unknown values become [stable].
enum FlutterApiChannel {
  stable,
  main;

  /// `main` and `master` select [main]. Any other value, empty or missing, selects [stable].
  static FlutterApiChannel parse(String? value) {
    final normalized = value?.toLowerCase();
    return normalized == 'main' || normalized == 'master' ? main : stable;
  }
}

/// Project contents and run target.
final class ProjectParameters {
  const ProjectParameters({
    this.root,
    this.entrypoint,
    this.sdk,
    this.sdkVersion,
    this.mode,
    this.files = const [],
  });

  /// Null infers the root. Empty selects the source root.
  final String? root;

  /// Source-relative run target. Null infers one.
  final String? entrypoint;

  /// Null infers the SDK kind from the root's pubspec.
  final SdkKind? sdk;

  /// Null selects the first available bundle of [sdk].
  final String? sdkVersion;

  /// Null infers the mode from the SDK and entrypoint.
  final RunMode? mode;

  /// Source-relative tab paths in URL order, including duplicates.
  final List<String> files;

  static ProjectParameters _validate(Map<String, List<String>> raw) {
    final sdk = _validateSdk(raw);
    return ProjectParameters(
      root: _validateRoot(raw),
      entrypoint: _validateEntrypoint(raw),
      sdk: sdk?.kind,
      sdkVersion: sdk?.version,
      mode: _validateMode(raw),
      files: _validateFiles(raw),
    );
  }

  static String? _validateRoot(Map<String, List<String>> raw) {
    // An empty root is valid: it selects the source root.
    final root = _single(raw, QueryParameters.root, allowEmpty: true);
    if (root != null) {
      ProjectLoader.normalizePath(root, allowRoot: true);
    }
    return root;
  }

  static String? _validateEntrypoint(Map<String, List<String>> raw) {
    final entrypoint = _single(raw, QueryParameters.entrypoint);
    if (entrypoint != null) {
      ProjectLoader.normalizePath(entrypoint);
    }
    return entrypoint;
  }

  static ({SdkKind kind, String? version})? _validateSdk(Map<String, List<String>> raw) {
    final value = _single(raw, QueryParameters.sdk);
    if (value == null) {
      return null;
    }
    final parts = value.split(':');
    final kind = SdkKind.values.asNameMap()[parts.first];
    if (kind == null || parts.length > 2 || parts.last.isEmpty) {
      throw const FormatException('sdk must be dart or flutter, optionally followed by :<version>.');
    }
    return (kind: kind, version: parts.length == 2 ? parts.last : null);
  }

  static RunMode? _validateMode(Map<String, List<String>> raw) {
    final value = _single(raw, QueryParameters.mode);
    if (value == null) {
      return null;
    }
    final mode = RunMode.values.asNameMap()[value];
    if (mode == null) {
      final allowed = RunMode.values.map((mode) => mode.name).join(' or ');
      throw FormatException('mode must be $allowed.');
    }
    return mode;
  }

  static List<String> _validateFiles(Map<String, List<String>> raw) {
    final files = raw[QueryParameters.file] ?? const <String>[];
    for (final path in files) {
      ProjectLoader.normalizePath(path);
    }
    return List.unmodifiable(files);
  }
}

/// Presentation-only options. None of these change the project contents.
final class PresentationParameters {
  const PresentationParameters({
    this.embed = false,
    this.theme,
    this.splitPercent,
  });

  /// Whether the embed layout is used.
  final bool embed;

  /// Null uses the saved preference, then the system theme.
  final UITheme? theme;

  /// Initial code panel share, clamped to 5–95. Null uses the default.
  final int? splitPercent;

  static PresentationParameters _validate(Map<String, List<String>> raw) => PresentationParameters(
    embed: _validateEmbed(raw),
    theme: _validateTheme(raw),
    splitPercent: _validateSplit(raw),
  );

  static bool _validateEmbed(Map<String, List<String>> raw) => raw[QueryParameters.embed]?.contains('true') == true;

  static UITheme? _validateTheme(Map<String, List<String>> raw) =>
      UITheme.values.asNameMap()[_lenient(raw, QueryParameters.theme)];

  static int? _validateSplit(Map<String, List<String>> raw) {
    final percent = int.tryParse(_lenient(raw, QueryParameters.split) ?? '');
    return percent?.clamp(5, 95).toInt();
  }
}

/// A non-negative session id. Dart has no unsigned int, so [parse] rejects negatives.
extension type const SessionId._(int value) {
  /// Parses [raw]. Returns null when absent, not an integer, or negative.
  static SessionId? parse(String? raw) {
    final value = int.tryParse(raw ?? '');
    return value == null || value < 0 ? null : SessionId._(value);
  }
}

/// The SDK kind named by the `sdk` parameter.
enum SdkKind { dart, flutter }

/// The page theme named by the `theme` parameter.
enum UITheme { light, dark }

/// Returns the only value for [key], or null when absent. Throws when repeated,
/// or when empty and [allowEmpty] is false.
String? _single(Map<String, List<String>> raw, String key, {bool allowEmpty = false}) {
  final values = raw[key];
  if (values == null) {
    return null;
  }
  if (values.length != 1 || (values.single.isEmpty && !allowEmpty)) {
    throw FormatException('Expected one non-empty "$key" parameter.');
  }
  return values.single;
}

/// Returns the only value for [key], or null when absent or repeated. Never throws.
String? _lenient(Map<String, List<String>> raw, String key) {
  final values = raw[key];
  return values != null && values.length == 1 ? values.single : null;
}
