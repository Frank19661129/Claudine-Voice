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
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:vibration/vibration.dart';  // Vibration feedback
import 'services/claudine_api.dart';
import 'services/queue_manager.dart';
import 'services/auth_service.dart';
import 'models/queue_item.dart';
import 'widgets/queue_indicator.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/queue_screen.dart';
import 'screens/login_screen.dart';

// Global navigator key for auth flows
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  // Load environment variables
  await dotenv.load(fileName: ".env");

  runApp(
    const ProviderScope(
      child: ClaudineVoiceMVP(),
    ),
  );
}

class ClaudineVoiceMVP extends StatefulWidget {
  const ClaudineVoiceMVP({super.key});

  @override
  State<ClaudineVoiceMVP> createState() => _ClaudineVoiceMVPState();
}

class _ClaudineVoiceMVPState extends State<ClaudineVoiceMVP> {
  bool _isCheckingAuth = true;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    final isLoggedIn = await authService.isLoggedIn();
    if (mounted) {
      setState(() {
        _isLoggedIn = isLoggedIn;
        _isCheckingAuth = false;
      });
    }
  }

  void _onLoginSuccess() {
    setState(() {
      _isLoggedIn = true;
    });
  }

  void _onLogout() {
    setState(() {
      _isLoggedIn = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Claudine',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      routes: {
        '/home': (context) => const HomeScreen(),
        '/login': (context) => const LoginScreen(),
      },
      home: _isCheckingAuth
          ? const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            )
          : _isLoggedIn
              ? const HomeScreen()
              : const LoginScreen(),
    );
  }
}

class VoiceScreen extends StatefulWidget {
  const VoiceScreen({super.key});

  @override
  State<VoiceScreen> createState() => _VoiceScreenState();
}

