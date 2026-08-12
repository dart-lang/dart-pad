// dart format off
// ignore_for_file: type=lint

// GENERATED FILE, DO NOT MODIFY
// Generated with jaspr_builder

import 'package:jaspr/client.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:file_selector_web/file_selector_web.dart' as _file_selector_web;
import 'package:pointer_interceptor_web/pointer_interceptor_web.dart'
    as _pointer_interceptor_web;
import 'package:url_launcher_web/url_launcher_web.dart' as _url_launcher_web;

/// Default [ClientOptions] for use with your Jaspr project.
///
/// Use this to initialize Jaspr **before** calling [runApp].
///
/// Example:
/// ```dart
/// import 'main.client.options.dart';
///
/// void main() {
///   Jaspr.initializeApp(
///     options: defaultClientOptions,
///   );
///
///   runApp(...);
/// }
/// ```
ClientOptions get defaultClientOptions => ClientOptions(
  initialize: () {
    final Registrar registrar = webPluginRegistrar;
    _file_selector_web.FileSelectorWeb.registerWith(registrar);
    _pointer_interceptor_web.PointerInterceptorWeb.registerWith(registrar);
    _url_launcher_web.UrlLauncherPlugin.registerWith(registrar);
    registrar.registerMessageHandler();
  },
);
