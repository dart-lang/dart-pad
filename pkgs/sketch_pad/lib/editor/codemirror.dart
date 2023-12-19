import 'dart:js_interop';
import 'package:web/web.dart';

@JS()
@anonymous
extension type CodeMirrorOptions._(JSObject _) {
  external String theme;
  external String mode;
  external bool autoCloseTags;
  external bool lineNumbers;
  external bool lineWrapping;
  external JSObject extraKeys;

  external factory CodeMirrorOptions();
}

@JS()
extension type CodeMirror._(JSObject _) {
  external factory CodeMirror(HTMLElement element, JSAny? codeMirrorOptions);
  external factory CodeMirror.fromTextArea(HTMLTextAreaElement textArea);

  external static String get version;
  external static Commands commands;
  external static Hint hint;
  external static void registerHelper(
      String type, String mode, JSFunction helper);

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
  external Position getCursor();
  external JSAny? getHelper(Position pos, String name);
  external void showHint(HintOptions? options);

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
extension type Commands._(JSObject _) {
  external set goLineLeft(JSFunction callback);
  external set indentIfMultiLineSelectionElseInsertSoftTab(JSFunction callback);
  external set weHandleElsewhere(JSFunction callback);
  external set autocomplete(JSFunction callback);
}

@JS()
extension type Events._(JSObject _) {
  external set change(JSFunction callback);
}

@JS()
extension type Doc._(JSObject _) {
  external void setValue(String value);
  external String getValue();
  external String? getLine(int n);
  external bool somethingSelected();
  external String? getSelection(String s);
  external void setSelection(Position position, [Position head]);
  external JSArray getAllMarks();
  external TextMarker markText(
      Position from, Position to, MarkTextOptions options);
  external int? indexFromPos(Position pos);
  external void replaceRange(String replacement, Position from,
      [Position? to, String? origin]);
  external Position posFromIndex(int index);
}

@JS()
@anonymous
extension type Position._(JSObject _) {
  external int line;
  external int ch;

  external factory Position({int line, int ch});
}

@JS()
extension type TextMarker._(JSObject _) {
  external void clear();
}

@JS()
@anonymous
extension type MarkTextOptions._(JSObject _) {
  external String className;
  external String title;

  external factory MarkTextOptions({
    String className,
    String title,
  });
}

@JS()
@anonymous
extension type HintResults._(JSObject _) {
  external JSArray/*<HintResult>*/ list;
  external Position from;
  external Position to;

  external factory HintResults({JSArray list, Position from, Position to});
}

@JS()
@anonymous
extension type HintResult._(JSObject _) {
  external String? text;

  external String? displayText;

  external String? className;

  external Position? from;

  external Position? to;
  external JSFunction? hintRenderer;
  external JSFunction? hint;

  external factory HintResult({
    String? text,
    String? displayText,
    String? className,
    Position? from,
    Position? to,
    JSFunction? hintRenderer,
    JSFunction? hint,
  });
}

@JS()
@anonymous
extension type HintOptions._(JSObject _) {
  external JSAny hint;
  external HintResults results;

  external factory HintOptions({JSAny hint, HintResults results});
}

@JS()
extension type Hint._(JSObject _) {
  external JSAny dart;
}
