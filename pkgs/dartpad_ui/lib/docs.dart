// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dartpad_shared/model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;

import 'model.dart';
import 'theme.dart';

class DocsWidget extends StatefulWidget {
  final AppModel appModel;
  final DocumentResponse documentResponse;

  const DocsWidget({
    required this.appModel,
    required this.documentResponse,
    super.key,
  });

  @override
  State<DocsWidget> createState() => _DocsWidgetState();
}

class _DocsWidgetState extends State<DocsWidget> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final docs = widget.documentResponse;

    final title = docs.cleanedUpTitle ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(),
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
            data: docs.dartdoc ?? '',
            padding: const EdgeInsets.only(left: denseSpacing),
            onTapLink: _handleMarkdownTap,
          ),
        ),
      ],
    );
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

extension DocumentResponseExtension on DocumentResponse {
  String? get cleanedUpTitle {
    if (elementDescription == null) {
      return null;
    } else {
      // "(new) Text(\n  String data, {\n  Key? key,\n  ... selectionColor,\n})"
      var title = elementDescription!;

      // Remove ws right after method args.
      title = title.replaceAll('(\n  ', '(');

      // Remove ws before named args.
      title = title.replaceAll('{\n  ', '{');

      // Remove ws after named args.
      title = title.replaceAll(',\n}', '}');

      title = title.replaceAll('\n', '').replaceAll('  ', ' ');

      if (this.deprecated == true) {
        title = '$title (deprecated)';
      }

      return title;
    }
  }
}
