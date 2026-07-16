@JS('window._codemirror')
library;

import 'dart:js_interop';

import 'package:codemirror_lang_dart/codemirror_lang_dart.dart' show dartLanguage;
import 'package:web/web.dart' as web;

// =============================================================================
// Codemirror Types
// =============================================================================

extension type ChangeSpec._(JSObject _) implements JSObject {
  external factory ChangeSpec({int from, int? to, JSString? insert});

  external int get from;
  external int get to;
}

extension type Compartment._(JSObject _) implements JSObject {
  external factory Compartment();
  external JSAny of(JSAny extension);
  external JSAny reconfigure(JSAny extension);
}

extension type EditorSelection(JSObject _) implements JSObject {
  external static EditorSelection cursor(int pos);
  external static EditorSelection create(JSArray<SelectionRange> ranges, [int? mainIndex]);
  external static SelectionRange range(int anchor, int head);

  external JSArray<SelectionRange> get ranges;
  external SelectionRange get main;
}

extension type EditorState(JSObject _) implements JSObject {
  external static EditorState create(EditorStateConfig config);
  external static Facet get languageData;

  external Text get doc;
  external EditorSelection get selection;
}

extension type EditorStateConfig._(JSObject _) implements JSObject {
  external factory EditorStateConfig({
    JSString? doc,
    EditorSelection? selection,
    JSArray<JSAny>? extensions,
  });
}

extension type EditorView._(JSObject _) implements JSObject {
  external factory EditorView(EditorViewConfig config);

  external EditorState get state;
  external void dispatch(TransactionSpec spec);
  external void destroy();
  external void requestMeasure();
  external void focus();
  external web.HTMLElement get scrollDOM;
  external web.HTMLElement get dom;
  external Rect? coordsAtPos(int pos, [int? side]);

  external static UpdateListener get updateListener;

  external static JSAny scrollIntoView(int pos, [ScrollIntoViewOptions? options]);
}

extension type EditorViewConfig._(JSObject _) implements JSObject {
  external factory EditorViewConfig({
    EditorState? state,
    web.HTMLElement? parent,
  });
}

extension type KeyBinding._(JSObject _) implements JSObject {
  external factory KeyBinding({
    JSString key,
    JSFunction run,
    bool? preventDefault,
  });
}

extension type Line(JSObject _) implements JSObject {
  external int get from;
  external int get to;
  external int get length;
  external JSString get text;
}

extension type LSPClient._(JSObject _) implements JSObject {
  external void sync();
  external JSPromise request(JSString method, JSObject params);
}

extension type LSPCodeAction(JSObject _) implements JSObject {
  external JSString get title;
  external JSString? get kind;
  external JSObject? get edit;
  external JSObject? get command;
}

extension type LSPPlugin._(JSObject _) implements JSObject {
  external static LSPPlugin? get(EditorView view);

  external LSPClient get client;
  external JSString get uri;
  external JSObject toPosition(int pos);
  external int fromPosition(JSObject pos);
}

@anonymous
extension type Panel._(JSObject _) implements JSObject {
  external factory Panel({
    web.HTMLElement dom,
    JSFunction? mount,
    JSFunction? update,
    JSFunction? destroy,
    bool? top,
  });
}

extension type Rect(JSObject _) implements JSObject {
  external double get left;
  external double get right;
  external double get top;
  external double get bottom;
}

extension type ScrollIntoViewOptions._(JSObject _) implements JSObject {
  external factory ScrollIntoViewOptions({JSString? y});
}

extension type SelectionActionConfig._(JSObject _) implements JSObject {
  external factory SelectionActionConfig({
    JSString key,
    JSString label,
    JSFunction run,
  });
}

extension type SelectionRange(JSObject _) implements JSObject {
  external int get anchor;
  external int get head;
  external int get from;
  external int get to;
  external bool get empty;
}

extension type ShowPanel._(JSObject _) implements JSObject {
  external JSAny of(JSFunction createPanel);
}

