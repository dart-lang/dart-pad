// dart format off
// ignore_for_file: type=lint

// GENERATED FILE, DO NOT MODIFY
// Generated with jaspr_builder

import 'package:jaspr/client.dart';

import 'package:jaspr_content/components/_internal/code_block_copy_button.dart'
    deferred as _code_block_copy_button;
import 'package:jaspr_content/components/_internal/tab_bar.dart'
    deferred as _tab_bar;
import 'package:jaspr_content/components/_internal/zoomable_image.dart'
    deferred as _zoomable_image;
import 'package:jaspr_content/components/github_button.dart'
    deferred as _github_button;
import 'package:jaspr_content/components/sidebar_toggle_button.dart'
    deferred as _sidebar_toggle_button;
import 'package:jaspr_content/components/theme_toggle.dart'
    deferred as _theme_toggle;

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
  clients: {
    'jaspr_content:code_block_copy_button': ClientLoader(
      (p) => _code_block_copy_button.CodeBlockCopyButton(),
      loader: _code_block_copy_button.loadLibrary,
    ),
    'jaspr_content:tab_bar': ClientLoader(
      (p) => _tab_bar.TabBar(
        initialValue: p['initialValue'] as String,
        items: (p['items'] as Map<String, Object?>).cast<String, String>(),
      ),
      loader: _tab_bar.loadLibrary,
    ),
    'jaspr_content:zoomable_image': ClientLoader(
      (p) => _zoomable_image.ZoomableImage(
        src: p['src'] as String,
        alt: p['alt'] as String?,
        caption: p['caption'] as String?,
      ),
      loader: _zoomable_image.loadLibrary,
    ),
    'jaspr_content:github_button': ClientLoader(
      (p) => _github_button.GitHubButton(repo: p['repo'] as String),
      loader: _github_button.loadLibrary,
    ),
    'jaspr_content:sidebar_toggle_button': ClientLoader(
      (p) => _sidebar_toggle_button.SidebarToggleButton(),
      loader: _sidebar_toggle_button.loadLibrary,
    ),
    'jaspr_content:theme_toggle': ClientLoader(
      (p) => _theme_toggle.ThemeToggle(),
      loader: _theme_toggle.loadLibrary,
    ),
  },
);
