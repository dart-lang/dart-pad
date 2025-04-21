// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../model.dart';

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
  String text = 'no code here yet';

  @override
  void initState() {
    super.initState();
    widget.appModel.sourceCodeController.addListener(_handleTextChange);
    _handleTextChange();
  }

  void _handleTextChange() {
    setState(() => text = widget.appModel.sourceCodeController.text);
  }

  @override
  Widget build(BuildContext context) {
    return Text(text);
  }

  @override
  void dispose() {
    widget.appModel.sourceCodeController.removeListener(_handleTextChange);
    super.dispose();
  }
}
