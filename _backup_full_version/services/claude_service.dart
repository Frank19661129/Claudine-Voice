import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Claude AI conversation service
/// Handles natural conversation with Claude 3.5 Sonnet
/// Optimized for voice interactions (low latency, streaming)
class ClaudeService {
  static const String _baseUrl = 'https://api.anthropic.com/v1';
  final String _apiKey;

  // Conversation context
  final List<Map<String, String>> _conversationHistory = [];
  final int _maxHistoryLength = 10; // Keep last 10 messages for context

  // System prompt for Claudine personality
  final String _systemPrompt = '''
Je bent Claudine, een vriendelijke en behulpzame persoonlijke assistent.

Persoonlijkheid:
- Warm en toegankelijk, spreek Nederlands
- Kort en to-the-point (dit is een spraak conversatie)
- Proactief: stel vragen als iets onduidelijk is
- Herinner de gebruiker aan dingen die ze eerder hebben gezegd

Voice conversatie regels:
- Houd antwoorden kort (max 2-3 zinnen tenzij expliciet gevraagd)
- Gebruik geen markdown of speciale formatting
- Spreek in natuurlijke spreektaal
- Bij taken: bevestig wat je gaat doen

Voorbeelden:
User: "Herinner me aan melk kopen"
Claudine: "Natuurlijk! Wanneer wil je dat ik je herinner?"

User: "Rond 18 uur"
Claudine: "Oké, ik zet een reminder voor vandaag 18:00. Nog iets anders?"
''';

  ClaudeService(this._apiKey);

  /// Send message to Claude and get response
  /// Returns streaming response for low latency
  Future<String> sendMessage(String userMessage) async {
    try {
      // Add user message to history
      _conversationHistory.add({
        'role': 'user',
        'content': userMessage,
      });

      // Trim history if too long
      if (_conversationHistory.length > _maxHistoryLength * 2) {
        _conversationHistory.removeRange(0, 2); // Remove oldest exchange
      }

      // Call Claude API
      final response = await http.post(
        Uri.parse('$_baseUrl/messages'),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': _apiKey,
          'anthropic-version': '2023-06-01',
        },
        body: jsonEncode({
          'model': 'claude-3-5-sonnet-20241022',
          'max_tokens': 150, // Short responses for voice
          'system': _systemPrompt,
          'messages': _conversationHistory,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Claude API error: ${response.statusCode} ${response.body}');
      }

      final data = jsonDecode(response.body);
      final assistantMessage = data['content'][0]['text'] as String;

      // Add assistant response to history
      _conversationHistory.add({
        'role': 'assistant',
        'content': assistantMessage,
      });

      debugPrint('💬 Claude: $assistantMessage');
      return assistantMessage;
    } catch (e) {
      debugPrint('❌ Claude API error: $e');
      rethrow;
    }
  }

  /// Streaming version (for future use - better UX)
  Stream<String> sendMessageStreaming(String userMessage) async* {
    try {
      _conversationHistory.add({
        'role': 'user',
        'content': userMessage,
      });

      final request = http.Request(
        'POST',
        Uri.parse('$_baseUrl/messages'),
      );

      request.headers.addAll({
        'Content-Type': 'application/json',
        'x-api-key': _apiKey,
        'anthropic-version': '2023-06-01',
      });

      request.body = jsonEncode({
        'model': 'claude-3-5-sonnet-20241022',
        'max_tokens': 150,
        'system': _systemPrompt,
        'messages': _conversationHistory,
        'stream': true,
      });

      final streamedResponse = await request.send();

      if (streamedResponse.statusCode != 200) {
        throw Exception('Claude API streaming error: ${streamedResponse.statusCode}');
      }

      final fullResponse = StringBuffer();

      await for (final chunk in streamedResponse.stream.transform(utf8.decoder)) {
        // Parse SSE format
        final lines = chunk.split('\n');
        for (final line in lines) {
          if (line.startsWith('data: ')) {
            final jsonStr = line.substring(6);
            if (jsonStr == '[DONE]') continue;

            try {
              final data = jsonDecode(jsonStr);
              if (data['type'] == 'content_block_delta') {
                final text = data['delta']['text'] as String;
                fullResponse.write(text);
                yield text;
              }
            } catch (_) {}
          }
        }
      }

      // Add complete response to history
      _conversationHistory.add({
        'role': 'assistant',
        'content': fullResponse.toString(),
      });
    } catch (e) {
      debugPrint('❌ Claude streaming error: $e');
      rethrow;
    }
  }

  /// Reset conversation context
  void clearHistory() {
    _conversationHistory.clear();
    debugPrint('🧹 Conversation history cleared');
  }

  /// Get conversation summary (for debugging/logging)
  String get conversationSummary {
    return _conversationHistory
        .map((msg) => '${msg['role']}: ${msg['content']}')
        .join('\n');
  }

  int get messageCount => _conversationHistory.length;
}
