// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:flutter/material.dart';

import '../../local_storage/local_storage.dart';
import '../../model.dart';
import 'editor_service.dart';

// TODO: implement find / find next

class EditorWidgetImpl extends StatefulWidget {
  final AppModel appModel;
  final AppServices appServices;

  const EditorWidgetImpl({
    required this.appModel,
    required this.appServices,
    super.key,
  });

  @override
  State<EditorWidgetImpl> createState() => _EditorWidgetImplState();
}

class _EditorWidgetImplState extends State<EditorWidgetImpl> {
  StreamSubscription<void>? _listener;
  late final EditorServiceImpl _editorService;

  @override
  void initState() {
    super.initState();
    _editorService = EditorServiceImpl(widget.appModel, widget.appServices);
    _autosaveTimer = Timer.periodic(const Duration(seconds: 5), _autosave);
    widget.appModel.appReady.addListener(_updateEditableStatus);
  }

  Timer? _autosaveTimer;
  void _autosave([Timer? timer]) {
    final content = widget.appModel.sourceCodeController.text;
    if (content.isEmpty) return;
    DartPadLocalStorage.instance.saveUserCode(content);
  }

  @override
  Widget build(BuildContext context) {
    final darkMode = Theme.of(context).brightness == Brightness.dark;
    _editorService.updateCodemirrorMode(darkMode);
    return _editorService.focusableActionDetector(darkMode);
  }

  @override
  void dispose() {
    _listener?.cancel();
    _autosaveTimer?.cancel();

    widget.appServices.registerEditorService(null);

    widget.appModel.sourceCodeController.removeListener(
      _editorService.updateCodemirrorFromModel,
    );
    widget.appModel.appReady.removeListener(_updateEditableStatus);
    widget.appModel.vimKeymapsEnabled.removeListener(
      _editorService.updateCodemirrorKeymap,
    );

    super.dispose();
  }

  void _updateEditableStatus() {
    _editorService.updateEditableStatus();
  }
}
