# Gemini Rules

This file contains rules and guidelines for the Gemini AI assistant to follow
when working on this project.

## About this project

This project is DartPad, an online editor for the Dart language.

### Project Structure

The DartPad project is a monorepo composed of several packages located in the
`pkgs` directory:

- `dart_services`: The backend service for DartPad.
  - `lib/server.dart`: The main entry point for the backend server.
  - `lib/src/`: Contains the implementation of the backend services.
- `dartpad_shared`: Shared code between the DartPad frontend and backend.
  - `lib/`: Contains data models, services, and other shared code.
- `dartpad_ui`: The frontend UI for DartPad.
  - `lib/main.dart`: The main entry point for the frontend application.
  - `lib/app/`: Contains the main application widgets and UI components.
  - `lib/model/`: Contains frontend-specific data models.
  - `lib/primitives/`: Contains low-level UI widgets and utilities.
- `samples`: Sample code snippets for DartPad.

## General principles

- **Be concise:** Provide terse and to-the-point answers and explanations.
- **Propose changes:** When asked to make changes, prefer creating a change
  request over asking for clarification if the intent is clear.
- **Verify changes:** After making changes, run tests to ensure that the changes
  are correct and don't introduce regressions.

## Coding style

- Follow the official
  [Dart style guide](https://dart.dev/guides/language/effective-dart/style).
- Keep lines under 80 characters.
- Add comments to explain complex or non-obvious code.

## Commit messages

- Use a clear and descriptive summary line.
- Include a more detailed description in the body of the commit message if
  necessary.

## Maintenance

- **Keep this file up-to-date:** If you detect that this file's description of
  the code organization no longer matches the structure on disk, please update
  it.
