import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'app_token.dart';

class DonationService {
  static const String baseUrl =
      'https://gasp-test-production.up.railway.app/api/v1';

  Map<String, String> _headers() {
    final token = AppToken.get();
    debugPrint(
      '[Donation] token = ${token == null ? "null ❌" : "${token.substring(0, 20)}... ✅"}',
    );
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<void> _ensureDonatorRole() async {
    final token = AppToken.get();
    final refreshToken = AppToken.getRefreshToken();
    if (token == null) return;
    if (refreshToken == null) {
      debugPrint('[Role] ❌ No refresh token');
      return;
    }
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
    final roleRes = await http.post(
      Uri.parse('$baseUrl/users/me/roles'),
      headers: headers,
      body: jsonEncode({'role': 'DONATOR'}),
    );
    debugPrint('[Role] ${roleRes.statusCode} ${roleRes.body}');
    final refreshRes = await http.post(
      Uri.parse('$baseUrl/auth/refresh'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refreshToken': refreshToken}),
    );
    debugPrint('[Refresh] ${refreshRes.statusCode} ${refreshRes.body}');
    if (refreshRes.statusCode >= 200 && refreshRes.statusCode < 300) {
      final data = jsonDecode(refreshRes.body) as Map<String, dynamic>;
      final newAccess = data['data']?['accessToken'] as String? ??
          data['data']?['token'] as String? ??
          data['accessToken'] as String?;
      final newRefresh = data['data']?['refreshToken'] as String? ??
          data['refreshToken'] as String?;
      if (newAccess != null && newAccess.isNotEmpty) {
        await AppToken.set(newAccess);
        debugPrint('[Refresh] ✅ Access token refreshed');
      }
      if (newRefresh != null && newRefresh.isNotEmpty) {
        await AppToken.setRefreshToken(newRefresh);
        debugPrint('[Refresh] ✅ Refresh token updated');
      }
    }
  }

  // ── GET all donations with optional filters ───────────────────────────────
  Future<List<Map<String, dynamic>>> getDonations({
    String? category,
    bool?   isUrgent,
    String? pickupType,
    double? lat,
    double? lng,
    double? radius,
    int?    page,
    int?    limit,
  }) async {
    final params = <String, String>{};
    if (category   != null && category.isNotEmpty)   params['category']   = category;
    if (isUrgent   != null)                           params['isUrgent']   = isUrgent.toString();
    if (pickupType != null && pickupType.isNotEmpty)  params['pickupType'] = pickupType;
    if (lat    != null) params['lat']    = lat.toString();
    if (lng    != null) params['lng']    = lng.toString();
    if (radius != null) params['radius'] = radius.toString();
    if (page   != null) params['page']   = page.toString();
    if (limit  != null) params['limit']  = limit.toString();

    final uri = Uri.parse('$baseUrl/donations')
        .replace(queryParameters: params.isEmpty ? null : params);
    debugPrint('[Donation] getDonations → $uri');

    final res = await http.get(uri, headers: _headers());
    debugPrint('[Donation] getDonations ${res.statusCode}');
    return _handleList(res);
  }

  // ── GET single donation ───────────────────────────────────────────────────
  Future<Map<String, dynamic>> getDonationById(String id) async {
    final res = await http.get(
      Uri.parse('$baseUrl/donations/$id'),
      headers: _headers(),
    );
    debugPrint('[Donation] getDonationById $id → ${res.statusCode}');
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final data = body['data']?['donation'] ??
          body['data']?['data'] ??
          body['data'] ??
          body['donation'];
      if (data is Map<String, dynamic>) return data;
      if (body.containsKey('title') || body.containsKey('_id')) return body;
    }
    throw Exception(body['message'] ?? 'Failed to load donation');
  }

  // ── GET my donations ──────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getMyDonations() async {
    final res = await http.get(
      Uri.parse('$baseUrl/donations/my'),
      headers: _headers(),
    );
    debugPrint('[Donation] getMyDonations ${res.statusCode}');
    return _handleList(res);
  }

