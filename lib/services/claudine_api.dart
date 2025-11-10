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

  /// Check of gebruiker is geauthenticeerd
  Future<Map<String, dynamic>?> getAuthInfo() async {
    try {
      print('🔍 Checking auth at: $baseUrl/api/auth/info');
      final response = await http.get(
        Uri.parse('$baseUrl/api/auth/info'),
      ).timeout(const Duration(seconds: 5));

      print('📡 Auth response: ${response.statusCode}');
      print('📦 Auth body: ${response.body}');

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      print('❌ Get auth info failed: $e');
      return null;
    }
  }

  /// Start Device Code Flow voor authenticatie
  Future<Map<String, dynamic>?> startDeviceFlow() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/start'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      print('Start device flow failed: $e');
      return null;
    }
  }

  /// Check of device flow autorisatie is voltooid
  Future<Map<String, dynamic>?> checkAuthStatus(String deviceCode) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/status'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'device_code': deviceCode}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      print('Check auth status failed: $e');
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
      final response = await http.get(
        Uri.parse('$baseUrl/api/calendar/calendars'),
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

      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
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

      final response = await http.post(
        Uri.parse('$baseUrl/api/calendar/create-from-voice'),
        headers: headers,
        body: json.encode(requestBody),
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      print('Create from voice failed: $e');
      return null;
    }
  }

  /// Set primary calendar provider
  Future<bool> setPrimaryProvider(String provider) async {
    try {
      debugPrint('⭐ Setting primary provider to: $provider');
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/set-primary'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'provider': provider}),
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
      final authHeaders = await _getAuthHeaders();
      if (authHeaders.isEmpty) {
        return null; // Not logged in
      }

      final response = await http.get(
        Uri.parse('$baseUrl/api/auth/user/me'),
        headers: authHeaders,
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint('❌ Get current user failed: $e');
      return null;
    }
  }
}
