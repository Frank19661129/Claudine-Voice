import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:aad_oauth/aad_oauth.dart';
import 'package:aad_oauth/model/config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Authentication service for Google and Microsoft OAuth and JWT management
class AuthService {
  static const String _jwtTokenKey = 'claudine_jwt_token';
  static const String _userIdKey = 'claudine_user_id';
  static const String _userEmailKey = 'claudine_user_email';
  static const String _userNameKey = 'claudine_user_name';

  // Google Sign-In with Web Client ID from .env
  late final GoogleSignIn _googleSignIn;

  // Microsoft Azure AD OAuth - initialized lazily
  AadOAuth? _msOAuth;

  AuthService() {
    // Initialize GoogleSignIn with serverClientId from .env
    final webClientId = dotenv.env['GOOGLE_OAUTH_WEB_CLIENT_ID'];
    if (webClientId == null || webClientId.isEmpty) {
      debugPrint('⚠️ GOOGLE_OAUTH_WEB_CLIENT_ID not found in .env');
    }

    _googleSignIn = GoogleSignIn(
      scopes: ['email', 'profile'],
      serverClientId: webClientId,
    );
  }

  /// Initialize Microsoft OAuth with a navigator key
  void _initMsOAuth(GlobalKey<NavigatorState> navigatorKey) {
    if (_msOAuth != null) return; // Already initialized

    final msClientId = dotenv.env['MS_OAUTH_CLIENT_ID'];
    final msTenantId = dotenv.env['MS_OAUTH_TENANT_ID'];
    final msRedirectUri = dotenv.env['MS_OAUTH_REDIRECT_URI'];

    if (msClientId == null || msTenantId == null || msRedirectUri == null) {
      debugPrint('⚠️ Microsoft OAuth credentials not found in .env');
    }

    final msConfig = Config(
      tenant: msTenantId ?? '',
      clientId: msClientId ?? '',
      scope: 'openid profile email offline_access',
      redirectUri: msRedirectUri ?? 'msauth://com.claudine.voice/auth',
      navigatorKey: navigatorKey,
    );

    _msOAuth = AadOAuth(msConfig);
  }

  String? _jwtToken;
  String? _userId;
  String? _userEmail;
  String? _userName;

  /// Check if user is logged in
  Future<bool> isLoggedIn() async {
    if (_jwtToken != null) return true;

    final prefs = await SharedPreferences.getInstance();
    _jwtToken = prefs.getString(_jwtTokenKey);
    _userId = prefs.getString(_userIdKey);
    _userEmail = prefs.getString(_userEmailKey);
    _userName = prefs.getString(_userNameKey);

    return _jwtToken != null;
  }

  /// Get current JWT token
  String? get jwtToken => _jwtToken;

  /// Get current user ID
  String? get userId => _userId;

  /// Get current user email
  String? get userEmail => _userEmail;

  /// Get current user name
  String? get userName => _userName;

  /// Login with Google
  Future<Map<String, dynamic>> loginWithGoogle(String serverUrl) async {
    try {
      debugPrint('🔐 Starting Google Sign-In...');

      // Sign in with Google
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        return {'success': false, 'error': 'Google sign-in cancelled'};
      }

      debugPrint('✅ Google user: ${googleUser.email}');

      // Get authentication details
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final String? idToken = googleAuth.idToken;

      if (idToken == null) {
        return {'success': false, 'error': 'Failed to get Google ID token'};
      }

      debugPrint('📝 Got Google ID token, sending to server...');

      // Send to backend for verification and JWT generation
      final response = await http.post(
        Uri.parse('$serverUrl/api/auth/user/login/google'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'id_token': idToken}),
      );

      debugPrint('📡 Server response: ${response.statusCode}');
      debugPrint('📦 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Store JWT token and user info
        _jwtToken = data['jwt_token'];
        _userId = data['user_id'];
        _userEmail = data['email'];
        _userName = data['display_name'];

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_jwtTokenKey, _jwtToken!);
        await prefs.setString(_userIdKey, _userId!);
        await prefs.setString(_userEmailKey, _userEmail!);
        await prefs.setString(_userNameKey, _userName!);

        debugPrint('✅ Login successful: $_userName ($_userEmail)');

        return {
          'success': true,
          'user_id': _userId,
          'email': _userEmail,
          'name': _userName,
        };
      } else {
        return {
          'success': false,
          'error': 'Server error: ${response.statusCode}'
        };
      }
    } catch (e) {
      debugPrint('❌ Google login error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Login with Microsoft
  Future<Map<String, dynamic>> loginWithMicrosoft(
    String serverUrl,
    GlobalKey<NavigatorState> navigatorKey,
  ) async {
    try {
      debugPrint('🔐 Starting Microsoft Sign-In...');

      // Initialize Microsoft OAuth if not already done
      _initMsOAuth(navigatorKey);

      if (_msOAuth == null) {
        return {'success': false, 'error': 'Failed to initialize Microsoft OAuth'};
      }

      // Sign in with Microsoft
      await _msOAuth!.login();

      // Get the access token
      final String? accessToken = await _msOAuth!.getAccessToken();

      if (accessToken == null) {
        return {'success': false, 'error': 'Microsoft sign-in cancelled or failed'};
      }

      debugPrint('✅ Got Microsoft access token');

      // Get ID token if available
      final String? idToken = await _msOAuth!.getIdToken();

      if (idToken == null) {
        return {'success': false, 'error': 'Failed to get Microsoft ID token'};
      }

      debugPrint('📝 Got Microsoft ID token, sending to server...');

      // Send to backend for verification and JWT generation
      final response = await http.post(
        Uri.parse('$serverUrl/api/auth/user/login/microsoft'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'id_token': idToken,
          'access_token': accessToken,
        }),
      );

      debugPrint('📡 Server response: ${response.statusCode}');
      debugPrint('📦 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Store JWT token and user info
        _jwtToken = data['jwt_token'];
        _userId = data['user_id'];
        _userEmail = data['email'];
        _userName = data['display_name'];

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_jwtTokenKey, _jwtToken!);
        await prefs.setString(_userIdKey, _userId!);
        await prefs.setString(_userEmailKey, _userEmail!);
        await prefs.setString(_userNameKey, _userName!);

        debugPrint('✅ Login successful: $_userName ($_userEmail)');

        return {
          'success': true,
          'user_id': _userId,
          'email': _userEmail,
          'name': _userName,
        };
      } else {
        return {
          'success': false,
          'error': 'Server error: ${response.statusCode}'
        };
      }
    } catch (e) {
      debugPrint('❌ Microsoft login error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Logout
  Future<void> logout() async {
    try {
      await _googleSignIn.signOut();
    } catch (e) {
      debugPrint('Error signing out from Google: $e');
    }

    if (_msOAuth != null) {
      try {
        await _msOAuth!.logout();
      } catch (e) {
        debugPrint('Error signing out from Microsoft: $e');
      }
    }

    _jwtToken = null;
    _userId = null;
    _userEmail = null;
    _userName = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_jwtTokenKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_userEmailKey);
    await prefs.remove(_userNameKey);

    debugPrint('✅ Logged out');
  }

  /// Get Authorization header for API calls
  Map<String, String> getAuthHeaders() {
    if (_jwtToken == null) return {};
    return {'Authorization': 'Bearer $_jwtToken'};
  }
}

/// Singleton instance
final authService = AuthService();
