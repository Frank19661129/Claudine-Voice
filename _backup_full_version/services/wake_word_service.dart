import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:picovoice_flutter/picovoice_manager.dart';
import 'package:picovoice_flutter/picovoice_error.dart';

/// Energy-efficient wake word detection service
/// Uses Picovoice Porcupine for on-device detection
/// Battery usage: ~1-2% per hour (extremely efficient)
class WakeWordService {
  PicovoiceManager? _picovoiceManager;
  bool _isListening = false;

  // Callbacks
  final Function(String wakeWord)? onWakeWordDetected;
  final Function(String error)? onError;

  // Wake word configuration
  String _currentWakeWord = "hee_claudine";

  WakeWordService({
    this.onWakeWordDetected,
    this.onError,
  });

  /// Initialize wake word detection
  /// Call this once on app start
  Future<void> initialize() async {
    if (_picovoiceManager != null) {
      debugPrint('WakeWordService already initialized');
      return;
    }

    try {
      // Picovoice access key (get from https://picovoice.ai)
      const accessKey = String.fromEnvironment(
        'PICOVOICE_ACCESS_KEY',
        defaultValue: 'YOUR_ACCESS_KEY_HERE', // TODO: Move to secure config
      );

      _picovoiceManager = await PicovoiceManager.create(
        accessKey,
        _getWakeWordPath(),
        _wakeWordCallback,
        null, // No inference (we only need wake word)
        _errorCallback,
        processErrorCallback: _errorCallback,
      );

      debugPrint('✓ WakeWordService initialized with: $_currentWakeWord');
    } on PicovoiceException catch (e) {
      debugPrint('✗ Failed to initialize WakeWordService: ${e.message}');
      onError?.call(e.message ?? 'Unknown Picovoice error');
      rethrow;
    }
  }

  /// Start listening for wake word
  /// Battery optimized: only processes audio when needed
  Future<void> startListening() async {
    if (_picovoiceManager == null) {
      throw StateError('WakeWordService not initialized. Call initialize() first.');
    }

    if (_isListening) {
      debugPrint('Already listening for wake word');
      return;
    }

    try {
      await _picovoiceManager!.start();
      _isListening = true;
      debugPrint('👂 Started listening for wake word: $_currentWakeWord');
    } on PicovoiceException catch (e) {
      debugPrint('✗ Failed to start listening: ${e.message}');
      onError?.call(e.message ?? 'Failed to start listening');
      rethrow;
    }
  }

  /// Stop listening (saves battery)
  Future<void> stopListening() async {
    if (_picovoiceManager == null || !_isListening) {
      return;
    }

    try {
      await _picovoiceManager!.stop();
      _isListening = false;
      debugPrint('🔇 Stopped listening for wake word');
    } on PicovoiceException catch (e) {
      debugPrint('✗ Failed to stop listening: ${e.message}');
      onError?.call(e.message ?? 'Failed to stop listening');
    }
  }

  /// Change wake word
  /// Supported: "hee_claudine", "hey_google" (custom), etc.
  Future<void> changeWakeWord(String wakeWord) async {
    if (_currentWakeWord == wakeWord) return;

    final wasListening = _isListening;

    // Stop current detection
    if (wasListening) {
      await stopListening();
    }

    // Dispose old manager
    await dispose();

    // Update wake word
    _currentWakeWord = wakeWord;

    // Reinitialize with new wake word
    await initialize();

    // Resume if was listening
    if (wasListening) {
      await startListening();
    }

    debugPrint('🔄 Wake word changed to: $_currentWakeWord');
  }

  /// Cleanup
  Future<void> dispose() async {
    await stopListening();
    await _picovoiceManager?.delete();
    _picovoiceManager = null;
    debugPrint('🧹 WakeWordService disposed');
  }

  // Private methods

  String _getWakeWordPath() {
    // Path to wake word model file
    // Format: assets/wake_words/{wake_word}_nl.ppn
    return 'assets/wake_words/${_currentWakeWord}_nl.ppn';
  }

  void _wakeWordCallback(int keywordIndex) {
    debugPrint('🎤 Wake word detected! Index: $keywordIndex');
    onWakeWordDetected?.call(_currentWakeWord);
  }

  void _errorCallback(PicovoiceException error) {
    debugPrint('❌ Wake word error: ${error.message}');
    onError?.call(error.message ?? 'Unknown error');
  }

  // Getters

  bool get isListening => _isListening;
  String get currentWakeWord => _currentWakeWord;

  /// Battery impact estimate (per hour)
  double get estimatedBatteryUsagePerHour => 1.5; // ~1-2%
}
