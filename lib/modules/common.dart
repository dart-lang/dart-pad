
library modules.common;

final String serverURL = 'http://localhost:8081/api';

class Lines {
  List<int> _starts = [];

  Lines(String source) {
    List<int> units = source.codeUnits;
    for (int i = 0; i < units.length; i++) {
      if (units[i] == 10) _starts.add(i);
    }
  }

  /// Return the 0-based line number.
  int getLineForOffset(int offset) {
    for (int i = 0; i < _starts.length; i++) {
      if (offset <= _starts[i]) return i;
    }
    return _starts.length;
  }
}
