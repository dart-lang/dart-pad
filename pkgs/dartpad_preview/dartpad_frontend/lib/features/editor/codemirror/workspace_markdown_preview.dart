// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of 'code_mirror_tab.dart';

/// The view shown for a workspace Markdown file.
enum MarkdownViewMode { source, preview }

/// Markdown presentation for workspace tabs, including paths renamed to Markdown.
mixin _WorkspaceMarkdownPreview on CodeMirrorTab {
  web.HTMLDivElement? _previewContainer;
  String? _renderedContent;
  // Remember the Markdown view choice across renames. This preference is not
  // the visible view: non-Markdown files always show source, as enforced below.
  MarkdownViewMode _preferredMarkdownViewMode = MarkdownViewMode.preview;

  // Only the CodeMirror input field is meant here. Preview keeps it alive but
  // hidden, so the shared lifecycle must not measure or save its hidden view.
  @override
  bool get _isEditorVisible => markdownViewMode == MarkdownViewMode.source;

  /// Whether the current path supports Markdown preview.
  bool get isMarkdown => isMarkdownFile(path);

  /// The actual view. Non-Markdown paths cannot enter preview mode.
  ///
  /// Markdown files initially open in preview, with the editor kept in memory.
  MarkdownViewMode get markdownViewMode => isMarkdown ? _preferredMarkdownViewMode : MarkdownViewMode.source;

  /// Switches Markdown display without recreating the editor.
  void setMarkdownViewMode(MarkdownViewMode mode) {
    if (!isMarkdown || _preferredMarkdownViewMode == mode) {
      return;
    }
    if (mode == MarkdownViewMode.preview) {
      _prepareEditorForHiding();
    }
    _preferredMarkdownViewMode = mode;
    if (mode == MarkdownViewMode.source) {
      _scheduleMeasureAndRestore();
    }
    _notifyUpdate();
  }

  @override
  void rename(String newPath) {
    // Changing the extension can change the actual view without changing the
    // remembered Markdown choice. Preserve the same editor across that switch.
    final wasPreview = markdownViewMode == MarkdownViewMode.preview;
    final willBePreview = isMarkdownFile(newPath) && _preferredMarkdownViewMode == MarkdownViewMode.preview;
    if (!wasPreview && willBePreview) {
      _prepareEditorForHiding();
    }
    super.rename(newPath);
    if (wasPreview && !willBePreview) {
      _scheduleMeasureAndRestore();
    }
  }

  Component _buildMarkdownView(Component source) {
    // Keep the source hierarchy stable when a rename changes the file type.
    // Otherwise Jaspr can reuse the externally managed CodeMirror container as
    // a new wrapper and try to insert the container into itself.
    final previewContainer = isMarkdown
        ? (_previewContainer ??= web.HTMLDivElement()
            ..className = 'markdown-preview'
            ..setAttribute('role', 'document')
            ..setAttribute('aria-label', 'Markdown preview')
            ..tabIndex = 0)
        : null;
    final showPreview = markdownViewMode == MarkdownViewMode.preview;
    if (showPreview && _renderedContent != content) {
      previewContainer!.innerHTML = renderMarkdown(content).toJS;
      _renderedContent = content;
    }
    return div(classes: 'workspace-text-tab', [
      div(
        classes: 'workspace-source${isMarkdown ? ' markdown-source' : ''}',
        attributes: {if (showPreview) 'hidden': ''},
        [source],
      ),
      if (previewContainer != null)
        div(
          classes: 'markdown-rendered',
          attributes: {if (!showPreview) 'hidden': ''},
          [NodeContainer(previewContainer)],
        ),
    ]);
  }
}
