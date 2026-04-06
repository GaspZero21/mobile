import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'app_token.dart';

class DonationService {
  static const String baseUrl =
      "https://gasp-test-production.up.railway.app/api/v1";

  // ── Headers ──────────────────────────────────────────────────────────────────

  Map<String, String> _authHeaders() {
    final token = AppToken.get();
    debugPrint(
      '[Donation] token = ${token == null ? "null ❌" : "${token.substring(0, 20)}... ✅"}',
    );
    return {
      "Content-Type": "application/json",
      if (token != null) "Authorization": "Bearer $token",
    };
  }

  // ── Ensure DONATOR role + fresh token ────────────────────────────────────────

  Future<void> _ensureDonatorRole() async {
    final token = AppToken.get();
    if (token == null) return;

    final headers = {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    };

    // 1. Assign DONATOR role (409 = already has it, that's fine)
    final roleRes = await http.post(
      Uri.parse("$baseUrl/users/me/roles"),
      headers: headers,
      body: jsonEncode({"role": "DONATOR"}),
    );
    debugPrint('[Role] ${roleRes.statusCode} ${roleRes.body}');

    // 2. Refresh token so new role is included in JWT claims
    final refreshRes = await http.post(
      Uri.parse("$baseUrl/auth/refresh"),
      headers: headers,
    );
    debugPrint('[Refresh] ${refreshRes.statusCode} ${refreshRes.body}');

    if (refreshRes.statusCode >= 200 && refreshRes.statusCode < 300) {
      final data = jsonDecode(refreshRes.body) as Map<String, dynamic>;
      final newToken =
          data['data']?['accessToken'] as String? ??
          data['data']?['token'] as String? ??
          data['accessToken'] as String?;
      if (newToken != null && newToken.isNotEmpty) {
        AppToken.set(newToken);
        debugPrint('[Refresh] ✅ Token refreshed with DONATOR role');
      }
    }
  }

  // ── GET all donations ─────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getDonations() async {
    final response = await http.get(
      Uri.parse("$baseUrl/donations"),
      headers: _authHeaders(),
    );
    return _handleList(response);
  }

  // ── POST create donation ──────────────────────────────────────────────────────

  Future<Map<String, dynamic>> createDonation({
    required String title,
    required String category,
    required String quantity, // ← String e.g. "5 kg", "3 pièces"
    required String pickupAddress,
    required String pickupType,
    File? photoFile,
    Uint8List? photoBytes,
    String? photoName,
    String? description,
    bool isUrgent = false,
    String? expiresAt,
    double? latitude,
    double? longitude,
  }) async {
    assert(
      photoFile != null || photoBytes != null,
      'Provide photoFile (mobile) or photoBytes (web)',
    );

    // Ensure DONATOR role and refresh token BEFORE the POST
    await _ensureDonatorRole();

    final token = AppToken.get();
    final uri = Uri.parse("$baseUrl/donations");
    final request = http.MultipartRequest('POST', uri);

    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    request.fields['title'] = title;
    request.fields['category'] = category;
    request.fields['quantity'] = quantity;
    request.fields['pickupAddress'] = pickupAddress;
    request.fields['pickupType'] = pickupType;
    request.fields['isUrgent'] = isUrgent.toString();

    if (description != null && description.isNotEmpty) {
      request.fields['description'] = description;
    }
    if (expiresAt != null) request.fields['expiresAt'] = expiresAt;
    if (latitude != null) request.fields['latitude'] = latitude.toString();
    if (longitude != null) request.fields['longitude'] = longitude.toString();

    if (photoBytes != null) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'photo',
          photoBytes,
          filename: photoName ?? 'photo.jpg',
        ),
      );
    } else if (photoFile != null) {
      request.files.add(
        await http.MultipartFile.fromPath('photo', photoFile.path),
      );
    }

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    return _handleMap(response);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────

  List<Map<String, dynamic>> _handleList(http.Response response) {
    debugPrint('[Donation] GET ${response.statusCode} ${response.body}');
    final body = jsonDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (body is List) return List<Map<String, dynamic>>.from(body);
      final data = body['data'];
      if (data is List) return List<Map<String, dynamic>>.from(data);
      if (data is Map && data['donations'] is List) {
        return List<Map<String, dynamic>>.from(data['donations']);
      }
      return [];
    }
    throw Exception(body["message"] ?? "Server error ${response.statusCode}");
  }

  Map<String, dynamic> _handleMap(http.Response response) {
    debugPrint('[Donation] POST ${response.statusCode} ${response.body}');
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 200 && response.statusCode < 300) return body;
    throw Exception(body["message"] ?? "Server error ${response.statusCode}");
  }
}
