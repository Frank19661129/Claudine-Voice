import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  // Load environment variables
  await dotenv.load(fileName: ".env");

  runApp(
    const ProviderScope(
      child: ClaudineVoiceMVP(),
    ),
  );
}

class ClaudineVoiceMVP extends StatelessWidget {
  const ClaudineVoiceMVP({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Claudine Voice MVP',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const VoiceScreen(),
    );
  }
}

class VoiceScreen extends StatefulWidget {
  const VoiceScreen({super.key});

  @override
  State<VoiceScreen> createState() => _VoiceScreenState();
}

class _VoiceScreenState extends State<VoiceScreen>
    with SingleTickerProviderStateMixin {
  // API Keys - loaded from .env file
  static final String _claudeApiKey = dotenv.env['CLAUDE_API_KEY'] ?? '';

  // Google Cloud TTS API Key - loaded from .env file
  static final String _googleTtsApiKey = dotenv.env['GOOGLE_TTS_API_KEY'] ?? '';

  // Services
  final SpeechToText _speech = SpeechToText();
  final FlutterTts _tts = FlutterTts();
  final AudioPlayer _audioPlayer = AudioPlayer();

  // State
  VoiceState _state = VoiceState.idle;
  String _currentText = '';
  String _lastResponse = '';
  bool _isInitialized = false;
  String _currentLocale = 'nl-NL';  // Track current language
  String _versionInfo = '';  // Version + build number

  // Conversation history
  final List<Map<String, String>> _history = [];

  // Animation
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _loadVersion();
    _initialize();
    _setupAnimation();
  }

  Future<void> _loadVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _versionInfo = 'v${packageInfo.version}+${packageInfo.buildNumber}';
    });
  }

  Future<void> _initialize() async {
    // Request microphone permission
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      _showError('Microphone permission required');
      return;
    }

    // Initialize speech
    _isInitialized = await _speech.initialize(
      onStatus: (status) {
        debugPrint('Speech status: $status');
        // Auto-reset to idle when speech is done
        if (status == 'done' || status == 'notListening') {
          if (_state == VoiceState.listening) {
            setState(() => _state = VoiceState.idle);
          }
        }
      },
      onError: (error) {
        debugPrint('Speech error: $error');
        // Any error during listening -> go back to idle
        setState(() => _state = VoiceState.idle);
      },
    );

    if (_isInitialized) {
      // Check available speech locales
      final locales = await _speech.locales();
      debugPrint('📋 Available speech locales: ${locales.map((l) => l.localeId).take(5).toList()}...');

      if (locales.any((l) => l.localeId.startsWith('nl'))) {
        _currentLocale = 'nl-NL';
        debugPrint('✓ Using Dutch (nl-NL)');
      } else {
        _currentLocale = 'en-US';
        debugPrint('⚠️ Dutch not available, using English (en-US)');
        _showMessage('Dutch not available - using English');
      }
    }

    // Force Google TTS engine on Android
    try {
      // Try to get available engines
      final engines = await _tts.getEngines;
      debugPrint('📢 Available TTS engines: $engines');

      // Try to set Google TTS engine
      if (engines != null && engines.isNotEmpty) {
        // Look for Google TTS
        final googleEngine = engines.firstWhere(
          (engine) => engine.toLowerCase().contains('google'),
          orElse: () => engines.first,
        );
        debugPrint('🎯 Setting TTS engine to: $googleEngine');
        await _tts.setEngine(googleEngine);
      }
    } catch (e) {
      debugPrint('⚠️ Could not set TTS engine: $e');
    }

    // Initialize TTS with detected language
    await _tts.setLanguage(_currentLocale);
    await _tts.setPitch(1.0);
    await _tts.setSpeechRate(0.5);  // 0.5 = normal speed for Google
    await _tts.setVolume(1.0);

    // Android-specific: Request audio focus to prevent clipping
    await _tts.awaitSpeakCompletion(true);

    // Critical: Warm up the TTS engine by speaking something
    // This prevents clipping on the first real speech
    debugPrint('🔥 Warming up TTS engine...');
    await _tts.speak('test');  // Speak a test word
    await Future.delayed(const Duration(milliseconds: 1000));
    debugPrint('✓ TTS engine ready');

    _tts.setStartHandler(() {
      debugPrint('🔊 TTS started');
      setState(() => _state = VoiceState.speaking);
    });

    _tts.setCompletionHandler(() {
      debugPrint('🔇 TTS completed');
      setState(() => _state = VoiceState.idle);
    });

    if (_isInitialized) {
      debugPrint('✓ Claudine Voice MVP ready');
      _showMessage('Tap the microphone to start');
    }
  }

  void _setupAnimation() {
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  Future<void> _startListening() async {
    if (!_isInitialized) {
      _showError('Not initialized yet');
      return;
    }

    if (_state == VoiceState.listening) {
      return;
    }

    setState(() {
      _state = VoiceState.listening;
      _currentText = '';
    });

    debugPrint('🎤 Starting to listen in $_currentLocale...');

    try {
      await _speech.listen(
        onResult: (result) {
          setState(() => _currentText = result.recognizedWords);

          if (result.finalResult) {
            _processInput(result.recognizedWords);
          }
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 2),
        partialResults: true,
        localeId: _currentLocale,
      );
    } catch (e) {
      debugPrint('Listen error: $e');
      setState(() => _state = VoiceState.idle);
    }
  }

  Future<void> _stopListening() async {
    await _speech.stop();
    setState(() => _state = VoiceState.idle);
  }

  Future<void> _processInput(String text) async {
    if (text.isEmpty) return;

    setState(() => _state = VoiceState.processing);

    try {
      // Add to history
      _history.add({'role': 'user', 'content': text});

      // Keep last 10 exchanges
      if (_history.length > 20) {
        _history.removeRange(0, 2);
      }

      debugPrint('🤖 Calling Claude API...');
      debugPrint('Messages: $_history');

      // Adjust system prompt based on language
      final systemPrompt = _currentLocale.startsWith('nl')
          ? '''Je bent Claudine, een vriendelijke persoonlijke assistent.
Spreek Nederlands. Houd antwoorden kort (max 2-3 zinnen).
Dit is een spraak conversatie.'''
          : '''You are Claudine, a friendly personal assistant.
Speak in English. Keep answers short (max 2-3 sentences).
This is a voice conversation.''';

      // Call Claude API - try multiple models with fallback
      final models = [
        'claude-3-5-sonnet-20240620',  // Try this first
        'claude-3-sonnet-20240229',     // Fallback to Claude 3
        'claude-3-haiku-20240307',      // Last resort (cheapest)
      ];

      http.Response? response;
      String? usedModel;

      for (final model in models) {
        final requestBody = {
          'model': model,
          'max_tokens': 150,
          'system': systemPrompt,
          'messages': _history,
        };

        debugPrint('🤖 Trying model: $model');

        response = await http.post(
          Uri.parse('https://api.anthropic.com/v1/messages'),
          headers: {
            'Content-Type': 'application/json',
            'x-api-key': _claudeApiKey,
            'anthropic-version': '2023-06-01',
          },
          body: jsonEncode(requestBody),
        );

        if (response.statusCode == 200) {
          usedModel = model;
          debugPrint('✓ Success with model: $model');
          break;
        } else if (response.statusCode == 404) {
          debugPrint('⚠️ Model $model not found, trying next...');
          continue;
        } else {
          // Other error, don't retry
          break;
        }
      }

      if (response == null || response.statusCode != 200) {
        final statusCode = response?.statusCode ?? 'unknown';
        final body = response?.body ?? 'No response';
        debugPrint('❌ Claude API Error $statusCode');
        debugPrint('Response: $body');
        throw Exception('API error: $statusCode\n$body');
      }

      final data = jsonDecode(response.body);
      debugPrint('✓ Claude response with model: $usedModel');
      final answer = data['content'][0]['text'] as String;

      // Add to history
      _history.add({'role': 'assistant', 'content': answer});

      setState(() {
        _lastResponse = answer;
        _state = VoiceState.speaking;
      });

      debugPrint('User: $text');
      debugPrint('Claudine: $answer');

      // Google TTS typically has better buffering, but still add small delay
      await Future.delayed(const Duration(milliseconds: 200));

      debugPrint('🗣️ Speaking: $answer');

      // Speak directly without padding - Google TTS handles this better
      await _tts.speak(answer);
    } catch (e) {
      debugPrint('Error: $e');
      _showError('Fout: ${e.toString()}');
      setState(() => _state = VoiceState.idle);
    }
  }

  void _showError(String message) {
    debugPrint('❌ Error: $message');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _speech.stop();
    _tts.stop();
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
              _buildVisualizer(),
              const SizedBox(height: 32),
              _buildStatus(),
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
            'Claudine Voice MVP',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
          ),
          if (_versionInfo.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _versionInfo,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVisualizer() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final scale = _state == VoiceState.listening
            ? 1.0 + (_pulseController.value * 0.2)
            : 1.0;

        return Transform.scale(
          scale: scale,
          child: Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _getVisualizerColor(),
              boxShadow: [
                BoxShadow(
                  color: _getVisualizerColor().withOpacity(0.5),
                  blurRadius: 40,
                  spreadRadius: _state == VoiceState.listening ? 20 : 0,
                ),
              ],
            ),
            child: Icon(
              _getIcon(),
              size: 70,
              color: Colors.white,
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatus() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0),
      child: Column(
        children: [
          Text(
            _getStatusText(),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          if (_currentText.isNotEmpty || _lastResponse.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                _getDisplayText(),
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
    if (_state == VoiceState.listening || _state == VoiceState.speaking) {
      return FloatingActionButton(
        onPressed: () {
          if (_state == VoiceState.listening) {
            _stopListening();
          } else {
            _tts.stop();
          }
        },
        backgroundColor: Colors.red,
        child: const Icon(Icons.stop, size: 32),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Test text input
        Container(
          width: 250,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(25),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'Type to test...',
                    hintStyle: TextStyle(color: Colors.white70),
                    border: InputBorder.none,
                  ),
                  onSubmitted: (text) {
                    if (text.isNotEmpty) _testWithText(text);
                  },
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send, color: Colors.white),
                onPressed: () {
                  // Will be handled by onSubmitted
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        // Voice input button
        FloatingActionButton.large(
          onPressed: _startListening,
          backgroundColor: Colors.white,
          child: const Icon(Icons.mic, color: Colors.blue, size: 40),
        ),
      ],
    );
  }

  // Test function for debugging without microphone
  Future<void> _testWithText(String text) async {
    setState(() => _currentText = text);
    await Future.delayed(const Duration(milliseconds: 500));
    _processInput(text);
  }

  // Helper methods

  List<Color> _getGradientColors() {
    switch (_state) {
      case VoiceState.idle:
        return [Colors.blue.shade400, Colors.blue.shade700];
      case VoiceState.listening:
        return [Colors.purple.shade400, Colors.purple.shade700];
      case VoiceState.processing:
        return [Colors.orange.shade400, Colors.orange.shade700];
      case VoiceState.speaking:
        return [Colors.green.shade400, Colors.green.shade700];
    }
  }

  Color _getVisualizerColor() {
    switch (_state) {
      case VoiceState.idle:
        return Colors.white.withOpacity(0.3);
      case VoiceState.listening:
        return Colors.purple.shade300;
      case VoiceState.processing:
        return Colors.orange.shade300;
      case VoiceState.speaking:
        return Colors.green.shade300;
    }
  }

  IconData _getIcon() {
    switch (_state) {
      case VoiceState.idle:
        return Icons.mic_none;
      case VoiceState.listening:
        return Icons.mic;
      case VoiceState.processing:
        return Icons.hourglass_bottom;
      case VoiceState.speaking:
        return Icons.volume_up;
    }
  }

  String _getStatusText() {
    switch (_state) {
      case VoiceState.idle:
        return 'Tik op de microfoon';
      case VoiceState.listening:
        return 'Ik luister...';
      case VoiceState.processing:
        return 'Even denken...';
      case VoiceState.speaking:
        return 'Claudine spreekt...';
    }
  }

  String _getDisplayText() {
    if (_state == VoiceState.listening && _currentText.isNotEmpty) {
      return _currentText;
    } else if ((_state == VoiceState.speaking || _state == VoiceState.idle) &&
        _lastResponse.isNotEmpty) {
      return _lastResponse;
    }
    return '';
  }
}

enum VoiceState {
  idle,
  listening,
  processing,
  speaking,
}
