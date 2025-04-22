// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pretty_diff_text/pretty_diff_text.dart';

import '../model.dart';
import 'stub/editor.dart'
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

class ReadOnlyCodeWidget extends StatefulWidget {
  const ReadOnlyCodeWidget(this.source, {super.key});
  final String source;

  @override
  State<ReadOnlyCodeWidget> createState() => _ReadOnlyCodeWidgetState();
}

class _ReadOnlyCodeWidgetState extends State<ReadOnlyCodeWidget> {
  final _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _textController.text = widget.source;
  }

  @override
  void didUpdateWidget(covariant ReadOnlyCodeWidget oldWidget) {
    if (widget.source != oldWidget.source) {
      setState(() {
        _textController.text = widget.source;
      });
    }

    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      child: SizedBox(
        height: 500,
        child: TextField(
          controller: _textController,
          readOnly: true,
          maxLines: null,
          style: GoogleFonts.robotoMono(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: Theme.of(context).textTheme.bodyMedium?.color,
          ),
          decoration: const InputDecoration(border: InputBorder.none),
        ),
      ),
    );
  }
}

class ReadOnlyDiffWidget extends StatelessWidget {
  const ReadOnlyDiffWidget({
    required this.existingSource,
    required this.newSource,
    super.key,
  });

  final String existingSource;
  final String newSource;

  // NOTE: the focus is needed to enable GeneratingCodeDialog to process
  // keyboard shortcuts, e.g. cmd+enter
  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      child: SizedBox(
        height: 500,
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: PrettyDiffText(
            oldText: existingSource,
            newText: newSource,
            defaultTextStyle: GoogleFonts.robotoMono(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Theme.of(context).textTheme.bodyMedium?.color,
            ),
            addedTextStyle: const TextStyle(
              color: Colors.black,
              backgroundColor: Color.fromARGB(255, 201, 255, 201),
            ),
            deletedTextStyle: const TextStyle(
              color: Colors.black,
              backgroundColor: Color.fromARGB(255, 249, 199, 199),
              decoration: TextDecoration.lineThrough,
            ),
          ),
        ),
      ),
    );
  }
}
