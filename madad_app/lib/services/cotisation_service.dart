import 'dart:convert';
import 'package:http/http.dart' as http;
import 'app_token.dart';

class CotisationService {
  static const String baseUrl = 'https://gasp-test-production.up.railway.app/api/v1';

  Map<String, String> _headers() {
    final token = AppToken.get();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ── GET all cotisations ─────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getCotisations({
    String? status = 'active',
    String? category,
    String? search,
  }) async {
    final params = <String, String>{};
    if (status != null) params['status'] = status;
    if (category != null) params['category'] = category;
    if (search != null) params['search'] = search;

    final uri = Uri.parse('$baseUrl/cotisations')
        .replace(queryParameters: params.isEmpty ? null : params);

    final res = await http.get(uri, headers: _headers());
    return _handleList(res);
  }

  // ── POST Contribute to a cotisation ─────────────────────────────────────
  Future<Map<String, dynamic>> contribute({
    required String id,
    required double quantity,
    String? note,
  }) async {
    final uri = Uri.parse('$baseUrl/cotisations/$id/contribute');

    final res = await http.post(
      uri,
      headers: _headers(),
      body: jsonEncode({
        'quantity': quantity,
        'note': note ?? '',
      }),
    );

    final body = jsonDecode(res.body) as Map<String, dynamic>;

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return body;
    } else {
      throw Exception(body['message'] ?? 'Failed to contribute');
    }
  }

  // ── Helper ──────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _handleList(http.Response response) {
    final body = jsonDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = body['data'];
      if (data is List) {
        return List<Map<String, dynamic>>.from(data);
      }
      if (data is Map && data['cotisations'] is List) {
        return List<Map<String, dynamic>>.from(data['cotisations']);
      }
    }
    throw Exception(body['message'] ?? 'Server error ${response.statusCode}');
  }
}