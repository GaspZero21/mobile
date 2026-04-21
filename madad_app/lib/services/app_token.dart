// lib/services/app_token.dart
// FIX: Token persistence across app restarts using shared_preferences
// Previously: tokens were in-memory only — lost on app kill
// Now: tokens are saved to shared_preferences and restored on startup

import 'package:shared_preferences/shared_preferences.dart';

class AppToken {
  static const _kAccessToken = 'access_token';
  static const _kRefreshToken = 'refresh_token';
  static const _kUserId = 'user_id';

  // In-memory cache (still used for fast sync reads)
  static String? _accessToken;
  static String? _refreshToken;
  static String? _userId;

  // ─── Init (call once in main.dart before runApp) ───────────────────────────

  /// Call this in main() before runApp() to restore persisted tokens.
  /// Example:
  ///   void main() async {
  ///     WidgetsFlutterBinding.ensureInitialized();
  ///     await AppToken.init();
  ///     runApp(const MyApp());
  ///   }
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString(_kAccessToken);
    _refreshToken = prefs.getString(_kRefreshToken);
    _userId = prefs.getString(_kUserId);
  }

  // ─── Setters ───────────────────────────────────────────────────────────────

  static Future<void> set(String token) async {
    _accessToken = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kAccessToken, token);
  }

  static Future<void> setRefreshToken(String rt) async {
    _refreshToken = rt;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kRefreshToken, rt);
  }

  static Future<void> setUserId(String id) async {
    _userId = id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUserId, id);
  }

  // ─── Getters (sync — reads from in-memory cache) ──────────────────────────

  static String? get() => _accessToken;
  static String? getRefreshToken() => _refreshToken;
  static String? getUserId() => _userId;

  /// Returns true if the user has a saved access token (i.e. was previously logged in).
  static bool isLoggedIn() => _accessToken != null && _accessToken!.isNotEmpty;

  // ─── Clear (logout) ────────────────────────────────────────────────────────

  static Future<void> clear() async {
    _accessToken = null;
    _refreshToken = null;
    _userId = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kAccessToken);
    await prefs.remove(_kRefreshToken);
    await prefs.remove(_kUserId);
  }

  // ─── Debug ─────────────────────────────────────────────────────────────────

  static void debug() {
    // ignore: avoid_print
    print('[AppToken] access=${_accessToken?.substring(0, 20)}... '
        'refresh=${_refreshToken?.substring(0, 10)}... '
        'userId=$_userId');
  }
}