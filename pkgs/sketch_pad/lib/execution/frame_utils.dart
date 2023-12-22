import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart';

extension HTMLIFrameElementExtension on HTMLIFrameElement {
  void safelyPostMessage(
    JSAny? message,
    String optionsOrTargetOrigin,
  ) {
    (this as JSObject)
        .getProperty<JSObject>('contentWindow'.toJS)
        .callMethod('postMessage'.toJS, message, optionsOrTargetOrigin.toJS);
  }
}
