import 'package:flutter/material.dart';

import '../model.dart';
import '_stub/editor.dart'
    if (dart.library.js_interop) '_web/editor.dart'
    show EditorWidgetImpl;

class EditorWidget extends StatelessWidget {
  const EditorWidget({
    super.key,
    required this.appModel,
    required this.appServices,
  });

  final AppModel appModel;
  final AppServices appServices;

  @override
  Widget build(BuildContext context) {
    return EditorWidgetImpl(appModel: appModel, appServices: appServices);
  }
}
