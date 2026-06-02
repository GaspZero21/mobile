import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'app_token.dart';

class UserService {
  static const String baseUrl =
      'https://gasp-test-production.up.railway.app/api/v1';

  Map<String, String> _headers() {
    final token = AppToken.get();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// PATCH /api/v1/users/me/location
  Future<void> updateLocation({
    required double latitude,
    required double longitude,
  }) async {
    final res = await http.patch(
      Uri.parse('$baseUrl/users/me/location'),
      headers: _headers(),
      body: jsonEncode({'latitude': latitude, 'longitude': longitude}),
    );
    debugPrint('[UserService] updateLocation → ${res.statusCode}');
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      throw Exception(body['message'] ?? 'Failed to update location');
    }
  }
  // Add these methods to UserService class

  /// POST /api/v1/users/me/roles
  Future<void> addRole(String role) async {
    final res = await http.post(
      Uri.parse('$baseUrl/users/me/roles'),
      headers: _headers(),
      body: jsonEncode({'role': role.toUpperCase()}),
    );
    debugPrint('[UserService] addRole $role → ${res.statusCode}');
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final body = jsonDecode(res.body) as Map<String, dynamic>?;
      throw Exception(body?['message'] ?? 'Failed to add role');
    }
  }

  /// DELETE /api/v1/users/me/roles
  Future<void> removeRole(String role) async {
    final res = await http.delete(
      Uri.parse('$baseUrl/users/me/roles'),
      headers: _headers(),
      body: jsonEncode({'role': role.toUpperCase()}),
    );
    debugPrint('[UserService] removeRole $role → ${res.statusCode}');
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final body = jsonDecode(res.body) as Map<String, dynamic>?;
      throw Exception(body?['message'] ?? 'Failed to remove role');
    }
  }
  /// POST /api/v1/users/{id}/report
  Future<void> reportUser({
    required String userId,
    required String reason,
    String? details,
  }) async {
    final body = <String, dynamic>{'reason': reason};
    if (details != null && details.isNotEmpty) body['details'] = details;

    final res = await http.post(
      Uri.parse('$baseUrl/users/$userId/report'),
      headers: _headers(),
      body: jsonEncode(body),
    );
    debugPrint('[UserService] reportUser $userId → ${res.statusCode}');
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final resBody = jsonDecode(res.body) as Map<String, dynamic>;
      throw Exception(resBody['message'] ?? 'Failed to report user');
    }
  }
}