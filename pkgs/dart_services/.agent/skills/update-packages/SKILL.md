---
name: update-packages
description: >-
  Updates pinned package dependencies for Dart and Flutter project templates.
  Use when adding/removing packages from the allowlist or updating dependency
  versions across Flutter channels (main/beta/stable).
---

# Update Packages

## Step 1: Update allowlist (if needed)

If adding or removing packages, edit `lib/src/project_templates.dart` first.
This file contains the allowlist of supported packages. Skip this step if only
updating versions.

## Step 2: Update dependencies for each channel

Run the following for each channel (stable, beta, main):

```bash
flutter channel <CHANNEL>
flutter upgrade
dart tool/grind.dart update-pub-dependencies
```

## Step 3: Switch back to stable

```bash
flutter channel stable
```

## Step 4: Verify changes

Check `git status` and `git diff` to confirm the expected changes to
`tool/dependencies/pub_dependencies_stable.json`, `pub_dependencies_beta.json`,
and `pub_dependencies_main.json`.
