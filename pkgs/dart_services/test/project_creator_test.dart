// Copyright (c) 2021, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dart_services/src/project_creator.dart';
import 'package:dart_services/src/sdk.dart';
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

void main() => defineTests();

void defineTests() {
  final sdk = Sdk();

  final languageVersion = sdk.dartVersion;

  Future<ProjectCreator> projectCreator() async {
    final dependenciesFile = d.file('dependencies.json', '''
{
  "meta": "^1.7.0"
}
''');
    await dependenciesFile.create();
    final templatesPath = d.dir('project_templates');
    await templatesPath.create();
    return ProjectCreator(
      sdk,
      templatesPath.io.path,
      dartLanguageVersion: sdk.dartVersion,
      dependenciesFile: dependenciesFile.io,
      log: printOnFailure,
    );
  }

  group('project templates', () {
    group('dart', () {
      setUpAll(() async {
        await (await projectCreator()).buildDartProjectTemplate();
      });

      test('project directory is created', () async {
        await d.dir('project_templates', [
          d.dir('dart_project'),
        ]).validate();
      });

      test('pubspec is created', () async {
        await d.dir('project_templates', [
          d.dir('dart_project', [
            d.file(
              'pubspec.yaml',
              allOf([
                contains('sdk: ^$languageVersion'),
              ]),
            ),
          ]),
        ]).validate();
      });

      test('pub get creates pubspec.lock', () async {
        await d.dir('project_templates', [
          d.dir('dart_project', [d.file('pubspec.lock', isNotEmpty)]),
        ]).validate();
      });

      test('recommended lints are enabled', () async {
        await d.dir('project_templates', [
          d.dir('dart_project', [
            d.file(
              'analysis_options.yaml',
              matches('include: package:lints/recommended.yaml'),
            ),
          ]),
        ]).validate();
      });
    });

    group('flutter', () {
      setUpAll(() async {
        await (await projectCreator())
            .buildFlutterProjectTemplate(firebaseStyle: FirebaseStyle.none);
      });

      test('project directory is created', () async {
        await d.dir('project_templates', [
          d.dir('flutter_project'),
        ]).validate();
      });

      test('Flutter Web directories are created', () async {
        await d.dir('project_templates', [
          d.dir('flutter_project', [
            d.dir('lib'),
            d.dir('web', [d.file('index.html', isEmpty)]),
          ])
        ]).validate();
      });

      test('pubspec is created', () async {
        await d.dir('project_templates', [
          d.dir('flutter_project', [
            d.file(
              'pubspec.yaml',
              allOf([
                contains('sdk: ^$languageVersion'),
                matches('sdk: flutter'),
              ]),
            ),
          ]),
        ]).validate();
      });

      test('pub get creates pubspec.lock', () async {
        await d.dir('project_templates', [
          d.dir('flutter_project', [d.file('pubspec.lock', isNotEmpty)]),
        ]).validate();
      });

      test('flutter lints are enabled', () async {
        await d.dir('project_templates', [
          d.dir('flutter_project', [
            d.file(
              'analysis_options.yaml',
              matches('include: package:flutter_lints/flutter.yaml'),
            ),
          ]),
        ]).validate();
      });

      test('plugins are registered', () async {
        await d.dir('project_templates', [
          d.dir('flutter_project/lib', [
            d.file(
              'generated_plugin_registrant.dart',
              matches('FirebaseCoreWeb.registerWith'),
            ),
          ]),
        ]).validate();
      });
    });

    group('firebase', () {
      setUpAll(() async {
        await (await projectCreator()).buildFlutterProjectTemplate(
            firebaseStyle: FirebaseStyle.flutterFire);
      });

      test('project directory is created', () async {
        await d.dir('project_templates', [
          d.dir('firebase_project'),
        ]).validate();
      });

      test('Flutter Web directories are created', () async {
        await d.dir('project_templates', [
          d.dir('firebase_project', [
            d.dir('lib'),
            d.dir('web', [d.file('index.html', isEmpty)]),
          ])
        ]).validate();
      });

      test('pubspec is created', () async {
        await d.dir('project_templates', [
          d.dir('firebase_project', [
            d.file(
              'pubspec.yaml',
              allOf([
                contains('sdk: ^$languageVersion'),
                matches('sdk: flutter'),
              ]),
            ),
          ]),
        ]).validate();
      });

      test('pub get creates pubspec.lock', () async {
        await d.dir('project_templates', [
          d.dir('firebase_project', [d.file('pubspec.lock', isNotEmpty)]),
        ]).validate();
      });

      test('flutter lints are enabled', () async {
        await d.dir('project_templates', [
          d.dir('firebase_project', [
            d.file(
              'analysis_options.yaml',
              matches('include: package:flutter_lints/flutter.yaml'),
            ),
          ]),
        ]).validate();
      });

      test('generated_plugin_registrant.dart is created', () async {
        await d.dir('project_templates', [
          d.dir('firebase_project', [
            d.dir('lib', [
              d.file(
                'generated_plugin_registrant.dart',
                isNotEmpty,
              ),
            ]),
          ]),
        ]).validate();
      });

      test('plugins are registered', () async {
        await d.dir('project_templates', [
          d.dir('firebase_project', [
            d.dir('lib', [
              d.file(
                'generated_plugin_registrant.dart',
                allOf([
                  matches('FirebaseFirestoreWeb.registerWith'),
                  matches('FirebaseAnalyticsWeb.registerWith'),
                  matches('FirebaseCoreWeb.registerWith'),
                  matches('FirebaseDatabaseWeb.registerWith'),
                  matches('FirebaseMessagingWeb.registerWith'),
                  matches('FirebaseStorageWeb.registerWith'),
                ]),
              ),
            ]),
          ]),
        ]).validate();
      });
    });
  });
}
