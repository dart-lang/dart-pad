# DartPad Frontend

Jaspr client-side UI for DartPad Preview: editor, file tree, execution preview,
and console panels.

| Path | Purpose |
| --- | --- |
| [lib/main.client.dart](lib/main.client.dart) | Browser entrypoint |
| [lib/app.dart](lib/app.dart) | App layout and component composition |
| [lib/app_styles.dart](lib/app_styles.dart) | Shared UI styles |
| [lib/features/](lib/features/) | Feature views, view models, and controllers |
| [test/](test/) | Chrome-based component and workflow tests |

- [Setup, commands, and embedding](../README.md)
- [Asset generation](doc/development.md)
- [Editor and language-server integration](../dartpad_editor/README.md)
