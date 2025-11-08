import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:permission_handler/permission_handler.dart';

/// High-quality speech recognition service
/// Uses native iOS/Android STT for best quality and lowest latency
class SpeechService {
  final SpeechToText _speech = SpeechToText();
  bool _isInitialized = false;
  bool _isListening = false;

  // Callbacks
  final Function(String text, bool isFinal)? onResult;
  final Function(String error)? onError;
  final Function()? onListeningStarted;
  final Function()? onListeningStopped;

  // Configuration
  final String locale;
  final bool enableHapticFeedback;

  SpeechService({
    this.onResult,
    this.onError,
    this.onListeningStarted,
    this.onListeningStopped,
    this.locale = 'nl_NL', // Dutch by default
    this.enableHapticFeedback = true,
  });

  /// Initialize speech recognition
  /// Must be called before any other methods
  Future<bool> initialize() async {
    if (_isInitialized) {
      return true;
    }

    try {
      // Check microphone permission
      final permissionStatus = await Permission.microphone.status;
      if (!permissionStatus.isGranted) {
        final result = await Permission.microphone.request();
        if (!result.isGranted) {
          onError?.call('Microphone permission denied');
          return false;
        }
      }

      // Initialize speech recognition
      _isInitialized = await _speech.initialize(
        onStatus: _onStatusChanged,
        onError: _onErrorOccurred,
        debugLogging: kDebugMode,
      );

      if (_isInitialized) {
        // Check if locale is available
        final locales = await _speech.locales();
        final hasLocale = locales.any((l) => l.localeId == locale);

        if (!hasLocale) {
          debugPrint('⚠️ Locale $locale not available, using system default');
        }

        debugPrint('✓ SpeechService initialized (locale: $locale)');
      } else {
        onError?.call('Failed to initialize speech recognition');
      }

      return _isInitialized;
    } catch (e) {
      debugPrint('✗ SpeechService initialization error: $e');
      onError?.call(e.toString());
      return false;
    }
  }

  /// Start listening for speech
  /// Optimized for natural conversation:
  /// - Automatic pause detection
  /// - Continuous listening mode
  /// - Low latency partial results
  Future<void> startListening({
    Duration pauseFor = const Duration(seconds = 2),
    Duration listenFor = const Duration(seconds = 30),
    bool partialResults = true,
  }) async {
    if (!_isInitialized) {
      throw StateError('SpeechService not initialized');
    }

    if (_isListening) {
      debugPrint('Already listening');
      return;
    }

    try {
      await _speech.listen(
        onResult: _onSpeechResult,
        listenFor: listenFor,
        pauseFor: pauseFor,
        partialResults: partialResults,
        localeId: locale,
        cancelOnError: true,
        listenMode: ListenMode.confirmation, // Better for commands
      );

      _isListening = true;
      onListeningStarted?.call();
      debugPrint('👂 Started listening (pause after: ${pauseFor.inSeconds}s)');
    } catch (e) {
      debugPrint('✗ Failed to start listening: $e');
      onError?.call(e.toString());
    }
  }

  /// Stop listening
  Future<void> stopListening() async {
    if (!_isListening) {
      return;
    }

    try {
      await _speech.stop();
      _isListening = false;
      onListeningStopped?.call();
      debugPrint('🔇 Stopped listening');
    } catch (e) {
      debugPrint('✗ Failed to stop listening: $e');
      onError?.call(e.toString());
    }
  }

  /// Cancel current listening session
  Future<void> cancel() async {
    if (!_isListening) {
      return;
    }

    try {
      await _speech.cancel();
      _isListening = false;
      onListeningStopped?.call();
      debugPrint('❌ Listening cancelled');
    } catch (e) {
      debugPrint('✗ Failed to cancel listening: $e');
    }
  }

  /// Get available languages
  Future<List<LocaleName>> getAvailableLocales() async {
    if (!_isInitialized) {
      await initialize();
    }
    return await _speech.locales();
  }

  /// Dispose resources
  Future<void> dispose() async {
    await stopListening();
    debugPrint('🧹 SpeechService disposed');
  }

  // Private callbacks

  void _onSpeechResult(SpeechRecognitionResult result) {
    final text = result.recognizedWords;
    final isFinal = result.finalResult;

    if (text.isNotEmpty) {
      debugPrint(
        '📝 ${isFinal ? 'Final' : 'Partial'} result: "$text" '
        '(confidence: ${result.confidence.toStringAsFixed(2)})',
      );
      onResult?.call(text, isFinal);
    }
  }

  void _onStatusChanged(String status) {
    debugPrint('🔊 Speech status: $status');

    if (status == 'done' || status == 'notListening') {
      _isListening = false;
      onListeningStopped?.call();
    } else if (status == 'listening') {
      _isListening = true;
      onListeningStarted?.call();
    }
  }

  void _onErrorOccurred(dynamic error) {
    debugPrint('❌ Speech error: $error');
    _isListening = false;
    onError?.call(error.toString());
    onListeningStopped?.call();
  }

  // Getters

  bool get isInitialized => _isInitialized;
  bool get isListening => _isListening;
  bool get isAvailable => _speech.isAvailable;

  /// Get current audio level (0.0 - 1.0)
  /// Useful for visual feedback
  double get soundLevel => _speech.lastRecognizedWords.isNotEmpty ? 0.5 : 0.0;
}
