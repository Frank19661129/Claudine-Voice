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
import 'services/claudine_api.dart';
import 'services/queue_manager.dart';
import 'models/queue_item.dart';
import 'widgets/queue_indicator.dart';
import 'screens/home_screen.dart';

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
      title: 'Claudine',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
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
  // API Keys - loaded from .env file
  static final String _claudeApiKey = dotenv.env['CLAUDE_API_KEY'] ?? '';

  // Google Cloud TTS API Key - loaded from .env file
  static final String _googleTtsApiKey = dotenv.env['GOOGLE_TTS_API_KEY'] ?? '';

  // Services
  final SpeechToText _speech = SpeechToText();
  final FlutterTts _tts = FlutterTts();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final ClaudineApiService _api = ClaudineApiService();
  final QueueManager _queueManager = QueueManager();

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

  // Multi-provider Authentication
  bool _o365Authenticated = false;
  String _o365User = '';
  bool _googleAuthenticated = false;
  String _googleUser = '';
  String? _activeProvider;  // 'o365' or 'google'

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

      debugPrint('🤖 === CALLING CLAUDE API ===');
      debugPrint('📊 History length: ${_history.length}');
      debugPrint('📝 Last message: ${_history.last}');
      _showMessage('Claude API aanroepen...');

      // Adjust system prompt based on language
      String locationContext = '';
      if (_currentLocation != null) {
        if (_locationStreet.isNotEmpty) {
          locationContext = '\n\nDe gebruiker is in de buurt van: $_locationStreet, $_locationName';
        } else {
          locationContext = '\n\nDe gebruiker is in de buurt van: $_locationName';
        }
        // GPS voor context, maar niet voorlezen
        locationContext += '\n(Exacte GPS: ${_currentLocation!.latitude.toStringAsFixed(4)}, ${_currentLocation!.longitude.toStringAsFixed(4)} - noem deze coördinaten NOOIT hardop)';
      }

      // Huidige datum voor calendar context met weekdagen
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final weekdayNames = ['maandag', 'dinsdag', 'woensdag', 'donderdag', 'vrijdag', 'zaterdag', 'zondag'];
      final weekdayNamesEn = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

      // Bereken komende 7 dagen met weekdagen
      String weekOverview = '';
      for (int i = 0; i < 7; i++) {
        final date = today.add(Duration(days: i));
        final weekdayName = _currentLocale.startsWith('nl')
            ? weekdayNames[date.weekday - 1]
            : weekdayNamesEn[date.weekday - 1];
        final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

        if (i == 0) {
          weekOverview += '$weekdayName $dateStr (VANDAAG)\n';
        } else if (i == 1) {
          weekOverview += '$weekdayName $dateStr (morgen)\n';
        } else {
          weekOverview += '$weekdayName $dateStr\n';
        }
      }

      final dateContext = '\n\nHuidige datum en komende week:\n$weekOverview';

      // Provider context - use PRIMARY provider by default
      final bool hasO365 = _o365Authenticated;
      final bool hasGoogle = _googleAuthenticated;
      final int providerCount = (hasO365 ? 1 : 0) + (hasGoogle ? 1 : 0);

      String providerContext = '';
      if (providerCount == 0) {
        providerContext = '\n\nGEEN CALENDAR: Gebruiker is niet ingelogd. Vertel hem/haar om in te loggen.';
      } else if (providerCount == 1) {
        final provider = hasO365 ? 'o365' : 'google';
        providerContext = '\n\nCALENDAR: Gebruik automatisch "$provider" als provider.';
      } else {
        // Multiple providers - use PRIMARY as default
        final primaryProvider = _activeProvider ?? (hasO365 ? 'o365' : 'google');
        final primaryName = primaryProvider == 'o365' ? 'Microsoft' : 'Google';

        providerContext = '''

MEERDERE CALENDARS:
Gebruiker heeft zowel O365 als Google Calendar.
PRIMARY CALENDAR: $primaryName ($primaryProvider) - gebruik dit als STANDAARD tenzij gebruiker anders aangeeft!

- Als gebruiker NIET specificeert welke agenda → gebruik automatisch "$primaryProvider" (primary)
- Als hij/zij zegt "Microsoft", "Outlook", of "werk" → gebruik "o365"
- Als hij/zij zegt "Google" of "prive" → gebruik "google"
- Als hij/zij zegt "beide agenda's" of "allebei" → maak TWEE events (één o365, één google)

BELANGRIJK: Bij twijfel gebruik je de PRIMARY calendar ($primaryProvider).''';
      }

      final systemPrompt = _currentLocale.startsWith('nl')
          ? '''Je bent Claudine, een vriendelijke persoonlijke assistent met toegang tot Calendar (O365 en Google).
Spreek Nederlands. Houd antwoorden kort (max 2-3 zinnen).
Dit is een spraak conversatie.$locationContext$dateContext$providerContext

BELANGRIJK: Als gevraagd wordt waar de gebruiker is, antwoord dan met de locatienaam (bijv. "Je bent in de buurt van [straat], [plaats]"). Noem NOOIT GPS coördinaten hardop.

CALENDAR FUNCTIE:
Wanneer de gebruiker een afspraak wil maken, extraheer de details en gebruik dit JSON formaat aan het EINDE van je antwoord:
[CALENDAR:{"title":"Afspraak titel","date":"YYYY-MM-DD","time":"HH:MM","location":"Locatie","provider":"o365 of google"}]

PROVIDER REGELS:
- Als gebruiker zegt "Microsoft/Outlook/werk agenda" → "provider":"o365"
- Als gebruiker zegt "Google/prive agenda" → "provider":"google"
- Als gebruiker zegt "beide agenda's" of "allebei" → maak TWEE CALENDAR tags (één o365, één google)!
- Als NIET DUIDELIJK en meerdere providers → VRAAG eerst welke agenda!
- Als maar 1 provider beschikbaar → gebruik die automatisch

Voorbeeld 1 (duidelijk):
Gebruiker: "Maak een afspraak voor morgen om 14 uur bij de tandarts in mijn Microsoft agenda"
Jij: "Ik maak een afspraak in je Microsoft agenda. [CALENDAR:{"title":"Tandarts","date":"2025-11-06","time":"14:00","location":"Tandarts","provider":"o365"}]"

Voorbeeld 2 (niet duidelijk, meerdere providers):
Gebruiker: "Maak een afspraak voor morgen om 14 uur bij de tandarts"
Jij: "Wil je dit in je Microsoft of Google agenda?"

Voorbeeld 3 (beide agenda's - BELANGRIJK):
Gebruiker: "Maak een afspraak voor morgen om 10 uur kerk in beide agenda's"
Jij: "Ik maak de afspraak in beide agenda's. [CALENDAR:{"title":"Kerk","date":"2025-11-06","time":"10:00","location":"Kerk","provider":"o365"}][CALENDAR:{"title":"Kerk","date":"2025-11-06","time":"10:00","location":"Kerk","provider":"google"}]"'''
          : '''You are Claudine, a friendly personal assistant with access to Office 365 Calendar.
Speak in English. Keep answers short (max 2-3 sentences).
This is a voice conversation.$locationContext$dateContext

IMPORTANT: When asked about location, respond with the location name (e.g. "You are near [street], [city]"). NEVER say GPS coordinates out loud.

CALENDAR FUNCTION:
When the user wants to create an appointment, extract the details and use this JSON format at the END of your response:
[CALENDAR:{"title":"Appointment title","date":"YYYY-MM-DD","time":"HH:MM","location":"Location"}]

Example (if today is 2025-11-04):
User: "Make an appointment for tomorrow at 2 PM at the dentist"
You: "I'll create an appointment for you at the dentist. [CALENDAR:{"title":"Dentist","date":"2025-11-05","time":"14:00","location":"Dentist"}]"''';

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
          'max_tokens': 300,  // Verhoogd voor calendar JSON
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
        debugPrint('❌ === CLAUDE API ERROR ===');
        debugPrint('❌ Status code: $statusCode');
        debugPrint('❌ Response body: $body');
        _showError('Claude API fout: $statusCode');
        throw Exception('API error: $statusCode\n$body');
      }

      final data = jsonDecode(response.body);
      debugPrint('✓ Claude response with model: $usedModel');
      String answer = data['content'][0]['text'] as String;

      debugPrint('🤖 Claude full answer: $answer');

      // Check for calendar event creation (kan meerdere zijn!)
      String displayAnswer = answer;
      if (answer.contains('[CALENDAR:')) {
        debugPrint('✅ CALENDAR tag(s) found in answer!');

        // Vind ALLE calendar tags (niet alleen de eerste)
        final matches = RegExp(r'\[CALENDAR:(.*?)\]').allMatches(answer);

        if (matches.isNotEmpty) {
          debugPrint('📅 Found ${matches.length} calendar event(s)');

          // Verwijder alle CALENDAR tags uit display answer
          displayAnswer = answer;
          for (final match in matches) {
            displayAnswer = displayAnswer.replaceAll(match.group(0)!, '').trim();
          }

          // Maak elk event aan
          for (final match in matches) {
            final calendarJson = match.group(1);
            debugPrint('📅 Processing calendar event: $calendarJson');
            _createCalendarEvent(calendarJson!);
          }
        }
      }

      // Add to history
      _history.add({'role': 'assistant', 'content': displayAnswer});

      setState(() {
        _lastResponse = displayAnswer;
        _state = VoiceState.speaking;
      });

      debugPrint('User: $text');
      debugPrint('Claudine: $displayAnswer');

      // Google TTS typically has better buffering, but still add small delay
      await Future.delayed(const Duration(milliseconds: 200));

      debugPrint('🗣️ Speaking: $displayAnswer');

      // Speak directly without padding - Google TTS handles this better
      await _tts.speak(displayAnswer);
    } catch (e) {
      debugPrint('Error: $e');
      _showError('Fout: ${e.toString()}');
      setState(() => _state = VoiceState.idle);
    }
  }

  Future<void> _createCalendarEvent(String calendarJson) async {
    debugPrint('📅 === START CALENDAR EVENT CREATION ===');
    debugPrint('📅 Raw JSON: $calendarJson');

    try {
      final eventData = jsonDecode(calendarJson);
      debugPrint('📅 Parsed JSON successfully');

      final title = eventData['title'] as String;
      final dateStr = eventData['date'] as String;
      final timeStr = eventData['time'] as String?;
      final location = eventData['location'] as String?;
      final provider = eventData['provider'] as String?;  // 'o365' or 'google'

      debugPrint('📅 Extracted data:');
      debugPrint('  Title: $title');
      debugPrint('  Date: $dateStr');
      debugPrint('  Time: $timeStr');
      debugPrint('  Location: $location');
      debugPrint('  Provider: $provider');

      // Parse date and time
      final dateParts = dateStr.split('-');
      final year = int.parse(dateParts[0]);
      final month = int.parse(dateParts[1]);
      final day = int.parse(dateParts[2]);

      int hour = 9; // Default 9:00 AM
      int minute = 0;

      if (timeStr != null && timeStr.contains(':')) {
        final timeParts = timeStr.split(':');
        hour = int.parse(timeParts[0]);
        minute = int.parse(timeParts[1]);
      }

      final startDateTime = DateTime(year, month, day, hour, minute);
      final endDateTime = startDateTime.add(const Duration(hours: 1));

      debugPrint('📅 Parsed DateTime:');
      debugPrint('  Start: $startDateTime');
      debugPrint('  End: $endDateTime');

      // Add to queue instead of calling API directly
      debugPrint('📅 Adding to queue with provider: $provider...');

      final queueItem = QueueItem.create(
        command: title,
        type: QueueItemType.calendarCreate,
        metadata: {
          'title': title,
          'start': startDateTime.toIso8601String(),
          'end': endDateTime.toIso8601String(),
          if (location != null) 'location': location,
          if (provider != null) 'provider': provider,
        },
      );

      await _queueManager.addToQueue(queueItem);

      debugPrint('✅ Added to queue, will process async');
      _showMessage('📥 Afspraak toegevoegd aan wachtrij: $title');
    } catch (e, stackTrace) {
      debugPrint('❌ Error creating calendar event: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      _showError('Fout bij aanmaken afspraak: ${e.toString()}');
    }

    debugPrint('📅 === END CALENDAR EVENT CREATION ===');
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
    _pulseController.dispose();
    _speech.stop();
    _tts.stop();
    _queueManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
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
        ),
        // Queue indicator floating badge
        const QueueIndicator(),
      ],
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
          if (_locationInfo.isNotEmpty || _locationName.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.gps_fixed, color: Colors.white70, size: 14),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    _locationInfo,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (_locationName.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.location_city, color: Colors.white70, size: 14),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      _locationStreet.isNotEmpty
                          ? '$_locationStreet, $_locationName'
                          : 'Locatie: $_locationName',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ],
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
