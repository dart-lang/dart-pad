---
name: update-packages
description: Updates pinned package dependencies for Dart and Flutter project templates. Use when adding/removing packages from the allowlist or updating dependency versions across Flutter channels (main/beta/stable).
---

# Update Packages

## Checklist

Copy this checklist and track your progress:

```
Dependency Update Progress:
- [ ] Step 1: Update allowlist (if adding/removing packages)
- [ ] Step 2: Update Stable channel
- [ ] Step 3: Update Beta channel
- [ ] Step 4: Update Main channel
```

## Step 1: Update allowlist

If adding or removing packages, edit `lib/src/project_templates.dart` first. This file contains the allowlist of supported packages. Skip this step if only updating versions.

## Channel Update Process

/!\ Repeat these steps for **each** channel (stable, beta, main) /!\

### 1. Switch channel

```bash
flutter channel <CHANNEL>
flutter upgrade
```

### 2. Build templates

```bash
dart tool/grind.dart build-project-templates
```

> [!NOTE]
> If this fails due to resolution errors:
> 1. Read the error message to identify the conflict.
> 2. Edit `tool/dependencies/pub_dependencies_<CHANNEL>.json` to fix the version.
> 3. Retry the build command.

### 3. Upgrade packages

Navigate to the generated project templates and upgrade dependencies:

```bash
cd project_templates/dart_project && flutter pub upgrade && cd ../..
cd project_templates/flutter_project && flutter pub upgrade && cd ../..
```

### 4. Pin dependencies

Overwrite the `pub_dependencies_<CHANNEL>.json` file with the resolved versions:

```bash
dart tool/grind.dart update-pub-dependencies
```
