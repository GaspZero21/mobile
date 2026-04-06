import 'package:flutter/foundation.dart';

class AppToken {
  AppToken._();

  static String? _accessToken;
  static String? _refreshToken;

  /// ── SET TOKENS ─────────────────────────────────────────────

  static void set(String accessToken) {
    _accessToken = accessToken;
  }

  static void setRefreshToken(String refreshToken) {
    _refreshToken = refreshToken;
  }

  static void setTokens({
    required String accessToken,
    required String refreshToken,
  }) {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
  }

  /// ── GET TOKENS ─────────────────────────────────────────────

  static String? get() => _accessToken;

  static String? getRefreshToken() => _refreshToken;

  /// ── CLEAR TOKENS ───────────────────────────────────────────

  static void clear() {
    _accessToken = null;
    _refreshToken = null;
  }

  /// ── DEBUG (safe) ───────────────────────────────────────────

  static void debug() {
    debugPrint(
        '[AppToken] access = ${_accessToken != null ? "SET ✅" : "NULL ❌"}');
    debugPrint(
        '[AppToken] refresh = ${_refreshToken != null ? "SET ✅" : "NULL ❌"}');
  }
}