  // ── POST create donation (multipart) ─────────────────────────────────────
  //
  // API requires:
  //   totalQuantity  — positive number  e.g. "7"
  //   quantityUnit   — unit string      e.g. "kg"
  //
  // The old `quantity` field ("7 kg") is no longer sent.
  Future<Map<String, dynamic>> createDonation({
    required String title,
    required String category,
    required double totalQuantity,   // ← number only
    required String quantityUnit,    // ← unit only  e.g. "kg", "L", "pieces"
    required String pickupAddress,
    required String pickupType,
    File?      photoFile,
    Uint8List? photoBytes,
    String?    photoName,
    String?    description,
    bool       isUrgent = false,
    String?    expiresAt,            // ISO-8601 e.g. "2026-04-29T23:59:59.000Z"
    double?    latitude,
    double?    longitude,
  }) async {
    assert(
      photoFile != null || photoBytes != null,
      'Provide photoFile (mobile) or photoBytes (web)',
    );
    await _ensureDonatorRole();
    final token = AppToken.get();
    final uri     = Uri.parse('$baseUrl/donations');
    final request = http.MultipartRequest('POST', uri);
    if (token != null) request.headers['Authorization'] = 'Bearer $token';

    request.fields['title']         = title;
    request.fields['category']      = category;
    request.fields['totalQuantity'] = totalQuantity.toString();  // ← fixed
    request.fields['quantityUnit']  = quantityUnit;              // ← fixed
    request.fields['pickupAddress'] = pickupAddress;
    request.fields['pickupType']    = pickupType;
    request.fields['isUrgent']      = isUrgent.toString();
    if (description != null && description.isNotEmpty) {
      request.fields['description'] = description;
    }
    if (expiresAt != null)  request.fields['expiresAt']  = expiresAt;
    if (latitude  != null)  request.fields['latitude']   = latitude.toString();
    if (longitude != null)  request.fields['longitude']  = longitude.toString();

    debugPrint('[Donation] createDonation fields: ${request.fields}');

    if (photoBytes != null) {
      request.files.add(http.MultipartFile.fromBytes(
        'photo', photoBytes, filename: photoName ?? 'photo.jpg',
      ));
    } else if (photoFile != null) {
      request.files.add(
          await http.MultipartFile.fromPath('photo', photoFile.path));
    }

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    return _handleMap(response);
  }

  // ── PATCH update donation ─────────────────────────────────────────────────
  Future<Map<String, dynamic>> updateDonation(
      String id, Map<String, dynamic> payload) async {
    final res = await http.patch(
      Uri.parse('$baseUrl/donations/$id'),
      headers: _headers(),
      body: jsonEncode(payload),
    );
    debugPrint('[Donation] updateDonation $id → ${res.statusCode}');
    return _handleMap(res);
  }

  // ── DELETE donation ───────────────────────────────────────────────────────
  Future<void> deleteDonation(String id) async {
    final res = await http.delete(
      Uri.parse('$baseUrl/donations/$id'),
      headers: _headers(),
    );
    debugPrint('[Donation] deleteDonation $id → ${res.statusCode}');
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      throw Exception(body['message'] ?? 'Failed to delete donation');
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _handleList(http.Response response) {
    debugPrint('[Donation] _handleList ${response.statusCode}');
    final body = jsonDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (body is List) return List<Map<String, dynamic>>.from(body);
      final data = body['data'];
      if (data is List) return List<Map<String, dynamic>>.from(data);
      if (data is Map && data['donations'] is List) {
        return List<Map<String, dynamic>>.from(data['donations']);
      }
      if (body['donations'] is List) {
        return List<Map<String, dynamic>>.from(body['donations']);
      }
      return [];
    }
    throw Exception(body['message'] ?? 'Server error ${response.statusCode}');
  }

  Map<String, dynamic> _handleMap(http.Response response) {
    debugPrint('[Donation] _handleMap ${response.statusCode}');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      debugPrint('[Donation] ERROR body: ${response.body}');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 200 && response.statusCode < 300) return body;

    // Surface field-level errors from 422 responses
    final errors = body['errors'];
    String message = body['message']?.toString() ?? '';
    if (errors is List && errors.isNotEmpty) {
      final details = errors
          .whereType<Map>()
          .map((e) =>
              '${e['field'] ?? e['param'] ?? '?'}: ${e['message'] ?? e['msg'] ?? '?'}')
          .join(', ');
      if (details.isNotEmpty) message = '$message ($details)';
    }
    throw Exception(
        message.isEmpty ? 'Server error ${response.statusCode}' : message);
  }
}