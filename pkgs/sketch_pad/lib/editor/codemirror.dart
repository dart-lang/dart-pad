import 'dart:js_interop';
import 'package:web/web.dart';

@JS()
@staticInterop
@anonymous
class CodeMirrorOptions {
  external factory CodeMirrorOptions();
}

extension CodeMirrorOptionsExtension on CodeMirrorOptions {
  external String theme;
  external String mode;
  external bool autoCloseTags;
  external bool lineNumbers;
  external bool lineWrapping;
  external JSObject extraKeys;
}

@JS()
@staticInterop
class CodeMirror {
  external factory CodeMirror(Element element, JSAny? codeMirrorOptions);
  external factory CodeMirror.fromTextArea(HTMLTextAreaElement textArea);
  external static String get version;
  external static Commands commands;
  external static void registerHelper(String type, String mode, JSFunction helper);
}

extension CodeMirrorExtension on CodeMirror {
  external void refresh();
  external void focus();
  external void setOption(String option, JSAny value);
  external JSAny getOption(String option);
  String getTheme() => (getOption('theme') as JSString).toDart;
  void setTheme(String theme) => setOption('theme', theme.toJS);
  external Doc getDoc();
  external JSAny execCommand(String command, [JSAny? object]);
  external Events events;
  external void on(String event, JSFunction callback);
  external JSFunction showHint;
  external Commands commands;

  void setReadOnly(bool value, [bool noCursor = false]) {
    if (value) {
      if (noCursor) {
        setOption('readOnly', 'nocursor'.toJS);
      } else {
        setOption('readOnly', value.toJS);
      }
    } else {
      setOption('readOnly', value.toJS);
    }
  }
}

@JS()
@staticInterop
class Commands {

}

extension CommandsExtension on Commands {
  external set goLineLeft(JSFunction callback);
  external set indentIfMultiLineSelectionElseInsertSoftTab(JSFunction callback);
  external set weHandleElsewhere(JSFunction callback);
  external set autocomplete(JSFunction callback);
}

@JS()
@staticInterop
class Events {

}

extension EventsExtension on Events {
  external set change(JSFunction callback);
}

@JS()
@staticInterop
class Doc {
}

extension DocExtension on Doc {
  external void setValue(String value);
  external String getValue();
  external String? getLine(int n);
  external bool somethingSelected();
  external String? getSelection(String s);
  external void setSelection(Position position, [Position head]);
  external JSArray getAllMarks();
  external TextMarker markText(Position from, Position to, MarkTextOptions options);
}

@JS()
@staticInterop
@anonymous
class Position {
  external factory Position({int line, int ch});
}

extension PositionExtension on Position {
  external int line;
  external int ch;
}

@JS()
@staticInterop
@anonymous
class TextMarker {
}

extension TextMarkerExtension on TextMarker {
  external void clear();
}

@JS()
@staticInterop
@anonymous
class MarkTextOptions {
  external factory MarkTextOptions({String className, String title,});
}
extension MarkTextOptionsExtension on MarkTextOptions {
  external String className;
  external String title;
}
