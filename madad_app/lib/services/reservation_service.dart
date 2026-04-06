import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'app_token.dart';

class ReservationService {
  static const String baseUrl =
      "https://gasp-test-production.up.railway.app/api/v1";

  Map<String, String> _headers() {
    final token = AppToken.get();
    return {
      "Content-Type": "application/json",
      if (token != null) "Authorization": "Bearer $token",
    };
  }

  // ── Ensure BENEFICIARY role + fresh token ─────────────────────────────────
  Future<void> _ensureBeneficiaryRole() async {
    final token        = AppToken.get();
    final refreshToken = AppToken.getRefreshToken(); // ← correct method name

    if (token == null) {
      debugPrint('[Role] ❌ No access token');
      return;
    }
    if (refreshToken == null) {
      debugPrint('[Role] ❌ No refresh token');
      return;
    }

    // 1. Assign BENEFICIARY role (409 = already has it, fine)
    final roleRes = await http.post(
      Uri.parse("$baseUrl/users/me/roles"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({"role": "BENEFICIARY"}),
    );
    debugPrint('[Role] ${roleRes.statusCode} ${roleRes.body}');

    // 2. Refresh token — send refreshToken in BODY (not header)
    final refreshRes = await http.post(
      Uri.parse("$baseUrl/auth/refresh"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"refreshToken": refreshToken}), // ← key fix
    );
    debugPrint('[Refresh] status: ${refreshRes.statusCode}');
    debugPrint('[Refresh] body:   ${refreshRes.body}');

    if (refreshRes.statusCode >= 200 && refreshRes.statusCode < 300) {
      final data = jsonDecode(refreshRes.body) as Map<String, dynamic>;
      final newAccess =
          data['data']?['accessToken'] as String? ??
          data['data']?['token'] as String? ??
          data['accessToken'] as String? ??
          data['token'] as String?;
      final newRefresh =
          data['data']?['refreshToken'] as String? ??
          data['refreshToken'] as String?;

      if (newAccess != null && newAccess.isNotEmpty) {
        AppToken.set(newAccess);
        debugPrint('[Refresh] ✅ Access token updated');
      } else {
        debugPrint('[Refresh] ❌ Could not extract access token. Keys: ${data.keys.toList()}');
      }
      if (newRefresh != null && newRefresh.isNotEmpty) {
        AppToken.setRefreshToken(newRefresh);
        debugPrint('[Refresh] ✅ Refresh token updated');
      }
    }
  }

  /// POST /api/v1/reservations
  Future<Map<String, dynamic>> createReservation(String donationId) async {
    await _ensureBeneficiaryRole();
    final response = await http.post(
      Uri.parse("$baseUrl/reservations"),
      headers: _headers(),
      body: jsonEncode({"donationId": donationId}),
    );
    return _handle(response, 'POST reservations');
  }

  /// GET /api/v1/reservations
  Future<List<Map<String, dynamic>>> getMyReservations() async {
    final response = await http.get(
      Uri.parse("$baseUrl/reservations"),
      headers: _headers(),
    );
    return _handleList(response, 'GET reservations');
  }

  /// GET /api/v1/reservations/{id}
  Future<Map<String, dynamic>> getReservation(String id) async {
    final response = await http.get(
      Uri.parse("$baseUrl/reservations/$id"),
      headers: _headers(),
    );
    return _handle(response, 'GET reservation/$id');
  }

  /// PATCH /api/v1/reservations/{id}/confirm  (DONATOR only, within 2h window)
  Future<Map<String, dynamic>> confirmReservation(String id) async {
    final response = await http.patch(
      Uri.parse("$baseUrl/reservations/$id/confirm"),
      headers: _headers(),
    );
    return _handle(response, 'PATCH confirm/$id');
  }

  /// PATCH /api/v1/reservations/{id}/cancel  (donor or beneficiary)
  Future<Map<String, dynamic>> cancelReservation(String id) async {
    final response = await http.patch(
      Uri.parse("$baseUrl/reservations/$id/cancel"),
      headers: _headers(),
    );
    return _handle(response, 'PATCH cancel/$id');
  }

  /// PATCH /api/v1/reservations/{id}/complete  (DONATOR only, after pickup)
  Future<Map<String, dynamic>> completeReservation(String id) async {
    final response = await http.patch(
      Uri.parse("$baseUrl/reservations/$id/complete"),
      headers: _headers(),
    );
    return _handle(response, 'PATCH complete/$id');
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  Map<String, dynamic> _handle(http.Response res, String tag) {
    debugPrint('[$tag] ${res.statusCode} ${res.body}');
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 200 && res.statusCode < 300) return body;
    throw Exception(body["message"] ?? "Server error ${res.statusCode}");
  }

  List<Map<String, dynamic>> _handleList(http.Response res, String tag) {
    debugPrint('[$tag] ${res.statusCode} ${res.body}');
    final body = jsonDecode(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (body is List) return List<Map<String, dynamic>>.from(body);
      final data = body['data'];
      if (data is List) return List<Map<String, dynamic>>.from(data);
      if (data is Map) {
        final nested = data['reservations'];
        if (nested is List) return List<Map<String, dynamic>>.from(nested);
      }
      return [];
    }
    final b = body as Map<String, dynamic>;
    throw Exception(b["message"] ?? "Server error ${res.statusCode}");
  }
}