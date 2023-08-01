// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:vtable/vtable.dart';

import 'src/protos/dart_services.pbserver.dart';
import 'theme.dart';

class VersionTable extends StatelessWidget {
  final VersionResponse versions;

  const VersionTable({
    required this.versions,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final packages = versions.packageInfo.where((p) => p.supported).toList();

    var versionText = 'Based on Dart SDK ${versions.sdkVersionFull} '
        'and Flutter SDK ${versions.flutterVersion}.';
    final experiments = versions.experiment.join(', ');
    if (experiments.isNotEmpty) {
      versionText += '\n\nEnabled experiments: $experiments.';
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
                label: 'Package',
                width: 250,
                grow: 0.7,
                transformFunction: (p) => 'package:${p.name}',
              ),
              VTableColumn(
                label: 'Version',
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
