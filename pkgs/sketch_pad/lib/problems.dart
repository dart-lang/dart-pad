// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:math' as math;

import 'package:dartpad_shared/model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;

import 'model.dart';
import 'theme.dart';

const _rowPadding = 2.0;

class ProblemsTableWidget extends StatelessWidget {
  final List<AnalysisIssue> problems;

  const ProblemsTableWidget({
    required this.problems,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    const lineHeight = 44.0;
    const visibleIssues = 3;

    var height = 0.0;
    // ignore: prefer_is_empty
    if (problems.length > 0) {
      height = lineHeight * math.min(problems.length, visibleIssues) +
          1 +
          denseSpacing * 2;
    }

    return AnimatedContainer(
      height: height,
      duration: animationDelay,
      curve: animationCurve,
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
        ),
        padding: const EdgeInsets.all(denseSpacing),
        child: ListView.builder(
          itemCount: problems.length,
          itemBuilder: (BuildContext context, int index) {
            final issue = problems[index];
            return ProblemWidget(issue: issue);
          },
        ),
      ),
    );
  }
}

class ProblemWidget extends StatelessWidget {
  final MenuController _menuController = MenuController();
  final AnalysisIssue issue;

  ProblemWidget({
    required this.issue,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final widget = Padding(
      padding: const EdgeInsets.only(bottom: _rowPadding),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                issue.errorIcon,
                size: smallIconSize,
                color: issue.colorFor(
                    darkMode: colorScheme.brightness == Brightness.dark),
              ),
              const SizedBox(width: denseSpacing),
              Expanded(
                child: Text(
                  issue.message,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                ' line ${issue.location.line}, col ${issue.location.column}',
                maxLines: 1,
                overflow: TextOverflow.clip,
                textAlign: TextAlign.end,
                style: subtleText,
              )
            ],
          ),
          if (issue.correction != null) const SizedBox(height: _rowPadding),
          if (issue.correction != null)
            Row(
              children: [
                const SizedBox.square(dimension: smallIconSize),
                const SizedBox(width: denseSpacing),
                Expanded(
                  child: Text(
                    issue.correction!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
        ],
      ),
    );

    final appServices = Provider.of<AppServices>(context);
    final diagnosticDocUrl = issue.url;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        child: MenuAnchor(
          controller: _menuController,
          menuChildren: [
            MenuItemButton(
              child: const Text('Copy diagnostic message'),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: issue.message));
              },
            ),
            if (diagnosticDocUrl != null)
              MenuItemButton(
                child: const Text('View diagnostic documentation'),
                onPressed: () {
                  url_launcher.launchUrl(Uri.parse(diagnosticDocUrl));
                },
              ),
          ],
          child: widget,
        ),
        onTap: () {
          _menuController.close();
          appServices.editorService?.jumpTo(issue);
        },
        onSecondaryTapDown: (details) async {
          // On right click, disable browser context menu, and
          // show menu to copy diagnostic or view its docs.
          if (kIsWeb) {
            await BrowserContextMenu.disableContextMenu();
          }
          _menuController.open(position: details.localPosition);
          if (kIsWeb) {
            BrowserContextMenu.enableContextMenu();
          }
        },
      ),
    );
  }
}

extension AnalysisIssueExtension on AnalysisIssue {
  Color colorFor({bool darkMode = true}) => switch (kind) {
        'error' => darkMode ? darkErrorColor : lightErrorColor,
        'warning' => darkMode ? darkWarningColor : lightWarningColor,
        'info' => darkMode ? darkInfoColor : lightInfoColor,
        _ => darkMode ? darkIssueColor : lightIssueColor
      };

  IconData get errorIcon => switch (kind) {
        'error' => Icons.error_outline,
        'warning' => Icons.warning_outlined,
        'info' => Icons.info_outline,
        _ => Icons.error_outline
      };
}
