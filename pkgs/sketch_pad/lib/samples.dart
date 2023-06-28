// Copyright 2023 the Dart project authors. All rights reserved.
// Use of this source code is governed by a BSD-style license
// that can be found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart' as url;

import 'main.dart';
import 'samples.g.dart';
import 'utils.dart';

class SamplesDrawer extends StatelessWidget {
  const SamplesDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    var categories = Samples.categories.keys;

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          ListTile(
            title: const Text(appName),
            titleTextStyle: theme.textTheme.titleLarge,
          ),
          for (var category in categories) ...[
            const Divider(),
            ListTile(title: Text('$category samples')),
            ...Samples.categories[category]!.map((sample) {
              return SampleListTile(
                image: sample.isDart ? dartLogo() : flutterLogo(),
                name: sample.name,
                id: sample.id,
              );
            })
          ],
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('Privacy notice'),
            trailing: const Icon(Icons.link),
            onTap: () {
              Navigator.pop(context);
              url.launchUrl(
                  Uri.parse('https://dart.dev/tools/dartpad/privacy'));
            },
          ),
          ListTile(
            leading: const Icon(Icons.feedback),
            title: const Text('Feedback'),
            trailing: const Icon(Icons.link),
            onTap: () {
              Navigator.pop(context);
              url.launchUrl(
                  Uri.parse('https://github.com/dart-lang/dart-pad/issues'));
            },
          ),
        ],
      ),
    );
  }
}

class SampleListTile extends StatelessWidget {
  final Image image;
  final String name;
  final String id;

  const SampleListTile({
    required this.image,
    required this.name,
    required this.id,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final uri = Uri(path: '/', queryParameters: {'sample': id});

    return ListTile(
      leading: image,
      title: Text(name),
      onTap: () {
        Navigator.pop(context);
        context.push(uri.toString());
      },
    );
  }
}
