# Gemini Rules

This file contains rules and guidelines for the Gemini AI assistant to follow
when working on this project.

## About this project

This project is DartPad, an online editor for the Dart language.

### Project Structure

DartPad runs analysis and compilation in the browser. Its packages live in the
`pkgs/dartpad_preview` Dart workspace:

- `dartpad_frontend`: The Jaspr web app served at dartpad.dev.
- `dartpad_editor`: Editor, language-server, and workspace building blocks.
- `codemirror-dart`: Dart wrapper around the CodeMirror 6 editor.
- `codemirror-lang-dart`: Dart language support for CodeMirror 6.
- `examples`: Bundled example projects, loaded with the `sample=` query
  parameter.

## General principles

- **Be concise:** Provide terse and to-the-point answers and explanations.
- **Propose changes:** When asked to make changes, prefer creating a change
  request over asking for clarification if the intent is clear.
- **Verify changes:** After making changes, run tests to ensure that the changes
  are correct and don't introduce regressions.

## Coding style

- Follow the official
  [Dart style guide](https://dart.dev/guides/language/effective-dart/style).
- Keep lines under 120 characters.
- Add comments to explain complex or non-obvious code.

## Commit messages

- Use a clear and descriptive summary line.
- Include a more detailed description in the body of the commit message if
  necessary.

## Maintenance

- **Keep this file up-to-date:** If you detect that this file's description of
  the code organization no longer matches the structure on disk, please update
  it.
