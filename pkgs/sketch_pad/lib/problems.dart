// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'services/dart_services.pb.dart';
import 'theme.dart';

class ProblemsWidget extends StatelessWidget {
  final List<AnalysisIssue> problems;

  const ProblemsWidget({
    required this.problems,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    const lineHeight = 44.0;
    const rowPadding = 2.0;

    var height = 0.0;
    // ignore: prefer_is_empty
    if (problems.length > 0) {
      height = lineHeight * math.min(problems.length, 3) + 1 + denseSpacing * 2;
    }

    return AnimatedContainer(
      height: height,
      duration: animationDelay,
      curve: animationCurve,
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surfaceVariant,
          border: Border(top: Divider.createBorderSide(context, width: 1.0)),
        ),
        padding: const EdgeInsets.all(denseSpacing),
        child: ListView.builder(
          itemCount: problems.length,
          itemBuilder: (BuildContext context, int index) {
            final issue = problems[index];

            return Padding(
              padding: const EdgeInsets.only(bottom: rowPadding),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        issue.errorIcon,
                        size: smallIconSize,
                        color: issue.colorFor(
                            darkMode:
                                colorScheme.brightness == Brightness.dark),
                      ),
                      const SizedBox(width: denseSpacing),
                      Expanded(
                        child: Tooltip(
                          message: issue.message,
                          waitDuration: tooltipDelay,
                          child: Text(
                            issue.message,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            // style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ),
                      Text(
                        ' line ${issue.line}, col ${issue.column}',
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                        textAlign: TextAlign.end,
                        // style: theme.textTheme.bodyMedium,
                        style: subtleText,
                      )
                    ],
                  ),
                  if (issue.hasCorrection()) const SizedBox(height: rowPadding),
                  if (issue.hasCorrection())
                    Row(
                      // crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox.square(dimension: smallIconSize),
                        const SizedBox(width: denseSpacing),
                        Expanded(
                          child: Tooltip(
                            waitDuration: tooltipDelay,
                            message: issue.correction,
                            child: Text(
                              issue.correction,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              // style: theme.textTheme.bodyMedium,
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

extension AnalysisIssueExtension on AnalysisIssue {
  Color colorFor({bool darkMode = true}) {
    switch (kind) {
      case 'error':
        return darkMode ? Colors.red : Colors.red;
      case 'warning':
        return darkMode ? Colors.yellow : Colors.yellow;
      case 'info':
        return darkMode ? Colors.blue : Colors.blue.shade300;
      default:
        return darkMode ? Colors.grey : Colors.grey;
    }
  }

  IconData get errorIcon {
    switch (kind) {
      case 'error':
        return Icons.error_outline;
      case 'warning':
        return Icons.warning_outlined;
      case 'info':
        return Icons.info_outline;
      default:
        return Icons.error_outline;
    }
  }
}
