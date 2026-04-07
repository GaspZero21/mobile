import 'package:flutter/foundation.dart';

class AppToken {
  AppToken._();

  static String? _accessToken;
  static String? _refreshToken;
  static String? _userId;

  // ── SET ────────────────────────────────────────────────────────────────────
  static void set(String accessToken) => _accessToken = accessToken;
  static void setRefreshToken(String refreshToken) => _refreshToken = refreshToken;
  static void setUserId(String userId) => _userId = userId;

  static void setTokens({
    required String accessToken,
    required String refreshToken,
  }) {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
  }

  // ── GET ────────────────────────────────────────────────────────────────────
  static String? get() => _accessToken;
  static String? getRefreshToken() => _refreshToken;
  static String? getUserId() => _userId;

  // ── CLEAR ──────────────────────────────────────────────────────────────────
  static void clear() {
    _accessToken  = null;
    _refreshToken = null;
    _userId       = null;
  }

  // ── DEBUG ──────────────────────────────────────────────────────────────────
  static void debug() {
    debugPrint('[AppToken] access  = ${_accessToken  != null ? "SET ✅" : "NULL ❌"}');
    debugPrint('[AppToken] refresh = ${_refreshToken != null ? "SET ✅" : "NULL ❌"}');
    debugPrint('[AppToken] userId  = ${_userId       != null ? "$_userId ✅" : "NULL ❌"}');
  }
}