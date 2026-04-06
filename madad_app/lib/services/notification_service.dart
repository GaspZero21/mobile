import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'app_token.dart';

class NotificationService {
  static const String baseUrl =
      "https://gasp-test-production.up.railway.app/api/v1";

  Map<String, String> _headers() {
    final token = AppToken.get();
    return {
      "Content-Type": "application/json",
      if (token != null) "Authorization": "Bearer $token",
    };
  }

  /// GET /api/v1/notifications
  Future<Map<String, dynamic>> getNotifications({
    int page = 1,
    int limit = 20,
  }) async {
    final uri = Uri.parse("$baseUrl/notifications?page=$page&limit=$limit");
    final response = await http.get(uri, headers: _headers());
    return _handle(response);
  }

  /// PATCH /api/v1/notifications/read-all
  Future<void> markAllRead() async {
    await http.patch(
      Uri.parse("$baseUrl/notifications/read-all"),
      headers: _headers(),
    );
  }

  /// PATCH /api/v1/notifications/{id}/read
  Future<void> markRead(String id) async {
    await http.patch(
      Uri.parse("$baseUrl/notifications/$id/read"),
      headers: _headers(),
    );
  }

  Map<String, dynamic> _handle(http.Response response) {
    debugPrint('[Notif] ${response.statusCode} ${response.body}');
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 200 && response.statusCode < 300) return body;
    throw Exception(body["message"] ?? "Server error");
  }
}