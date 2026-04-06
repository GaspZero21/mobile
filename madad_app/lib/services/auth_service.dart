import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'app_token.dart';

class AuthService {
  static const String baseUrl =
      "https://gasp-test-production.up.railway.app/api/v1";

  // ── Token ────────────────────────────────────────────────────────────────────

  static void _saveToken(Map<String, dynamic> responseData) {
  final token = responseData['data']?['accessToken'] as String?;
  final refresh = responseData['data']?['refreshToken'] as String?; // ← ADD

  if (token != null && token.isNotEmpty) {
    AppToken.set(token);
    debugPrint('[Auth] ✅ Access token saved (${token.substring(0, 20)}...)');
  } else {
    debugPrint('[Auth] ⚠️  accessToken not found. Keys: ${responseData.keys}');
  }

  if (refresh != null && refresh.isNotEmpty) {             // ← ADD
    AppToken.setRefreshToken(refresh);                      // ← ADD
    debugPrint('[Auth] ✅ Refresh token saved');             // ← ADD
  } else {                                                  // ← ADD
    debugPrint('[Auth] ⚠️  refreshToken not found');        // ← ADD
  }                                                         // ← ADD
}

  static void logout() {
    AppToken.clear();
    debugPrint('[Auth] Token cleared');
  }

  // ── Register ─────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    String? phoneNumber,
  }) async {
    final response = await http.post(
      Uri.parse("$baseUrl/auth/register"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "name": name,
        "email": email,
        "password": password,
        if (phoneNumber != null && phoneNumber.isNotEmpty)
          "phoneNumber": phoneNumber,
      }),
    );
    // Don't save token yet — user must verify email first
    return _handle(response);
  }

  // ── Verify email (after registration) ────────────────────────────────────────

  Future<Map<String, dynamic>> verifyEmail({
    required String email,
    required String otp,
  }) async {
    final response = await http.post(
      Uri.parse("$baseUrl/auth/verify-email"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"email": email, "otp": otp}),
    );
    final data = _handle(response);
    // API may return token after verification — save it if present
    _saveToken(data);
    return data;
  }

  // ── Resend verification OTP ───────────────────────────────────────────────────

  Future<Map<String, dynamic>> resendVerification(String email) async {
    final response = await http.post(
      Uri.parse("$baseUrl/auth/resend-verification"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"email": email}),
    );
    return _handle(response);
  }

  // ── Login ─────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse("$baseUrl/auth/login"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"email": email, "password": password}),
    );
    final data = _handle(response);
    _saveToken(data);
    return data;
  }

  // ── Forgot password ───────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> forgotPassword(String email) async {
    final response = await http.post(
      Uri.parse("$baseUrl/auth/forgot-password"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"email": email}),
    );
    return _handle(response);
  }

  // ── Reset password ────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String otp,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse("$baseUrl/auth/reset-password"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"email": email, "otp": otp, "password": password}),
    );
    return _handle(response);
  }

  // ── Response handler ──────────────────────────────────────────────────────────

  Map<String, dynamic> _handle(http.Response response) {
    debugPrint('[Auth] ${response.statusCode} ${response.request?.url}');
    debugPrint('[Auth] ${response.body}');
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 200 && response.statusCode < 300) return data;
    throw Exception(data["message"] ?? "Server error ${response.statusCode}");
  }
}