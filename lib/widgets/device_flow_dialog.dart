import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/claudine_api.dart';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';

/// Dialog for OAuth Device Flow authentication
class DeviceFlowDialog extends StatefulWidget {
  final String provider; // 'o365' or 'google'
  final ClaudineApiService api;

  const DeviceFlowDialog({
    super.key,
    required this.provider,
    required this.api,
  });

  @override
  State<DeviceFlowDialog> createState() => _DeviceFlowDialogState();
}

class _DeviceFlowDialogState extends State<DeviceFlowDialog> {
  bool _isLoading = true;
  bool _isPolling = false;
  bool _isSuccess = false;
  String? _userCode;
  String? _verificationUrl;
  String? _deviceCode;
  String? _errorMessage;
  int _expiresIn = 0;
  Timer? _pollTimer;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _startDeviceFlow();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _startDeviceFlow() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // FIX: Pass provider parameter to support multi-user calendar auth
      final result = await widget.api.startDeviceFlow(widget.provider);

      if (result != null && mounted) {
        setState(() {
          _userCode = result['user_code'];
          // Handle both 'verification_uri' and 'verification_url' keys
          _verificationUrl = result['verification_uri'] ?? result['verification_url'];
          _deviceCode = result['device_code'];
          _expiresIn = result['expires_in'] ?? 900;
          _isLoading = false;
        });

        // Start polling for authorization
        _startPolling();

        // Start countdown timer
        _startCountdown();
      } else {
        setState(() {
          _errorMessage = 'Failed to start device flow';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _startPolling() {
    _isPolling = true;

    // Poll every 5 seconds
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (!_isPolling || _deviceCode == null) {
        timer.cancel();
        return;
      }

      try {
        // FIX: Pass provider parameter for multi-user support
        final result = await widget.api.checkAuthStatus(_deviceCode!, widget.provider);

        if (result != null && result['success'] == true) {
          // Success!
          timer.cancel();
          if (mounted) {
            setState(() {
              _isSuccess = true;
              _isPolling = false;
            });

            // Close dialog after a moment
            await Future.delayed(const Duration(seconds: 2));
            if (mounted) {
              Navigator.of(context).pop(true); // Return success
            }
          }
        } else if (result != null && result['error'] != null && result['error'] != 'authorization_pending') {
          // Real error (not just "still waiting")
          timer.cancel();
          if (mounted) {
            setState(() {
              _errorMessage = result['message'] ?? 'Authentication failed';
              _isPolling = false;
            });
          }
        }
        // If authorization_pending, keep polling
      } catch (e) {
        // Network error, keep trying
        debugPrint('Poll error: $e');
      }
    });
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _expiresIn--;
      });

      if (_expiresIn <= 0) {
        timer.cancel();
        _pollTimer?.cancel();
        setState(() {
          _errorMessage = 'Code expired. Please try again.';
          _isPolling = false;
        });
      }
    });
  }

  Future<void> _openUrl() async {
    if (_verificationUrl != null) {
      try {
        final uri = Uri.parse(_verificationUrl!);
        debugPrint('🌐 Opening URL: $_verificationUrl');

        // Try to launch URL directly - don't check canLaunchUrl first as it's unreliable
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );

        if (!launched) {
          debugPrint('❌ Failed to launch URL');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Could not open browser. Please visit: $_verificationUrl'),
                duration: const Duration(seconds: 5),
              ),
            );
          }
        } else {
          debugPrint('✅ Browser opened successfully');
        }
      } catch (e) {
        debugPrint('❌ Error opening URL: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error opening browser: $e'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    }
  }

  void _copyCode() {
    if (_userCode != null) {
      Clipboard.setData(ClipboardData(text: _userCode!));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Code copied to clipboard'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final providerName = widget.provider == 'o365' ? 'Microsoft 365' : 'Google';

    return WillPopScope(
      onWillPop: () async {
        // Cancel polling when dialog is closed
        _pollTimer?.cancel();
        _countdownTimer?.cancel();
        return true;
      },
      child: AlertDialog(
        title: Text('Login to $providerName Calendar'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isLoading) ...[
                const Center(
                  child: CircularProgressIndicator(),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Starting authentication...',
                  textAlign: TextAlign.center,
                ),
              ] else if (_isSuccess) ...[
                const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 64,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Authentication successful!',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ] else if (_errorMessage != null) ...[
                const Icon(
                  Icons.error,
                  color: Colors.red,
                  size: 64,
                ),
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ] else ...[
                const Text(
                  'To authorize calendar access:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                // Step 1
                const Text('1. Click "Open Browser" below'),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _openUrl,
                  icon: const Icon(Icons.open_in_browser),
                  label: const Text('Open Browser'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
                const SizedBox(height: 16),

                // Step 2
                const Text('2. Enter this code:'),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _userCode ?? '',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                          fontFamily: 'monospace',
                        ),
                      ),
                      IconButton(
                        onPressed: _copyCode,
                        icon: const Icon(Icons.copy),
                        tooltip: 'Copy code',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Countdown
                if (_isPolling)
                  Text(
                    'Waiting for authorization... (${_formatTime(_expiresIn)})',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
              ],
            ],
          ),
        ),
        actions: [
          if (!_isLoading && !_isSuccess && _errorMessage == null) ...[
            TextButton(
              onPressed: () {
                _pollTimer?.cancel();
                _countdownTimer?.cancel();
                Navigator.of(context).pop(false);
              },
              child: const Text('Cancel'),
            ),
          ],
          if (_errorMessage != null) ...[
            TextButton(
              onPressed: () => _startDeviceFlow(),
              child: const Text('Retry'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Close'),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }
}
