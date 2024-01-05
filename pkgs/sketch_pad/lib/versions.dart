// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dartpad_shared/services.dart';
import 'package:flutter/material.dart';
import 'package:vtable/vtable.dart';

import 'l10n/en.flutter.g.dart';
import 'theme.dart';

class VersionTable extends StatelessWidget {
  final VersionResponse version;

  const VersionTable({
    required this.version,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final packages = version.packages.where((p) => p.supported).toList();

    var versionText = context.messagesLocalizations!
        .basedOnDartAndFlutter(version.dartVersion, version.flutterVersion);
    final experiments = version.experiments.join(', ');
    if (experiments.isNotEmpty) {
      versionText +=
          '\n\n${context.messagesLocalizations!.experimentsEnabled(experiments)}';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(),
        Text(versionText),
        const Divider(),
        const SizedBox(height: denseSpacing),
        Expanded(
          child: VTable<PackageInfo>(
            showToolbar: false,
            items: packages,
            columns: [
              VTableColumn(
                label: context.messagesLocalizations!.package,
                width: 250,
                grow: 0.7,
                transformFunction: (p) => 'package:${p.name}',
              ),
              VTableColumn(
                label: context.messagesLocalizations!.version,
                width: 70,
                grow: 0.3,
                transformFunction: (p) => p.version,
                styleFunction: (p) => subtleText,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