extension type SyntaxHighlightingOptions._(JSObject _) implements JSObject {
  external factory SyntaxHighlightingOptions({bool? fallback});
}

extension type Text(JSObject _) implements JSObject {
  external int get length;
  external int get lines;
  external Line line(int line);

  @JS('toString')
  external JSString toJsString();
}

extension type TransactionSpec._(JSObject _) implements JSObject {
  external factory TransactionSpec({
    JSAny? changes, // ChangeSpec or JSArray<ChangeSpec>
    EditorSelection? selection,
    JSAny? effects, // JSAny or JSArray<JSAny>
    JSAny? scrollIntoView,
  });
}

extension type StateEffectType(JSObject _) implements JSObject {
  external StateEffect of(JSAny? value);
}

extension type StateEffect(JSObject _) implements JSObject {}

@JS()
external StateEffectType get forceSemanticTokensRefresh;

extension type UpdateListener(JSObject _) implements JSObject {
  external JSAny of(JSFunction callback);
}

extension type ViewUpdate(JSObject _) implements JSObject {
  external bool get docChanged;
  external EditorState get state;
}

// =============================================================================
// Codemirror Extensions
// =============================================================================

@JS()
external JSAny get basicSetup;

@JS()
external JSAny get defaultHighlightStyle;

@JS()
external JSAny gotoDefinitionOnClick();

@JS()
external JSAny get indentWithTab;

@JS('keymap.of')
external JSAny keymapOf(JSArray<KeyBinding> bindings);

@JS()
external JSAny lintGutter();

@JS()
external JSAny linter(JSFunction? source);

@JS()
external JSAny get oneDark;

@JS()
external JSAny selectionAction(SelectionActionConfig config);

@JS()
external ShowPanel get showPanel;

@JS()
external JSAny syntaxHighlighting(JSAny style, [SyntaxHighlightingOptions? options]);

@JS()
external JSAny diagnosticHoverToolbar(JSArray<ToolbarAction> actions);

@JS()
@anonymous
extension type ToolbarAction._(JSObject _) implements JSObject {
  external factory ToolbarAction({
    JSString label,
    JSFunction run,
  });
}

extension type CMDiagnostic(JSObject _) implements JSObject {
  external int get from;
  external int get to;
  external JSString get severity;
  external JSString get message;
}

@JS()
external JSFunction get toggleLineComment;

@JS()
external JSFunction get formatDocument;

extension type Facet._(JSObject _) implements JSObject {
  external JSAny of(JSAny value);
}

@JS()
external JSAny yaml();

@JS()
external JSAny markdown();

@JS()
external JSAny javascript();

@JS()
external JSAny html();

@JS()
external JSAny css();

@JS()
external JSAny json();

@JS()
external JSAny xml();

@JS()
external JSAny sass();

@JS()
external JSAny sql();

JSObject dart() {
  final language = dartLanguage();

  final languageDataProvider = ((EditorState state, JSNumber pos, JSNumber side) {
    return [
          {
                'commentTokens':
                    {
                          'line': '//',
                          'block': {'open': '/*', 'close': '*/'},
                        }.jsify()
                        as JSObject,
              }.jsify()
              as JSObject,
        ].jsify()
        as JSArray;
  }).toJS;

  return [
        language,
        EditorState.languageData.of(languageDataProvider),
        keymapOf(
          [
            KeyBinding(
              key: 'Mod-/'.toJS,
              run: toggleLineComment,
            ),
            KeyBinding(
              key: 'Mod-Shift-7'.toJS,
              run: toggleLineComment,
            ),
            KeyBinding(
              key: 'Mod-Shift-/'.toJS,
              run: toggleLineComment,
            ),
            KeyBinding(
              key: 'Mod-Shift-Digit7'.toJS,
              run: toggleLineComment,
            ),
          ].toJS,
        ),
      ].jsify()
      as JSObject;
}
