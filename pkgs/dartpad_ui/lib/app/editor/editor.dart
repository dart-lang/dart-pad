// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:pretty_diff_text/pretty_diff_text.dart';

import '../../model.dart';
import '../../theme.dart';
import 'stub/editor.dart'
    if (dart.library.js_interop) 'web/editor.dart'
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

class ReadOnlyDiffWidget extends StatelessWidget {
  const ReadOnlyDiffWidget({
    required this.existingSource,
    required this.newSource,
    super.key,
  });

  const ReadOnlyDiffWidget.noDiff({required String source, super.key})
    : existingSource = source,
      newSource = source;

  final String existingSource;
  final String newSource;

  // NOTE: the focus is needed to enable GeneratingCodeDialog to process
  // keyboard shortcuts, e.g. cmd+enter
  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: SizedBox(
          width: double.infinity,
          child: PrettyDiffText(
            oldText: existingSource,
            newText: newSource,
            defaultTextStyle: TextStyle(
              color: Theme.of(context).textTheme.bodyMedium?.color,
              fontFamily: monospaceFontFamily,
            ),
            addedTextStyle: const TextStyle(
              color: Colors.black,
              backgroundColor: Color.fromARGB(255, 201, 255, 201),
              fontFamily: monospaceFontFamily,
            ),
            deletedTextStyle: const TextStyle(
              color: Colors.black,
              backgroundColor: Color.fromARGB(255, 249, 199, 199),
              decoration: TextDecoration.lineThrough,
              fontFamily: monospaceFontFamily,
            ),
          ),
        ),
      ),
    );
  }
}
