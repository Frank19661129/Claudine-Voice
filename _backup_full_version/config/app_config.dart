/// Application configuration
/// Centralized config for API keys, settings, etc.
class AppConfig {
  // API Keys (from environment or fallback)
  static const String claudeApiKey = String.fromEnvironment(
    'CLAUDE_API_KEY',
    defaultValue: '', // Must be set via --dart-define
  );

  static const String picovoiceAccessKey = String.fromEnvironment(
    'PICOVOICE_ACCESS_KEY',
    defaultValue: '', // Must be set via --dart-define
  );

  // API Endpoints
  static const String claudeBaseUrl = 'https://api.anthropic.com/v1';
  static const String claudeModel = 'claude-3-5-sonnet-20241022';

  // Wake Word Settings
  static const String defaultWakeWord = 'hee_claudine';
  static const String wakeWordModelPath = 'assets/wake_words/hee_claudine_nl.ppn';

  // Speech Settings
  static const String defaultLocale = 'nl_NL'; // Dutch
  static const Duration speechPauseThreshold = Duration(seconds: 2);
  static const Duration speechTimeout = Duration(seconds: 30);

  // TTS Settings
  static const double defaultPitch = 1.0;
  static const double defaultSpeechRate = 0.5; // Slightly slower for clarity
  static const double defaultVolume = 1.0;

  // Battery Optimization
  static const int lowBatteryThreshold = 20; // Disable wake word below 20%
  static const int mediumBatteryThreshold = 50; // Reduce features below 50%

  // Conversation Settings
  static const int maxConversationHistory = 10; // Keep last 10 exchanges
  static const int maxResponseTokens = 150; // Short responses for voice

  // UI Settings
  static const Duration animationDuration = Duration(milliseconds: 300);
  static const Duration pulseAnimationDuration = Duration(milliseconds: 1500);

  // Feature Flags (for development)
  static const bool enableStreamingResponses = false; // Future feature
  static const bool enableConversationHistory = true;
  static const bool enableHapticFeedback = true;
  static const bool enableSoundEffects = true;

  // Validation
  static bool get isClaudeApiKeySet => claudeApiKey.isNotEmpty;
  static bool get isPicovoiceKeySet => picovoiceAccessKey.isNotEmpty;
  static bool get isFullyConfigured => isClaudeApiKeySet && isPicovoiceKeySet;
}
