import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'app_token.dart';

class ReservationService {
  static const String baseUrl =
      'https://gasp-test-production.up.railway.app/api/v1';

  Map<String, String> _headers() {
    final token = AppToken.get();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// POST /api/v1/reservations
  Future<Map<String, dynamic>> createReservation(
    String donationId, {
    double? quantity,
    double? fullQuantity,
  }) async {
    await ensureBeneficiaryRole();

    final double requestedQty = quantity ?? fullQuantity ?? 1.0;

    final body = <String, dynamic>{
      'donationId': donationId,
      'requestedQuantity': requestedQty,
    };

    debugPrint('[Reservation] POST body: ${jsonEncode(body)}');

    final res = await http.post(
      Uri.parse('$baseUrl/reservations'),
      headers: _headers(),
      body: jsonEncode(body),
    );
    debugPrint('[Reservation] → ${res.statusCode} ${res.body}');
    final resBody = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 200 && res.statusCode < 300) return resBody;
    throw Exception(resBody['message'] ?? 'Failed to create reservation');
  }

  // ── Ensure BENEFICIARY role + fresh token ─────────────────────────────────
  // Made public so screens can call it before any beneficiary-only PATCH.
  Future<void> ensureBeneficiaryRole() async {
    final token        = AppToken.get();
    final refreshToken = AppToken.getRefreshToken();
    if (token == null || refreshToken == null) return;

    try {
      final roleRes = await http.post(
        Uri.parse('$baseUrl/users/me/roles'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'role': 'BENEFICIARY'}),
      );
      debugPrint('[Role] → ${roleRes.statusCode} ${roleRes.body}');
    } catch (e) {
      debugPrint('[Role] request failed: $e — continuing anyway');
    }

    try {
      final refreshRes = await http.post(
        Uri.parse('$baseUrl/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': refreshToken}),
      );
      debugPrint('[Refresh] → ${refreshRes.statusCode}');
      if (refreshRes.statusCode >= 200 && refreshRes.statusCode < 300) {
        final data = jsonDecode(refreshRes.body) as Map<String, dynamic>;
        final newAccess  = data['data']?['accessToken']  as String? ??
                           data['accessToken']            as String?;
        final newRefresh = data['data']?['refreshToken'] as String? ??
                           data['refreshToken']           as String?;
        if (newAccess  != null) AppToken.set(newAccess);
        if (newRefresh != null) AppToken.setRefreshToken(newRefresh);
        debugPrint('[Refresh] token updated ✓');
      }
    } catch (e) {
      debugPrint('[Refresh] request failed: $e — continuing with existing token');
    }
  }

  /// GET /api/v1/reservations
  Future<List<Map<String, dynamic>>> getReservations() async {
    final res = await http.get(
      Uri.parse('$baseUrl/reservations'),
      headers: _headers(),
    );
    debugPrint('[Reservation] getReservations ${res.statusCode}');
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final raw = body['data']?['reservations'] ??
          body['data'] ??
          body['reservations'] ??
          [];
      if (raw is List) return List<Map<String, dynamic>>.from(raw);
    }
    throw Exception(body['message'] ?? 'Failed to load reservations');
  }

  /// GET /api/v1/reservations/:id
  Future<Map<String, dynamic>> getReservationById(String id) async {
    final res = await http.get(
      Uri.parse('$baseUrl/reservations/$id'),
      headers: _headers(),
    );
    debugPrint('[Reservation] getReservationById $id → ${res.statusCode}');
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final data = body['data']?['reservation'] ??
          body['data']?['data'] ??
          body['data'] ??
          body['reservation'];
      if (data is Map<String, dynamic>) return data;
      if (body.containsKey('status') || body.containsKey('_id')) return body;
    }
    throw Exception(body['message'] ?? 'Failed to load reservation');
  }

  /// PATCH /api/v1/reservations/:id/accept
  Future<void> acceptReservation(String id) async {
    final res = await http.patch(
      Uri.parse('$baseUrl/reservations/$id/accept'),
      headers: _headers(),
    );
    debugPrint('[Reservation] acceptReservation $id → ${res.statusCode}');
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      throw Exception(body['message'] ?? 'Failed to accept reservation');
    }
  }

  /// PATCH /api/v1/reservations/:id/cancel
  Future<void> cancelReservation(String id) async {
    final res = await http.patch(
      Uri.parse('$baseUrl/reservations/$id/cancel'),
      headers: _headers(),
    );
    debugPrint('[Reservation] cancelReservation $id → ${res.statusCode}');
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      throw Exception(body['message'] ?? 'Failed to cancel reservation');
    }
  }

  /// PATCH /api/v1/reservations/:id
  /// Updates the requestedQuantity of a PENDING reservation (beneficiary only).
  /// Call ensureBeneficiaryRole() before this if the user may have multiple roles.
  Future<void> updateReservationQuantity(String id, double quantity) async {
    final res = await http.patch(
      Uri.parse('$baseUrl/reservations/$id'),
      headers: _headers(),
      body: jsonEncode({'requestedQuantity': quantity}),
    );
    debugPrint('[Reservation] updateQuantity $id → ${res.statusCode} ${res.body}');
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      throw Exception(body['message'] ?? 'Failed to update quantity');
    }
  }

  /// GET /api/v1/reservations (alias)
  Future<List<Map<String, dynamic>>> getMyReservations() async {
    final response = await http.get(
      Uri.parse('$baseUrl/reservations'),
      headers: _headers(),
    );
    return _handleList(response, 'GET reservations');
  }

  /// GET /api/v1/reservations/{id}
  Future<Map<String, dynamic>> getReservation(String id) async {
    final response = await http.get(
      Uri.parse('$baseUrl/reservations/$id'),
      headers: _headers(),
    );
    return _handle(response, 'GET reservation/$id');
  }

  /// PATCH /api/v1/reservations/{id}/confirm
  Future<Map<String, dynamic>> confirmReservation(String id) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/reservations/$id/confirm'),
      headers: _headers(),
    );
    return _handle(response, 'PATCH confirm/$id');
  }

  /// PATCH /api/v1/reservations/{id}/complete
  Future<Map<String, dynamic>> completeReservation(String id) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/reservations/$id/complete'),
      headers: _headers(),
    );
    return _handle(response, 'PATCH complete/$id');
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  Map<String, dynamic> _handle(http.Response res, String tag) {
    debugPrint('[$tag] ${res.statusCode} ${res.body}');
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 200 && res.statusCode < 300) return body;
    throw Exception(body['message'] ?? 'Server error ${res.statusCode}');
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
    throw Exception(b['message'] ?? 'Server error ${res.statusCode}');
  }
}