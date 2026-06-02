import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'app_token.dart';

class CategoryService {
  static const String _baseUrl =
      'https://gasp-test-production.up.railway.app/api/v1';

  // ── Fallback hardcoded list ───────────────────────────────────────────────
  static const List<Map<String, String>> _fallback = [
    {'label': 'Fruits & Veg',  'value': 'fruits_vegetables', 'emoji': '🥦'},
    {'label': 'Dry Goods',     'value': 'dry_goods',         'emoji': '🌾'},
    {'label': 'Cooked Meal',   'value': 'cooked_meal',       'emoji': '🍲'},
    {'label': 'Dairy',         'value': 'dairy',             'emoji': '🥛'},
    {'label': 'Bakery',        'value': 'bakery',            'emoji': '🥖'},
    {'label': 'Other',         'value': 'other',             'emoji': '📦'},
  ];

  /// Fetches from GET /api/v1/donations/categories.
  /// Prepends "All" only when [includeAll] is true (for home screen filters).
  /// Falls back to hardcoded list on any error.
  Future<List<Map<String, String>>> getCategories({
    bool includeAll = true,
  }) async {
    try {
      final token = AppToken.get();
      final headers = {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final res = await http
          .get(
            Uri.parse('$_baseUrl/donations/categories'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 6));

      debugPrint('[Category] GET /donations/categories → ${res.statusCode}');
      debugPrint('[Category] body: ${res.body}');

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final body = jsonDecode(res.body);
        final raw = _extractList(body);

        if (raw != null && raw.isNotEmpty) {
          final list = <Map<String, String>>[];

          if (includeAll) {
            list.add({'label': 'All', 'value': '', 'emoji': '🍽️'});
          }

          for (final item in raw) {
            final parsed = _parseItem(item);
            if (parsed != null && parsed['value']!.isNotEmpty) {
              list.add(parsed);
            }
          }

          if (list.isNotEmpty) {
            debugPrint('[Category] ✅ loaded ${list.length} categories from API');
            return list;
          }
        }
      }
    } catch (e) {
      debugPrint('[Category] ❌ Error: $e — using fallback');
    }

    // Fallback
    final fallback = List<Map<String, String>>.from(_fallback);
    if (includeAll) {
      fallback.insert(0, {'label': 'All', 'value': '', 'emoji': '🍽️'});
    }
    return fallback;
  }

  // ── Extract the raw list from any API response shape ─────────────────────
  List<dynamic>? _extractList(dynamic body) {
    // Shape 1: top-level array  → [ "fruits_vegetables", ... ]
    if (body is List) return body;

    if (body is Map) {
      // Shape 2: { data: [...] }
      if (body['data'] is List) return body['data'] as List;

      // Shape 3: { data: { categories: [...] } }
      if (body['data'] is Map) {
        final inner = body['data'] as Map;
        if (inner['categories'] is List) return inner['categories'] as List;
        if (inner['items'] is List)      return inner['items'] as List;
      }

      // Shape 4: { categories: [...] }
      if (body['categories'] is List) return body['categories'] as List;

      // Shape 5: { items: [...] }
      if (body['items'] is List) return body['items'] as List;

      // Shape 6: { success: true, data: { categories: [...] } }
      final data = body['data'];
      if (data is Map && data['categories'] is List) {
        return data['categories'] as List;
      }
    }

    return null;
  }

  // ── Parse a single category item (string or object) ──────────────────────
  Map<String, String>? _parseItem(dynamic item) {
    if (item is String && item.isNotEmpty) {
      return {
        'label': _labelFor(item),
        'value': item,
        'emoji': _emojiFor(item),
      };
    }

    if (item is Map) {
      // Try every common field name for the slug/value
      final value = (item['value']     ??
                     item['slug']      ??
                     item['key']       ??
                     item['id']        ??
                     item['name']      ?? '').toString();

      // Try every common field name for the display label
      final label = (item['label']     ??
                     item['name']      ??
                     item['title']     ??
                     item['displayName'] ?? value).toString();

      final emoji = item['emoji']?.toString() ?? _emojiFor(value);

      if (value.isEmpty) return null;

      return {
        'label': label.isNotEmpty ? label : _labelFor(value),
        'value': value,
        'emoji': emoji,
      };
    }

    return null;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  String _labelFor(String value) {
    switch (value) {
      case 'fruits_vegetables': return 'Fruits & Veg';
      case 'dry_goods':         return 'Dry Goods';
      case 'cooked_meal':       return 'Cooked Meal';
      case 'dairy':             return 'Dairy';
      case 'bakery':            return 'Bakery';
      case 'other':             return 'Other';
      default:
        // Convert snake_case → Title Case for custom categories
        return value
            .split('_')
            .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
            .join(' ');
    }
  }

  String _emojiFor(String value) {
    switch (value) {
      case 'fruits_vegetables': return '🥦';
      case 'dry_goods':         return '🌾';
      case 'cooked_meal':       return '🍲';
      case 'dairy':             return '🥛';
      case 'bakery':            return '🥖';
      case 'other':             return '📦';
      default:                  return '🍽️';
    }
  }
}