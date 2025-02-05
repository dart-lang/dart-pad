// This constant reads the dart-define passed at compile time.
// For example, you can build with:
// flutter build <target> --dart-define=GEN_AI_ENABLED=true
const bool genAiEnabled = bool.fromEnvironment(
  'GEN_AI_ENABLED',
  defaultValue: false,
);
