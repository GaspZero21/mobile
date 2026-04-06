import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'app_token.dart';

class ChatService {
  static const String baseUrl =
      'https://gasp-test-production.up.railway.app/api/v1';

  Map<String, String> _headers() {
    final token = AppToken.get();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// GET /api/v1/chat/{reservationId}
  Future<Map<String, dynamic>> getChat(String reservationId) async {
    final res = await http.get(
      Uri.parse('$baseUrl/chat/$reservationId'),
      headers: _headers(),
    );
    debugPrint('[Chat] GET ${res.statusCode} ${res.body}');
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 200 && res.statusCode < 300) return body;
    throw Exception(body['message'] ?? 'Error ${res.statusCode}');
  }

  /// POST /api/v1/chat/{reservationId}/messages
  Future<void> sendMessage(String reservationId, String content) async {
    final res = await http.post(
      Uri.parse('$baseUrl/chat/$reservationId/messages'),
      headers: _headers(),
      body: jsonEncode({'content': content}),
    );
    debugPrint('[Chat] POST ${res.statusCode} ${res.body}');
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      throw Exception(body['message'] ?? 'Error ${res.statusCode}');
    }
  }
}