library url_template;

import 'url_matcher.dart';

final _specialChars = RegExp(r'[\\()$^.+[\]{}|]');
final _paramPattern = r'([^/?]+)';
final _paramWithSlashesPattern = r'([^?]+)';

/// A reversible URL template class that can match/parse and reverse URL
/// templates like: /foo/:bar/baz
class UrlTemplate implements UrlMatcher {
  // Parameter names of the template ie  `['bar']` for `/foo/:bar/baz`
  List<String> _fields;

  // The compiled template
  RegExp _pattern;

  /// The template exploded as parts
  /// - even indexes contain text
  /// - odd indexes contain closures that return the parameter value
  ///
  /// `/foo/:bar/baz` produces:
  /// - [0] = `/foo/`
  /// - [1] = `(p) => p['bar']`
  /// - [2] = `/baz`
  List _chunks;

  String toString() => 'UrlTemplate($_pattern)';

  int compareTo(UrlMatcher other) {
    final String tmpParamPattern = '\t';
    if (other is UrlTemplate) {
      String thisPattern =
          _pattern.pattern.replaceAll(_paramPattern, tmpParamPattern);
      String otherPattern =
          other._pattern.pattern.replaceAll(_paramPattern, tmpParamPattern);
      List<String> thisPatternParts = thisPattern.split('/');
      List<String> otherPatternParts = otherPattern.split('/');
      if (thisPatternParts.length == otherPatternParts.length) {
        for (int i = 0; i < thisPatternParts.length; i++) {
          String thisPart = thisPatternParts[i];
          String otherPart = otherPatternParts[i];
          if (thisPart == tmpParamPattern && otherPart != tmpParamPattern) {
            return 1;
          } else if (thisPart != tmpParamPattern &&
              otherPart == tmpParamPattern) {
            return -1;
          }
        }
        return otherPattern.compareTo(thisPattern);
      } else {
        return otherPatternParts.length - thisPatternParts.length;
      }
    } else {
      return 0;
    }
  }

  UrlTemplate(String template) {
    _compileTemplate(template);
  }

  void _compileTemplate(String template) {
    // Escape special characters
    template = template.replaceAllMapped(_specialChars, (m) => r'\' + m[0]);
    _fields = <String>[];
    _chunks = [];
    var exp = RegExp(r':(\w+\*?)');
    StringBuffer sb = StringBuffer('^');
    int start = 0;
    exp.allMatches(template).forEach((Match m) {
      var paramName = m[1];
      var txt = template.substring(start, m.start);
      _fields.add(paramName);
      _chunks.add(txt);
      _chunks.add((Map params) => params[paramName]);
      sb.write(txt);
      if (paramName.endsWith(r'*')) {
        sb.write(_paramWithSlashesPattern);
      } else {
        sb.write(_paramPattern);
      }
      start = m.end;
    });
    if (start != template.length) {
      var txt = template.substring(start, template.length);
      sb.write(txt);
      _chunks.add(txt);
    }
    _pattern = RegExp(sb.toString());
  }

  UrlMatch match(String url) {
    Match match = _pattern.firstMatch(url);
    if (match == null) {
      return null;
    }
    var parameters = Map();
    for (var i = 0; i < match.groupCount; i++) {
      parameters[_fields[i]] = match[i + 1];
    }
    var tail = url.substring(match[0].length);
    return UrlMatch(match[0], tail, parameters);
  }

  String reverse({Map parameters, String tail = ''}) {
    if (parameters == null) {
      parameters = const {};
    }
    return _chunks.map((c) => c is Function ? c(parameters) : c).join() + tail;
  }

  List<String> get urlParameterNames => _fields;
}
