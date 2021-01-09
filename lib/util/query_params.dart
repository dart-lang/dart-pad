import 'dart:html';

/// A utility for accessing and setting query parameters.
abstract class QueryParams {
  /// An immutable map of all current query parameters.
  static Map<String, String> get parameters {
    return Uri.parse(window.location.toString()).queryParameters;
  }

  /// Whether or not null safety is enabled through query parameters.
  static bool get nullSafety {
    final nullSafety = _queryParam('null_safety');

    return nullSafety == 'true';
  }

  static set nullSafety(bool enabled) {
    var url = Uri.parse(window.location.toString());
    var params = Map<String, String>.from(url.queryParameters);
    if (enabled) {
      params['null_safety'] = 'true';
    } else if (params.containsKey('null_safety')) {
      params.remove('null_safety');
    } else {
      return;
    }
    url = url.replace(queryParameters: params);
    window.history.replaceState({}, 'DartPad', url.toString());
  }

  /// Whether the `null_safety` query parameter is defined or not.
  static bool get hasNullSafety {
    final nullSafety = _queryParam('null_safety');

    return nullSafety != null;
  }

  static String /*?*/ get gistId {
    return _queryParam('id');
  }

  static int /*?*/ get line {
    final line = _queryParam('line');

    if (line == null) {
      return null;
    }

    return int.tryParse(line);
  }

  static String /*?*/ get theme {
    return _queryParam('theme');
  }

  static bool get autoRunEnabled {
    return _queryParam('run') == 'true';
  }

  static bool get shouldOpenConsole {
    return _queryParam('open_console') == 'true';
  }

  static bool get showInstallButton {
    return _queryParam('install_button') == 'true';
  }

  static bool get hasShowInstallButton {
    return _queryParam('install_button') != null;
  }

  static String /*?*/ get sampleId {
    return _queryParam('sample_id');
  }

  static String /*?*/ get sampleChannel {
    return _queryParam('sample_channel');
  }

  static String /*?*/ get githubOwner {
    return _queryParam('gh_owner');
  }

  static String /*?*/ get githubRepo {
    return _queryParam('gh_repo');
  }

  static String /*?*/ get githubPath {
    return _queryParam('gh_path');
  }

  static String /*?*/ get githubRef {
    return _queryParam('gh_ref');
  }

  static int /*?*/ get initialSplit {
    final split = _queryParam('split');

    if (split == null) {
      return null;
    }

    return int.tryParse(split);
  }

  static String /*?*/ _queryParam(String key) {
    return Uri.parse(window.location.toString()).queryParameters[key];
  }
}
