import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/wake_word_service.dart';
import '../services/speech_service.dart';
import '../services/claude_service.dart';
import '../services/tts_service.dart';

/// Main voice assistant screen
/// ChatGPT Voice-like experience with visual feedback
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  // Services
  late WakeWordService _wakeWordService;
  late SpeechService _speechService;
  late ClaudeService _claudeService;
  late TTSService _ttsService;

  // State
  VoiceState _voiceState = VoiceState.idle;
  String _currentText = '';
  String _lastResponse = '';
  bool _isWakeWordActive = true;

  // Animation
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _setupAnimation();
  }

  Future<void> _initializeServices() async {
    // Initialize wake word
    _wakeWordService = WakeWordService(
      onWakeWordDetected: _onWakeWordDetected,
      onError: _onError,
    );

    // Initialize speech recognition
    _speechService = SpeechService(
      onResult: _onSpeechResult,
      onError: _onError,
      onListeningStarted: () => setState(() => _voiceState = VoiceState.listening),
      onListeningStopped: () => setState(() => _voiceState = VoiceState.idle),
    );

    // Initialize Claude
    const apiKey = String.fromEnvironment(
      'CLAUDE_API_KEY',
      defaultValue: 'YOUR_API_KEY_HERE',
    );
    _claudeService = ClaudeService(apiKey);

    // Initialize TTS
    _ttsService = TTSService(
      onSpeechStarted: () => setState(() => _voiceState = VoiceState.speaking),
      onSpeechCompleted: () {
        setState(() => _voiceState = VoiceState.idle);
        if (_isWakeWordActive) {
          _startWakeWordListening();
        }
      },
      onError: _onError,
    );

    // Initialize all services
    await _wakeWordService.initialize();
    await _speechService.initialize();
    await _ttsService.initialize();

    // Start listening for wake word
    await _startWakeWordListening();
  }

  void _setupAnimation() {
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  Future<void> _startWakeWordListening() async {
    if (_isWakeWordActive) {
      await _wakeWordService.startListening();
      setState(() => _voiceState = VoiceState.idle);
    }
  }

  void _onWakeWordDetected(String wakeWord) {
    debugPrint('🎤 Wake word detected: $wakeWord');
    setState(() => _voiceState = VoiceState.wakeWordDetected);

    // Stop wake word detection
    _wakeWordService.stopListening();

    // Start listening for command
    Future.delayed(const Duration(milliseconds: 500), () {
      _speechService.startListening();
    });
  }

  void _onSpeechResult(String text, bool isFinal) {
    setState(() => _currentText = text);

    if (isFinal) {
      _processUserInput(text);
    }
  }

  Future<void> _processUserInput(String text) async {
    setState(() => _voiceState = VoiceState.processing);

    try {
      // Get response from Claude
      final response = await _claudeService.sendMessage(text);

      setState(() {
        _lastResponse = response;
        _voiceState = VoiceState.speaking;
      });

      // Speak response
      await _ttsService.speak(response);
    } catch (e) {
      _onError('Failed to process: $e');
    }
  }

  void _onError(String error) {
    debugPrint('❌ Error: $error');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _wakeWordService.dispose();
    _speechService.dispose();
    _ttsService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _getGradientColors(),
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              const Spacer(),
              _buildVoiceVisualizer(),
              const SizedBox(height: 32),
              _buildStatusText(),
              const Spacer(),
              _buildControls(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Claudine',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
          ),
          IconButton(
            icon: Icon(
              _isWakeWordActive ? Icons.mic : Icons.mic_off,
              color: Colors.white,
            ),
            onPressed: () {
              setState(() => _isWakeWordActive = !_isWakeWordActive);
              if (_isWakeWordActive) {
                _startWakeWordListening();
              } else {
                _wakeWordService.stopListening();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceVisualizer() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final scale = _voiceState == VoiceState.listening
            ? 1.0 + (_pulseController.value * 0.2)
            : 1.0;

        return Transform.scale(
          scale: scale,
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _getVisualizerColor(),
              boxShadow: [
                BoxShadow(
                  color: _getVisualizerColor().withOpacity(0.5),
                  blurRadius: 40,
                  spreadRadius: _voiceState == VoiceState.listening ? 20 : 0,
                ),
              ],
            ),
            child: Icon(
              _getVisualizerIcon(),
              size: 80,
              color: Colors.white,
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusText() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0),
      child: Column(
        children: [
          Text(
            _getStatusTitle(),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          if (_currentText.isNotEmpty || _lastResponse.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                _getCurrentDisplayText(),
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.white,
                    ),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (_voiceState == VoiceState.listening ||
            _voiceState == VoiceState.speaking)
          FloatingActionButton(
            onPressed: () {
              if (_voiceState == VoiceState.listening) {
                _speechService.stopListening();
              } else if (_voiceState == VoiceState.speaking) {
                _ttsService.stop();
              }
            },
            backgroundColor: Colors.red,
            child: const Icon(Icons.stop),
          )
        else if (_voiceState == VoiceState.idle)
          FloatingActionButton(
            onPressed: () => _speechService.startListening(),
            backgroundColor: Colors.white,
            child: const Icon(Icons.mic, color: Colors.blue),
          ),
      ],
    );
  }

  // Helper methods

  List<Color> _getGradientColors() {
    switch (_voiceState) {
      case VoiceState.idle:
        return [Colors.blue.shade400, Colors.blue.shade700];
      case VoiceState.wakeWordDetected:
      case VoiceState.listening:
        return [Colors.purple.shade400, Colors.purple.shade700];
      case VoiceState.processing:
        return [Colors.orange.shade400, Colors.orange.shade700];
      case VoiceState.speaking:
        return [Colors.green.shade400, Colors.green.shade700];
    }
  }

  Color _getVisualizerColor() {
    switch (_voiceState) {
      case VoiceState.idle:
        return Colors.white.withOpacity(0.3);
      case VoiceState.wakeWordDetected:
      case VoiceState.listening:
        return Colors.purple.shade300;
      case VoiceState.processing:
        return Colors.orange.shade300;
      case VoiceState.speaking:
        return Colors.green.shade300;
    }
  }

  IconData _getVisualizerIcon() {
    switch (_voiceState) {
      case VoiceState.idle:
        return Icons.mic_none;
      case VoiceState.wakeWordDetected:
      case VoiceState.listening:
        return Icons.mic;
      case VoiceState.processing:
        return Icons.hourglass_bottom;
      case VoiceState.speaking:
        return Icons.volume_up;
    }
  }

  String _getStatusTitle() {
    switch (_voiceState) {
      case VoiceState.idle:
        return _isWakeWordActive
            ? 'Zeg "Hee Claudine" om te beginnen'
            : 'Tik op de microfoon om te beginnen';
      case VoiceState.wakeWordDetected:
        return 'Ja, ik luister...';
      case VoiceState.listening:
        return 'Ik luister...';
      case VoiceState.processing:
        return 'Even denken...';
      case VoiceState.speaking:
        return 'Claudine spreekt...';
    }
  }

  String _getCurrentDisplayText() {
    if (_voiceState == VoiceState.listening && _currentText.isNotEmpty) {
      return _currentText;
    } else if (_voiceState == VoiceState.speaking ||
        _voiceState == VoiceState.idle && _lastResponse.isNotEmpty) {
      return _lastResponse;
    }
    return '';
  }
}

enum VoiceState {
  idle,
  wakeWordDetected,
  listening,
  processing,
  speaking,
}
