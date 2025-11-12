import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service voor communicatie met Claudine Server
class ClaudineApiService {
  // Server URL - gebruik laptop IP wanneer je vanaf telefoon test
  // Vind je laptop IP: Windows -> ipconfig (zoek WiFi adapter IPv4)
  static const String baseUrl = 'http://100.104.213.54:8001'; // WIJZIG NAAR JE LAPTOP IP!

  /// Get auth headers (JWT token) if user is logged in
  Future<Map<String, String>> _getAuthHeaders() async {
    try {
      final authHeaders = await Future(() async {
        // Import dynamically to avoid circular dependencies
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('claudine_jwt_token');
        if (token != null) {
          return {'Authorization': 'Bearer $token'};
        }
        return <String, String>{};
      });
      return authHeaders;
    } catch (e) {
      return {};
    }
  }

  /// Check of de server bereikbaar is
  Future<bool> checkHealth() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/health'),
      ).timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      print('Health check failed: $e');
      return false;
    }
  }

  /// Get server session info
  /// Returns session_id that changes on every server restart
  Future<Map<String, dynamic>?> getSessionInfo() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/session'),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      print('Get session info failed: $e');
      return null;
    }
  }

  /// Check if server session has changed (indicating server restart)
  /// Returns true if session changed and cache should be cleared
  Future<bool> checkSessionChanged() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedSessionId = prefs.getString('server_session_id');

      final sessionInfo = await getSessionInfo();
      if (sessionInfo == null) {
        return false; // Can't determine, don't clear cache
      }

      final currentSessionId = sessionInfo['session_id'] as String?;
      if (currentSessionId == null) {
        return false;
      }

      // First time checking or session changed
      if (savedSessionId == null) {
        // First time, save it
        await prefs.setString('server_session_id', currentSessionId);
        print('🆔 Saved server session ID: $currentSessionId');
        return false;
      }

      if (savedSessionId != currentSessionId) {
        // Session changed! Server was restarted
        print('🔄 Server session changed!');
        print('   Old: $savedSessionId');
        print('   New: $currentSessionId');

        // Update to new session ID
        await prefs.setString('server_session_id', currentSessionId);
        return true;
      }

      return false; // Session unchanged
    } catch (e) {
      print('Check session changed failed: $e');
      return false;
    }
  }

  /// Check of gebruiker is geauthenticeerd
  Future<Map<String, dynamic>?> getAuthInfo() async {
    try {
      // FIX: Add JWT auth headers for multi-user support
      final headers = await _getAuthHeaders();

      debugPrint('🔍 Checking auth at: $baseUrl/api/auth/info');
      debugPrint('🔐 Auth headers: ${headers.containsKey('Authorization') ? 'YES' : 'NO'}');

      final response = await http.get(
        Uri.parse('$baseUrl/api/auth/info'),
        headers: headers,
      ).timeout(const Duration(seconds: 5));

      debugPrint('📡 Auth response: ${response.statusCode}');
      debugPrint('📦 Auth body: ${response.body}');

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint('❌ Get auth info failed: $e');
      return null;
    }
  }

  /// Start Device Code Flow voor authenticatie (multi-user support)
  Future<Map<String, dynamic>?> startDeviceFlow(String provider) async {
    try {
      // FIX: Use new multi-user endpoint with JWT auth headers
      final headers = await _getAuthHeaders();

      debugPrint('🔐 Starting device flow for provider: $provider');
      debugPrint('🔐 Auth headers: ${headers.containsKey('Authorization') ? 'YES' : 'NO'}');

      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/device-flow/start?provider=$provider'),
        headers: headers,
      ).timeout(const Duration(seconds: 10));

      debugPrint('📡 Device flow start response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('✅ Device flow started: ${data['user_code']}');
        return data;
      }
      return null;
    } catch (e) {
      debugPrint('❌ Start device flow failed: $e');
      return null;
    }
  }

  /// Check of device flow autorisatie is voltooid (multi-user support)
  Future<Map<String, dynamic>?> checkAuthStatus(String deviceCode, String provider) async {
    try {
      // FIX: Use provider-specific endpoints with JWT auth headers
      final headers = await _getAuthHeaders();
      headers['Content-Type'] = 'application/json';

      // Provider-specific endpoints
      final endpoint = provider == 'google'
          ? '$baseUrl/api/auth/google/status'
          : '$baseUrl/api/auth/status';

      debugPrint('📡 Polling auth status for $provider: $endpoint');

      final response = await http.post(
        Uri.parse(endpoint),
        headers: headers,
        body: json.encode({'device_code': deviceCode}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint('❌ Check auth status failed: $e');
      return null;
    }
  }

  /// Logout (verwijder tokens)
  Future<bool> logout() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/logout'),
      ).timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      print('Logout failed: $e');
      return false;
    }
  }

  /// Haal beschikbare kalenders op
  Future<List<dynamic>?> getCalendars() async {
    try {
      // FIX: Add auth headers for multi-user support
      final headers = await _getAuthHeaders();

      final response = await http.get(
        Uri.parse('$baseUrl/api/calendar/calendars'),
        headers: headers,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['calendars'];
      }
      return null;
    } catch (e) {
      print('Get calendars failed: $e');
      return null;
    }
  }

  /// Maak een calendar event aan
  Future<Map<String, dynamic>?> createEvent({
    required String title,
    required DateTime start,
    DateTime? end,
    String? description,
    String? location,
    String? provider,  // 'o365' or 'google' (optional, auto-detect if not specified)
  }) async {
    try {
      final payload = {
        'title': title,
        'start': start.toIso8601String(),
        if (end != null) 'end': end.toIso8601String(),
        if (description != null) 'description': description,
        if (location != null) 'location': location,
      };

      // Build URL with optional provider query parameter
      String url = '$baseUrl/api/calendar/create';
      if (provider != null && provider.isNotEmpty) {
        url += '?provider=$provider';
      }

      debugPrint('🌐 Sending to: $url');
      debugPrint('🌐 Provider: ${provider ?? "auto-detect"}');
      debugPrint('🌐 Payload: ${json.encode(payload)}');

      // Get auth headers
      Map<String, String> headers = {'Content-Type': 'application/json'};
      try {
        final authHeaders = await _getAuthHeaders();
        headers.addAll(authHeaders);
        debugPrint('🔐 Auth headers added');
      } catch (e) {
        debugPrint('⚠️ No auth headers available: $e');
      }

      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: json.encode(payload),
      ).timeout(const Duration(seconds: 15));

      debugPrint('🌐 Response status: ${response.statusCode}');
      debugPrint('🌐 Response body: ${response.body}');

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        debugPrint('❌ Create event failed: ${response.statusCode}');
        debugPrint('❌ Error body: ${response.body}');
        return {
          'success': false,
          'error': 'Server returned ${response.statusCode}',
          'details': response.body
        };
      }
    } catch (e) {
      debugPrint('❌ Create event exception: $e');
      return {
        'success': false,
        'error': 'Exception: $e'
      };
    }
  }

  /// Verwerk natuurlijke taal opdracht (experimental)
  /// Dit stuurt de ruwe tekst naar de server voor verwerking
  Future<Map<String, dynamic>?> createEventFromVoice(
    String command, {
    String? location,
  }) async {
    try {
      // Get auth headers if available
      Map<String, String> headers = {'Content-Type': 'application/json'};
      try {
        final authHeaders = await _getAuthHeaders();
        headers.addAll(authHeaders);
      } catch (e) {
        debugPrint('⚠️ No auth headers available (backward compat mode)');
      }

      final requestBody = {
        'command': command,
        if (location != null) 'location': location,
      };

      debugPrint('🌐 Sending to: $baseUrl/api/calendar/create-from-voice');
      debugPrint('🔑 Auth headers: ${headers.containsKey('Authorization') ? 'YES' : 'NO'}');
      debugPrint('📝 Command: $command');

      final response = await http.post(
        Uri.parse('$baseUrl/api/calendar/create-from-voice'),
        headers: headers,
        body: json.encode(requestBody),
      ).timeout(const Duration(seconds: 20));

      debugPrint('📡 Response status: ${response.statusCode}');
      debugPrint('📦 Response body: ${response.body}');

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        // Return error details
        try {
          final errorData = json.decode(response.body);
          return {
            'success': false,
            'error': errorData['detail'] ?? 'Unknown error',
            'status_code': response.statusCode
          };
        } catch (e) {
          return {
            'success': false,
            'error': 'Server returned ${response.statusCode}',
            'status_code': response.statusCode
          };
        }
      }
    } catch (e) {
      debugPrint('❌ Create from voice exception: $e');
      return {
        'success': false,
        'error': 'Exception: $e'
      };
    }
  }

  /// Set primary calendar provider
  Future<bool> setPrimaryProvider(String provider) async {
    try {
      debugPrint('⭐ Setting primary provider to: $provider');

      // Get auth headers (CRITICAL FIX - was missing!)
      final headers = await _getAuthHeaders();
      headers['Content-Type'] = 'application/json';

      debugPrint('🔐 Auth headers: ${headers.containsKey('Authorization') ? 'YES' : 'NO'}');

      // FIX: Use path parameter instead of body (server expects path param!)
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/set-primary/$provider'),
        headers: headers,
      ).timeout(const Duration(seconds: 10));

      debugPrint('📡 Set primary response: ${response.statusCode}');
      debugPrint('📦 Response body: ${response.body}');

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('❌ Set primary provider failed: $e');
      return false;
    }
  }

  /// Get current user info (including login provider)
  Future<Map<String, dynamic>?> getCurrentUser() async {
    try {
      debugPrint('👤 Getting current user info...');
      final authHeaders = await _getAuthHeaders();
      if (authHeaders.isEmpty) {
        debugPrint('⚠️ No auth headers - user not logged in');
        return null; // Not logged in
      }

      debugPrint('📡 Calling /api/auth/user/me...');
      final response = await http.get(
        Uri.parse('$baseUrl/api/auth/user/me'),
        headers: authHeaders,
      ).timeout(const Duration(seconds: 5));

      debugPrint('📡 User/me response: ${response.statusCode}');
      debugPrint('📦 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('✅ Got user info: provider=${data['provider']}, email=${data['email']}');
        return data;
      }
      debugPrint('⚠️ User/me returned ${response.statusCode}');
      return null;
    } catch (e) {
      debugPrint('❌ Get current user failed: $e');
      return null;
    }
  }
}
