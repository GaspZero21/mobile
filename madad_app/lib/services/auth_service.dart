import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class AuthService {
  static const String baseUrl =
      "https://gasp-test-production.up.railway.app/api/v1";

  /// REGISTER
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
        "phoneNumber": phoneNumber,
      }),
    );
    return _handleResponse(response);
  }

  /// LOGIN
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse("$baseUrl/auth/login"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"email": email, "password": password}),
    );
    return _handleResponse(response);
  }

  /// FORGOT PASSWORD
  Future<Map<String, dynamic>> forgotPassword(String email) async {
    final response = await http.post(
      Uri.parse("$baseUrl/auth/forgot-password"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"email": email}),
    );
    return _handleResponse(response);
  }

  /// RESET PASSWORD
  Future<Map<String, dynamic>> resetPassword({
    required String email, // ✅ was: token
    required String otp, // ✅ new
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse("$baseUrl/auth/reset-password"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "email": email, // ✅ was: token
        "otp": otp, // ✅ new
        "password": password,
      }),
    );
    return _handleResponse(response);
  }

  /// COMMON RESPONSE HANDLER
  Map<String, dynamic> _handleResponse(http.Response response) {
    debugPrint("STATUS CODE: ${response.statusCode}");
    debugPrint("RESPONSE BODY: ${response.body}");
    final data = jsonDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    } else {
      throw Exception(data["message"] ?? "Server error");
    }
  }
}
