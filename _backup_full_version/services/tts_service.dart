import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Text-to-Speech service for natural voice output
/// Uses native TTS engines (highest quality, lowest latency)
class TTSService {
  final FlutterTts _tts = FlutterTts();
  bool _isInitialized = false;
  bool _isSpeaking = false;

  // Callbacks
  final Function()? onSpeechStarted;
  final Function()? onSpeechCompleted;
  final Function(String error)? onError;

  // Configuration
  String _language = 'nl-NL';
  double _pitch = 1.0;
  double _rate = 0.5; // Slightly slower for clarity
  double _volume = 1.0;

  TTSService({
    this.onSpeechStarted,
    this.onSpeechCompleted,
    this.onError,
  });

  /// Initialize TTS engine
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Set up callbacks
      _tts.setStartHandler(() {
        _isSpeaking = true;
        onSpeechStarted?.call();
        debugPrint('🔊 TTS started');
      });

      _tts.setCompletionHandler(() {
        _isSpeaking = false;
        onSpeechCompleted?.call();
        debugPrint('🔇 TTS completed');
      });

      _tts.setErrorHandler((msg) {
        _isSpeaking = false;
        onError?.call(msg);
        debugPrint('❌ TTS error: $msg');
      });

      // Configure TTS
      await _tts.setLanguage(_language);
      await _tts.setPitch(_pitch);
      await _tts.setSpeechRate(_rate);
      await _tts.setVolume(_volume);

      // iOS specific
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await _tts.setSharedInstance(true);
        await _tts.setIosAudioCategory(
          IosTextToSpeechAudioCategory.playback,
          [
            IosTextToSpeechAudioCategoryOptions.allowBluetooth,
            IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
            IosTextToSpeechAudioCategoryOptions.mixWithOthers,
          ],
          IosTextToSpeechAudioMode.voicePrompt,
        );
      }

      _isInitialized = true;
      debugPrint('✓ TTSService initialized (language: $_language)');
    } catch (e) {
      debugPrint('✗ TTSService initialization error: $e');
      onError?.call(e.toString());
      rethrow;
    }
  }

  /// Speak text
  /// For natural conversation, automatically handles sentence pauses
  Future<void> speak(String text) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (_isSpeaking) {
      await stop();
    }

    try {
      // Clean text for better TTS
      final cleanedText = _cleanTextForTTS(text);

      debugPrint('🗣️ Speaking: "$cleanedText"');
      await _tts.speak(cleanedText);
    } catch (e) {
      debugPrint('✗ TTS speak error: $e');
      onError?.call(e.toString());
    }
  }

  /// Stop current speech
  Future<void> stop() async {
    if (!_isSpeaking) return;

    try {
      await _tts.stop();
      _isSpeaking = false;
      debugPrint('⏹️ TTS stopped');
    } catch (e) {
      debugPrint('✗ TTS stop error: $e');
    }
  }

  /// Pause speech
  Future<void> pause() async {
    if (!_isSpeaking) return;

    try {
      await _tts.pause();
      debugPrint('⏸️ TTS paused');
    } catch (e) {
      debugPrint('✗ TTS pause error: $e');
    }
  }

  /// Change voice settings
  Future<void> setVoice({
    String? language,
    double? pitch,
    double? rate,
    double? volume,
  }) async {
    if (language != null && language != _language) {
      _language = language;
      await _tts.setLanguage(language);
    }

    if (pitch != null && pitch != _pitch) {
      _pitch = pitch;
      await _tts.setPitch(pitch);
    }

    if (rate != null && rate != _rate) {
      _rate = rate;
      await _tts.setSpeechRate(rate);
    }

    if (volume != null && volume != _volume) {
      _volume = volume;
      await _tts.setVolume(volume);
    }

    debugPrint('🔧 TTS settings updated');
  }

  /// Get available voices
  Future<List<dynamic>> getVoices() async {
    if (!_isInitialized) {
      await initialize();
    }
    return await _tts.getVoices;
  }

  /// Dispose resources
  Future<void> dispose() async {
    await stop();
    debugPrint('🧹 TTSService disposed');
  }

  // Private helpers

  String _cleanTextForTTS(String text) {
    // Remove markdown formatting
    String cleaned = text
        .replaceAll('**', '')
        .replaceAll('*', '')
        .replaceAll('_', '')
        .replaceAll('#', '');

    // Add pauses at sentence boundaries for natural speech
    cleaned = cleaned
        .replaceAll('. ', '. <break time="300ms"/> ')
        .replaceAll('? ', '? <break time="300ms"/> ')
        .replaceAll('! ', '! <break time="300ms"/> ');

    return cleaned;
  }

  // Getters

  bool get isInitialized => _isInitialized;
  bool get isSpeaking => _isSpeaking;
  String get currentLanguage => _language;
  double get currentPitch => _pitch;
  double get currentRate => _rate;
  double get currentVolume => _volume;
}
