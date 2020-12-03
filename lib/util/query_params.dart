import 'dart:html';

class QueryParams {
  static bool get nullSafety {
    var url = Uri.parse(window.location.toString());

    if (url.hasQuery &&
        url.queryParameters['null_safety'] != null &&
        url.queryParameters['null_safety'] == 'true') {
      return true;
    }

    return false;
  }

  static set nullSafety(bool enabled) {
    var url = Uri.parse(window.location.toString());
    var params = Map<String, String>.from(url.queryParameters);
    if (enabled) {
      params['null_safety'] = 'true';
    } else if (params.containsKey('null_safety')) {
      params.remove('null_safety');
    }
    url = url.replace(queryParameters: params);
    window.history.replaceState({}, 'DartPad', url.toString());
  }

  static bool get hasNullSafety {
    var url = Uri.parse(window.location.toString());
    return url.hasQuery && url.queryParameters['null_safety'] != null;
  }
}
