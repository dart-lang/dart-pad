
library liftoff.common;

abstract class TextProvider {
  // TODO: current location as well

  String getText();
}

class StringTextProvider {
  final String _text;
  StringTextProvider(this._text);
  String getText() => _text;
}