class _VoiceScreenState extends State<VoiceScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  // Google Cloud TTS API Key - loaded from .env file
  static final String _googleTtsApiKey = dotenv.env['GOOGLE_TTS_API_KEY'] ?? '';

  // Services
  final SpeechToText _speech = SpeechToText();
  final FlutterTts _tts = FlutterTts();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final ClaudineApiService _api = ClaudineApiService();
  final QueueManager _queueManager = QueueManager();

  // Stream subscriptions
  StreamSubscription<List<QueueItem>>? _queueItemsSubscription;

  // State
  VoiceState _state = VoiceState.idle;
  String _currentText = '';
  String _lastResponse = '';
  bool _isInitialized = false;
  String _currentLocale = 'nl-NL';  // Track current language
  String _versionInfo = '';  // Version + build number

  // Location
  Position? _currentLocation;
  String _locationInfo = '';
  String _locationName = '';
  String _locationStreet = '';
  Timer? _locationTimer;

  // Server Status
  bool _serverConnected = false;
  String _serverStatus = 'Checking...';

  // Multi-provider Authentication (Calendar)
  bool _o365Authenticated = false;
  String _o365User = '';
  bool _googleAuthenticated = false;
  String _googleUser = '';
  String? _activeProvider;  // 'o365' or 'google'

  // User Login Provider
  String? _loginProvider;  // 'google' or 'microsoft'

  // Conversation history
  final List<Map<String, String>> _history = [];

  // Animation
  late AnimationController _pulseController;

  // Smart speech detection
  DateTime? _lastSpeechTime;
  bool _hasFillerWord = false;
  bool _seemsIncomplete = false;
  String _listeningStatus = '';  // "thinking", "listening", ""

  // Dutch filler words that indicate user is thinking
  static const List<String> _fillerWords = [
    'eeh', 'eh', 'uhm', 'um', 'uh', 'mmm', 'hmm',
    'dus', 'eigenlijk', 'zeg maar', 'nou', 'ja',
    'gewoon', 'zoals', 'ofzo', 'enzo', 'enzovoort'
  ];

  // Words that suggest incomplete sentence
  static const List<String> _incompleteIndicators = [
    'en', 'of', 'maar', 'dus', 'omdat', 'want',
    'die', 'dat', 'met', 'voor', 'bij', 'naar'
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadVersion();
    _initialize();
    _setupAnimation();
    _refreshStatus();
    _startLocationTimer();
    _queueManager.start(); // Start queue processing
    _setupQueueListener(); // Listen for queue completions
  }

  /// Setup listener for queue item completions
  void _setupQueueListener() {
    List<QueueItem>? _previousItems;

    _queueItemsSubscription = _queueManager.queueItemsStream.listen((items) async {
      // Check if any item just completed
      if (_previousItems != null) {
        for (final item in items) {
          final previousItem = _previousItems!.firstWhere(
            (prev) => prev.id == item.id,
            orElse: () => item,
          );

          // If item was processing and is now completed, give haptic feedback
          if (previousItem.status == QueueItemStatus.processing &&
              item.status == QueueItemStatus.completed) {
            debugPrint('✅ Queue item completed: ${item.command}');
            await _vibrateCompletion();
          }
        }
      }

      _previousItems = List.from(items);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // App komt naar voren - refresh alles
      _refreshStatus();
    }
  }

  Future<void> _loadVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _versionInfo = 'v${packageInfo.version}+${packageInfo.buildNumber}';
    });
  }

  Future<void> _getLocation() async {
    try {
      // Request location permission
      final locationStatus = await Permission.location.request();

      if (!locationStatus.isGranted) {
        debugPrint('⚠️ Location permission not granted');
        setState(() {
          _locationInfo = 'Locatie toegang geweigerd';
        });
        return;
      }

      // Check if location services are enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('⚠️ Location services disabled');
        setState(() {
          _locationInfo = 'Locatie services uitgeschakeld';
        });
        return;
      }

      debugPrint('📍 Getting GPS location...');

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      setState(() {
        _currentLocation = position;
        _locationInfo = 'GPS: ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
      });

      debugPrint('✓ Location obtained: $_locationInfo');
      debugPrint('  Accuracy: ${position.accuracy}m');

      // Reverse geocoding - get place name
      try {
        debugPrint('🌍 Getting location name...');
        List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );

        if (placemarks.isNotEmpty) {
          final place = placemarks.first;

          // Build location name: City or Locality
          final city = place.locality ?? place.subAdministrativeArea ?? place.administrativeArea;

          // Get street name
          final street = place.street ?? place.thoroughfare ?? '';
          final houseNumber = place.subThoroughfare ?? '';

          String fullStreet = street;
          if (houseNumber.isNotEmpty && street.isNotEmpty) {
            fullStreet = '$street $houseNumber';
          }

          setState(() {
            _locationName = city ?? 'Onbekende locatie';
            _locationStreet = fullStreet;
          });

          debugPrint('✓ Location: $_locationName');
          debugPrint('  Street: $_locationStreet');
          debugPrint('  Full: ${place.street}, ${place.locality}, ${place.administrativeArea}, ${place.country}');
        }
      } catch (e) {
        debugPrint('⚠️ Reverse geocoding error: $e');
        setState(() {
          _locationName = 'Locatie naam onbekend';
        });
      }
    } catch (e) {
      debugPrint('❌ Location error: $e');
      setState(() {
        _locationInfo = 'Kon locatie niet bepalen';
      });
    }
  }

  Future<void> _initialize() async {
    // Request microphone permission
    final micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) {
      _showError('Microphone permission required');
      return;
    }

    // Request location permission and get location
    await _getLocation();

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

    // Critical: Warm up the TTS engine by speaking something silent
    // This prevents clipping on the first real speech
    debugPrint('🔥 Warming up TTS engine...');
    await _tts.setVolume(0.0);  // Mute for warmup
    await _tts.speak(' ');  // Speak silence
    await Future.delayed(const Duration(milliseconds: 500));
    await _tts.setVolume(1.0);  // Restore volume
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
    debugPrint('🎤 === START LISTENING CALLED ===');
    debugPrint('🎤 Initialized: $_isInitialized');
    debugPrint('🎤 Current state: $_state');

    if (!_isInitialized) {
      debugPrint('❌ Not initialized!');
      _showError('Not initialized yet');
      return;
    }

    if (_state == VoiceState.listening) {
      debugPrint('⚠️ Already listening, ignoring');
      return;
    }

    setState(() {
      _state = VoiceState.listening;
      _currentText = '';
      _hasFillerWord = false;
      _seemsIncomplete = false;
      _listeningStatus = 'listening';
      _lastSpeechTime = DateTime.now();
    });

    debugPrint('🎤 Starting to listen in $_currentLocale...');
    _showMessage('Luisteren gestart...');

    try {
      await _speech.listen(
        onResult: (result) {
          final text = result.recognizedWords;
          _lastSpeechTime = DateTime.now();

          // Detect filler words and incomplete sentences
          final hasFillerWord = _detectFillerWords(text);
          final seemsIncomplete = _detectIncomplete(text);

          setState(() {
            _currentText = text;
            _hasFillerWord = hasFillerWord;
            _seemsIncomplete = seemsIncomplete;

            // Update status message
            if (hasFillerWord) {
              _listeningStatus = 'thinking';
              debugPrint('💭 Filler word detected - user thinking');
            } else if (seemsIncomplete) {
              _listeningStatus = 'continuing';
              debugPrint('📝 Incomplete sentence detected');
            } else {
              _listeningStatus = 'listening';
            }
          });

          if (result.finalResult) {
            _processInput(text);
          }
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 5),
        partialResults: true,
        localeId: _currentLocale,
      );
    } catch (e) {
      debugPrint('Listen error: $e');
      setState(() {
        _state = VoiceState.idle;
        _listeningStatus = '';
      });
    }
  }

  /// Detect if text contains filler words (user is thinking)
  bool _detectFillerWords(String text) {
    final textLower = text.toLowerCase();

    // Check for filler words at the end or standalone
    for (final filler in _fillerWords) {
      if (textLower.endsWith(filler) ||
          textLower.endsWith('$filler ') ||
          textLower == filler ||
          textLower.contains(' $filler ')) {
        return true;
      }
    }

    return false;
  }

  /// Detect if sentence seems incomplete (trailing conjunction/preposition)
  bool _detectIncomplete(String text) {
    if (text.isEmpty) return false;

    final textLower = text.toLowerCase().trim();
    final words = textLower.split(' ');

    if (words.isEmpty) return false;

    // Check if last word is an incomplete indicator
    final lastWord = words.last;
    if (_incompleteIndicators.contains(lastWord)) {
      return true;
    }

    // Check if text ends with comma or ellipsis
    if (text.endsWith(',') || text.endsWith('...')) {
      return true;
    }

    return false;
  }

  Future<void> _stopListening() async {
    await _speech.stop();
    setState(() => _state = VoiceState.idle);
  }

  Future<void> _processInput(String text) async {
    debugPrint('🧠 === PROCESS INPUT CALLED ===');
    debugPrint('🧠 Input text: "$text"');

    if (text.isEmpty) {
      debugPrint('⚠️ Empty text, skipping');
      return;
    }

    setState(() => _state = VoiceState.processing);
    _showMessage('Verwerken...');

    try {
      debugPrint('📝 Adding to history...');
      // Add to history
      _history.add({'role': 'user', 'content': text});

      // Keep last 10 exchanges
      if (_history.length > 20) {
        _history.removeRange(0, 2);
      }

      debugPrint('📥 === ADDING TO QUEUE ===');
      debugPrint('📊 Command: $text');
      _showMessage('Verzoek toevoegen aan wachtrij...');

      // Build location string for metadata
      String? location;
      if (_locationStreet.isNotEmpty && _locationName.isNotEmpty) {
        location = '$_locationStreet, $_locationName';
      } else if (_locationName.isNotEmpty) {
        location = _locationName;
      }

      // Add to queue for async processing
      final queueItem = QueueItem.create(
        command: text,
        type: QueueItemType.general,
        metadata: {
          if (location != null) 'location': location,
        },
      );

      // Add to queue (fire and forget - async)
      _queueManager.addToQueue(queueItem);

      debugPrint('✅ Added to queue, will process async');

      // Give haptic feedback
      await _vibrateStart();

      // Return to idle immediately
      setState(() {
        _state = VoiceState.idle;
      });

      debugPrint('User: $text');
      debugPrint('Claudine: [Queue processing]');
    } catch (e) {
      debugPrint('Error: $e');
      _showError('Fout: ${e.toString()}');
      setState(() => _state = VoiceState.idle);
    }
  }


  /// Vibration feedback for request submitted
  Future<void> _vibrateStart() async {
    try {
      debugPrint('🔔 Attempting start vibration...');
      if (await Vibration.hasVibrator() ?? false) {
        debugPrint('🔔 Device has vibrator, vibrating for 200ms');
        Vibration.vibrate(duration: 200);  // Stronger vibration (200ms)
      } else {
        debugPrint('⚠️ No vibrator detected');
      }
    } catch (e) {
      debugPrint('❌ Vibration error: $e');
    }
  }

  /// Vibration feedback for request completed
  Future<void> _vibrateCompletion() async {
    try {
      debugPrint('🔔 Attempting completion vibration...');
      if (await Vibration.hasVibrator() ?? false) {
        debugPrint('🔔 Device has vibrator, vibrating for 400ms');
        Vibration.vibrate(duration: 400);  // Strong vibration (400ms)
      } else {
        debugPrint('⚠️ No vibrator detected');
      }
    } catch (e) {
      debugPrint('❌ Vibration error: $e');
    }
  }

  void _showError(String message) {
    debugPrint('❌ Error: $message');
    ScaffoldMessenger.of(context).clearSnackBars();  // Clear old snackbars first
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 8),  // Longer duration
        behavior: SnackBarBehavior.floating,  // Float above content
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showMessage(String message) {
    debugPrint('✅ Message: $message');
    ScaffoldMessenger.of(context).clearSnackBars();  // Clear old snackbars first
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.green.shade700,
        duration: const Duration(seconds: 5),  // Longer duration
        behavior: SnackBarBehavior.floating,  // Float above content
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _refreshStatus() async {
    debugPrint('🔄 Refreshing all status...');

    // 1. Refresh location
    await _getLocation();

    // 2. Check server connectivity
    await _checkServerConnection();

    // 3. Check auth status (O365 + Google, only if server is connected)
    if (_serverConnected) {
      await _checkAuthStatus();
    } else {
      setState(() {
        _o365Authenticated = false;
        _o365User = '';
        _googleAuthenticated = false;
        _googleUser = '';
        _activeProvider = null;
      });
    }
  }

  Future<void> _checkServerConnection() async {
    try {
      debugPrint('🌐 Checking server connection...');
      final isHealthy = await _api.checkHealth();

      setState(() {
        _serverConnected = isHealthy;
        _serverStatus = isHealthy ? 'Connected' : 'Offline';
      });

      debugPrint('🌐 Server status: $_serverStatus');
    } catch (e) {
      debugPrint('❌ Server check failed: $e');
      setState(() {
        _serverConnected = false;
        _serverStatus = 'Error';
      });
    }
  }

  Future<void> _checkAuthStatus() async {
    try {
      debugPrint('📧 Checking auth status (O365 + Google)...');
      final authInfo = await _api.getAuthInfo();

      if (authInfo != null) {
        // O365 status
        final o365Info = authInfo['o365'] ?? {};
        final googleInfo = authInfo['google'] ?? {};

        setState(() {
          _o365Authenticated = o365Info['authenticated'] ?? false;
          _o365User = o365Info['user'] ?? '';
          _googleAuthenticated = googleInfo['authenticated'] ?? false;
          _googleUser = googleInfo['user'] ?? '';
          _activeProvider = authInfo['active_provider'];
        });

        debugPrint('📧 O365: $_o365Authenticated (${_o365User})');
        debugPrint('📧 Google: $_googleAuthenticated (${_googleUser})');
        debugPrint('📧 Active provider: $_activeProvider');
      } else {
        setState(() {
          _o365Authenticated = false;
          _o365User = '';
          _googleAuthenticated = false;
          _googleUser = '';
          _activeProvider = null;
        });
      }
    } catch (e) {
      debugPrint('❌ Failed to check auth status: $e');
      setState(() {
        _o365Authenticated = false;
        _o365User = '';
        _googleAuthenticated = false;
        _googleUser = '';
        _activeProvider = null;
      });
    }

    // Also check login provider
    await _checkLoginProvider();
  }

  Future<void> _checkLoginProvider() async {
    try {
      final userInfo = await _api.getCurrentUser();
      if (userInfo != null) {
        setState(() {
          _loginProvider = userInfo['provider'];
        });
        debugPrint('👤 Logged in with: $_loginProvider');
      } else {
        setState(() {
          _loginProvider = null;
        });
      }
    } catch (e) {
      debugPrint('❌ Failed to check login provider: $e');
    }
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SettingsScreen(
          o365Authenticated: _o365Authenticated,
          o365User: _o365User,
          googleAuthenticated: _googleAuthenticated,
          googleUser: _googleUser,
          activeProvider: _activeProvider,
          onSetPrimaryProvider: _handleSetPrimaryProvider,
          onLogin: _handleLogin,
          onLogout: _handleLogout,
          locationName: _locationName,
          locationStreet: _locationStreet,
          locationInfo: _locationInfo,
          onUserLogout: () {
            // Navigate back to login screen after user logout
            Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
          },
        ),
      ),
    );
  }

  Future<void> _handleLogin(String provider) async {
    try {
      debugPrint('🔐 Login to $provider...');

      // Queue the login request
      await _queueManager.addToQueue(
        QueueItem.create(
          command: 'Login to $provider',
          type: QueueItemType.general,
          metadata: {'action': 'login', 'provider': provider},
        ),
      );

      // Show feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Login to $provider queued'),
            duration: const Duration(seconds: 2),
          ),
        );
      }

      // Refresh auth status after a moment
      await Future.delayed(const Duration(seconds: 1));
      await _checkAuthStatus();
    } catch (e) {
      debugPrint('❌ Login failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Login failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleLogout(String provider) async {
    try {
      debugPrint('🔐 Logout from $provider...');

      // Queue the logout request
      await _queueManager.addToQueue(
        QueueItem.create(
          command: 'Logout from $provider',
          type: QueueItemType.general,
          metadata: {'action': 'logout', 'provider': provider},
        ),
      );

      // Show feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Logout from $provider queued'),
            duration: const Duration(seconds: 2),
          ),
        );
      }

      // Refresh auth status
      await Future.delayed(const Duration(seconds: 1));
      await _checkAuthStatus();
    } catch (e) {
      debugPrint('❌ Logout failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Logout failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleSetPrimaryProvider(String provider) async {
    try {
      debugPrint('⭐ Setting $provider as primary provider...');

      // Queue the set primary provider request
      await _queueManager.addToQueue(
        QueueItem.create(
          command: 'Set $provider as primary',
          type: QueueItemType.general,
          metadata: {'action': 'set_primary_provider', 'provider': provider},
        ),
      );

      // Also call API directly
      final success = await _api.setPrimaryProvider(provider);

      if (success) {
        // Update local state
        setState(() {
          _activeProvider = provider;
        });

        // Show feedback
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$provider set as primary mailbox'),
              duration: const Duration(seconds: 2),
              backgroundColor: Colors.green,
            ),
          );
        }

        // Refresh auth status
        await Future.delayed(const Duration(milliseconds: 500));
        await _checkAuthStatus();
      } else {
        throw Exception('API call failed');
      }
    } catch (e) {
      debugPrint('❌ Set primary provider failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to set primary provider: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _startLocationTimer() {
    // Refresh location elke 30 minuten
    _locationTimer = Timer.periodic(const Duration(minutes: 30), (timer) {
      debugPrint('⏰ Location timer: refreshing location');
      _getLocation();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _locationTimer?.cancel();
    _queueItemsSubscription?.cancel();
    _pulseController.dispose();
    _speech.stop();
    _tts.stop();
    _queueManager.dispose();
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

  Widget _buildLoginProviderBadge() {
    if (_loginProvider == null) return const SizedBox.shrink();

    // Determine colors and icon based on provider
    Color badgeColor;
    String text;
    Color textColor = Colors.white;

    if (_loginProvider == 'google') {
      badgeColor = Colors.red.shade700;
      text = 'Google';
    } else if (_loginProvider == 'microsoft') {
      badgeColor = Colors.blue.shade700;
      text = 'Microsoft';
    } else {
      badgeColor = Colors.grey.shade700;
      text = _loginProvider!;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _loginProvider == 'google'
              ? Icons.g_mobiledata
              : Icons.business,
            color: textColor,
            size: 16,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: textColor,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQueueBadge() {
    return StreamBuilder<int>(
      stream: _queueManager.queueCountStream,
      initialData: 0,
      builder: (context, snapshot) {
        final queueCount = snapshot.data ?? 0;
        final isEmpty = queueCount == 0;

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => QueueScreen(),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isEmpty
                  ? Colors.white.withOpacity(0.3)
                  : Colors.blue.withOpacity(0.8),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.queue,
                  color: Colors.white,
                  size: 16,
                ),
                // Toon alleen cijfer als > 0
                if (!isEmpty) ...[
                  const SizedBox(width: 4),
                  Text(
                    '$queueCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Claudine Voice MVP',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Login provider badge
                  if (_loginProvider != null) ...[
                    _buildLoginProviderBadge(),
                    const SizedBox(width: 8),
                  ],
                  // Queue indicator badge
                  _buildQueueBadge(),
                  const SizedBox(width: 8),
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
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.settings, color: Colors.white),
                    onPressed: _openSettings,
                    tooltip: 'Settings',
                  ),
                ],
              ),
            ],
          ),
          // Status indicators
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                // Server status
                Row(
                  children: [
                    Icon(
                      _serverConnected ? Icons.cloud_done : Icons.cloud_off,
                      color: _serverConnected ? Colors.green[300] : Colors.red[300],
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Server: $_serverStatus',
                        style: TextStyle(
                          color: _serverConnected ? Colors.green[300] : Colors.red[300],
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // O365 status
                Row(
                  children: [
                    Icon(
                      _o365Authenticated ? Icons.check_circle : Icons.error_outline,
                      color: _o365Authenticated ? Colors.green[300] : Colors.grey[400],
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _o365Authenticated
                            ? 'O365: ${_o365User.split('@')[0]}'
                            : 'O365: -',
                        style: TextStyle(
                          color: _o365Authenticated ? Colors.green[300] : Colors.grey[400],
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Star for primary provider
                    if (_activeProvider == 'o365')
                      const Icon(
                        Icons.star,
                        color: Colors.amber,
                        size: 16,
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                // Google status
                Row(
                  children: [
                    Icon(
                      _googleAuthenticated ? Icons.check_circle : Icons.error_outline,
                      color: _googleAuthenticated ? Colors.green[300] : Colors.grey[400],
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _googleAuthenticated
                            ? 'Google: ${_googleUser.split('@')[0]}'
                            : 'Google: -',
                        style: TextStyle(
                          color: _googleAuthenticated ? Colors.green[300] : Colors.grey[400],
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Star for primary provider
                    if (_activeProvider == 'google')
                      const Icon(
                        Icons.star,
                        color: Colors.amber,
                        size: 16,
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                // Refresh button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _refreshStatus,
                    icon: const Icon(Icons.refresh, size: 14),
                    label: const Text('Refresh', style: TextStyle(fontSize: 11)),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      backgroundColor: Colors.white.withOpacity(0.2),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
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

    return FloatingActionButton.large(
      onPressed: _startListening,
      backgroundColor: Colors.white,
      child: const Icon(Icons.mic, color: Colors.blue, size: 40),
    );
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
        // Smart feedback based on listening status
        if (_listeningStatus == 'thinking') {
          return 'Ik hoor je denken... 💭';
        } else if (_listeningStatus == 'continuing') {
          return 'Ik luister verder... 📝';
        } else {
          return 'Ik luister... 🎤';
        }
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
