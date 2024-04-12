// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dartpad_shared/model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;

import 'model.dart';
import 'theme.dart';
import 'widgets.dart';

class DocsWidget extends StatefulWidget {
  final AppModel appModel;

  const DocsWidget({
    required this.appModel,
    super.key,
  });

  @override
  State<DocsWidget> createState() => _DocsWidgetState();
}

class _DocsWidgetState extends State<DocsWidget> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(
          top: Divider.createBorderSide(
            context,
            width: 8.0,
            color: theme.colorScheme.surface,
          ),
        ),
      ),
      padding: const EdgeInsets.all(denseSpacing),
      child: Stack(
        children: [
          ValueListenableBuilder(
            valueListenable: widget.appModel.currentDocs,
            builder: (context, DocumentResponse? docs, _) {
              // TODO: Consider showing propagatedType if not null.

              var title = _cleanUpTitle(docs?.elementDescription);
              if (docs?.deprecated == true) {
                title = '$title (deprecated)';
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (title.isNotEmpty)
                    Text(
                      title,
                      style: theme.textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (title.isNotEmpty) const SizedBox(height: denseSpacing),
                  Expanded(
                    child: Markdown(
                      data: docs?.dartdoc ?? '',
                      padding: const EdgeInsets.only(left: denseSpacing),
                      onTapLink: _handleMarkdownTap,
                    ),
                  ),
                ],
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.all(denseSpacing),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MiniIconButton(
                  icon: Icons.close,
                  tooltip: 'Close',
                  onPressed: _closePanel,
                  small: true,
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _closePanel() {
    widget.appModel.docsShowing.value = false;
  }

  String _cleanUpTitle(String? title) {
    if (title == null) return '';

    // "(new) Text(\n  String data, {\n  Key? key,\n  ... selectionColor,\n})"

    // Remove ws right after method args.
    title = title.replaceAll('(\n  ', '(');

    // Remove ws before named args.
    title = title.replaceAll('{\n  ', '{');

    // Remove ws after named args.
    title = title.replaceAll(',\n}', '}');

    return title.replaceAll('\n', '').replaceAll('  ', ' ');
  }

  void _handleMarkdownTap(String text, String? href, String title) {
    if (href != null) {
      final uri = Uri.tryParse(href);
      if (uri == null) {
        widget.appModel.editorStatus.showToast('Unable to open: $href');
      } else {
        url_launcher.launchUrl(uri);
      }
    }
  }
}
