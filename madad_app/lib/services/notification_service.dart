import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'app_token.dart';

class NotificationService {
  static const String baseUrl =
      'https://gasp-test-production.up.railway.app/api/v1';

  Map<String, String> _headers() {
    final token = AppToken.get();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// PATCH /api/v1/users/me/fcm-token
  Future<void> updateFcmToken(String fcmToken) async {
    final res = await http.patch(
      Uri.parse('$baseUrl/users/me/fcm-token'),
      headers: _headers(),
      body: jsonEncode({'fcmToken': fcmToken}),
    );
    debugPrint('[Notif] FCM token PATCH ${res.statusCode} ${res.body}');
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      throw Exception(body['message'] ?? 'Error ${res.statusCode}');
    }
  }

  /// GET /api/v1/notifications?page=1&limit=20
  Future<Map<String, dynamic>> getNotifications({
    int page = 1,
    int limit = 20,
  }) async {
    final res = await http.get(
      Uri.parse('$baseUrl/notifications?page=$page&limit=$limit'),
      headers: _headers(),
    );
    debugPrint('[Notif] GET ${res.statusCode}');
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 200 && res.statusCode < 300) return body;
    throw Exception(body['message'] ?? 'Error ${res.statusCode}');
  }

  /// PATCH /api/v1/notifications/:id/read
  Future<void> markRead(String id) async {
    final res = await http.patch(
      Uri.parse('$baseUrl/notifications/$id/read'),
      headers: _headers(),
    );
    debugPrint('[Notif] markRead ${res.statusCode}');
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      throw Exception(body['message'] ?? 'Error ${res.statusCode}');
    }
  }

  /// PATCH /api/v1/notifications/read-all
  Future<void> markAllRead() async {
    final res = await http.patch(
      Uri.parse('$baseUrl/notifications/read-all'),
      headers: _headers(),
    );
    debugPrint('[Notif] markAllRead ${res.statusCode}');
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      throw Exception(body['message'] ?? 'Error ${res.statusCode}');
    }
  }

  /// PATCH /api/v1/users/me/location
  Future<void> updateLocation(double latitude, double longitude) async {
    final res = await http.patch(
      Uri.parse('$baseUrl/users/me/location'),
      headers: _headers(),
      body: jsonEncode({'latitude': latitude, 'longitude': longitude}),
    );
    debugPrint('[Notif] location PATCH ${res.statusCode}');
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      throw Exception(body['message'] ?? 'Error ${res.statusCode}');
    }
  }

  /// PATCH /api/v1/users/me/preferences
  /// Handles notification toggles AND preferred_categories
  Future<void> updatePreferences({
    bool? reservationRequested,
    bool? reservationAccepted,
    bool? reservationCancelled,
    bool? donationCompleted,
    bool? newMessages,
    List<String>? preferredCategories,
    int? notificationRadiusKm,
    bool? urgentOnly,
  }) async {
    final payload = <String, dynamic>{};
    if (reservationRequested != null)
      payload['reservationRequested'] = reservationRequested;
    if (reservationAccepted != null)
      payload['reservationAccepted'] = reservationAccepted;
    if (reservationCancelled != null)
      payload['reservationCancelled'] = reservationCancelled;
    if (donationCompleted != null)
      payload['donationCompleted'] = donationCompleted;
    if (newMessages != null)
      payload['newMessages'] = newMessages;
    if (preferredCategories != null)
      payload['preferred_categories'] = preferredCategories;
    if (notificationRadiusKm != null)
      payload['notification_radius_km'] = notificationRadiusKm;
    if (urgentOnly != null)
      payload['urgent_only'] = urgentOnly;

    final res = await http.patch(
      Uri.parse('$baseUrl/users/me/preferences'),
      headers: _headers(),
      body: jsonEncode(payload),
    );
    debugPrint(
        '[Notif] preferences PATCH ${res.statusCode} ${res.body}');
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      throw Exception(body['message'] ?? 'Error ${res.statusCode}');
    }
  }

  /// GET current user preferences (nested inside /users/me response)
  Future<Map<String, dynamic>> getPreferences() async {
    final res = await http.get(
      Uri.parse('$baseUrl/users/me'),
      headers: _headers(),
    );
    debugPrint('[Notif] getPreferences GET ${res.statusCode}');
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final user = body['data']?['user'] as Map<String, dynamic>?
          ?? body['data'] as Map<String, dynamic>?
          ?? {};
      return user['preferences'] as Map<String, dynamic>?
          ?? user['notificationPreferences'] as Map<String, dynamic>?
          ?? {};
    }
    throw Exception('Error ${res.statusCode}');
  }
}