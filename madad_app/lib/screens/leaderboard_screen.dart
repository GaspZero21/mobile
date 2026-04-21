import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../theme/colors.dart';
import '../services/app_token.dart';
import '../widgets/shared_bottom_nav.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  static const String _baseUrl =
      'https://gasp-test-production.up.railway.app/api/v1';

  late TabController _tabCtrl;

  List<Map<String, dynamic>> _leaders = [];
  bool _leadersLoading = true;
  String? _leadersError;

  // FIX: use uppercase role values to match backend ENUM
  String _typeFilter = '';
  String _cityFilter = '';

  List<Map<String, dynamic>> _badges = [];
  bool _badgesLoading = true;
  String? _badgesError;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _fetchLeaderboard();
    _fetchMyBadges();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Map<String, String> get _headers {
    final token = AppToken.get();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ── Universal list extractor ──────────────────────────────────────────────
  List<Map<String, dynamic>> _extractList(dynamic raw) {
    if (raw == null) return [];

    if (raw is String) {
      try {
        return _extractList(jsonDecode(raw));
      } catch (_) {
        return [];
      }
    }

    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }

    if (raw is Map) {
      for (final key in const [
        'rows', 'items', 'list', 'results',
        'users', 'leaderboard', 'badges', 'data',
      ]) {
        if (raw.containsKey(key) && raw[key] != null) {
          final child = _extractList(raw[key]);
          if (child.isNotEmpty) return child;
        }
      }

      final keys = raw.keys.toList();
      if (keys.isNotEmpty &&
          keys.every((k) => int.tryParse(k.toString()) != null)) {
        final sorted = List.of(keys)
          ..sort((a, b) =>
              int.parse(a.toString()).compareTo(int.parse(b.toString())));
        return sorted
            .map((k) => raw[k])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }
    }

    return [];
  }

  // ── FIX: Extract donation count from every possible field name ────────────
  //
  // Tries all known field names in priority order.
  // Also handles Prisma-style _count: { "donations": 5 }
  // and APIs that embed the full donations list.
  int _extractDonationCount(Map<String, dynamic> user) {
    // 1. Direct top-level numeric fields
    for (final key in const [
      'donationCount',
      'donations_count',
      'totalDonations',
      'total_donations',
      'donationsCount',
      'donation_count',
    ]) {
      final v = user[key];
      if (v is num) return v.toInt();
      if (v is String) {
        final parsed = int.tryParse(v);
        if (parsed != null) return parsed;
      }
    }

    // 2. Prisma-style _count object: { "_count": { "donations": 5 } }
    final count = user['_count'];
    if (count is Map) {
      for (final key in const ['donations', 'donation']) {
        final v = count[key];
        if (v is num) return v.toInt();
      }
    }

    // 3. 'donations' field — could be a count (num) OR a full list
    final donField = user['donations'];
    if (donField is num) return donField.toInt();
    if (donField is List) return donField.length;

    return 0;
  }

  // ── GET /api/v1/leaderboard ───────────────────────────────────────────────
  Future<void> _fetchLeaderboard() async {
    setState(() {
      _leadersLoading = true;
      _leadersError = null;
    });
    try {
      final params = <String, String>{'limit': '20'};
      if (_typeFilter.isNotEmpty) params['type'] = _typeFilter;
      if (_cityFilter.isNotEmpty) params['city'] = _cityFilter;

      final uri = Uri.parse('$_baseUrl/leaderboard')
          .replace(queryParameters: params);
      final res = await http.get(uri, headers: _headers);

      debugPrint('[Leaderboard] status      : ${res.statusCode}');
      debugPrint('[Leaderboard] raw body    : ${res.body}');

      if (res.statusCode != 200) {
        dynamic errBody;
        try {
          errBody = jsonDecode(res.body);
        } catch (_) {}
        final msg = (errBody is Map) ? (errBody['message'] ?? '') : '';
        throw Exception(msg.isEmpty ? 'HTTP ${res.statusCode}' : msg);
      }

      dynamic decoded;
      try {
        decoded = jsonDecode(res.body);
      } catch (e) {
        throw Exception('Response is not valid JSON: $e');
      }

      debugPrint('[Leaderboard] decoded type: ${decoded.runtimeType}');

      final leaders = _extractList(decoded);
      debugPrint('[Leaderboard] items found : ${leaders.length}');

      // Debug: log first item's full shape so we know the real field names
      if (leaders.isNotEmpty) {
        debugPrint('[Leaderboard] first item keys : ${leaders.first.keys.toList()}');
        debugPrint('[Leaderboard] first item value: ${leaders.first}');
      }

      setState(() {
        _leaders = leaders;
        _leadersLoading = false;
      });
    } catch (e) {
      debugPrint('[Leaderboard] ERROR: $e');
      setState(() {
        _leadersError = e.toString();
        _leadersLoading = false;
      });
    }
  }

  // ── GET /api/v1/leaderboard/users/{id}/badges ─────────────────────────────
  Future<void> _fetchMyBadges() async {
    setState(() {
      _badgesLoading = true;
      _badgesError = null;
    });
    try {
      String? userId = AppToken.getUserId();

      if (userId == null || userId.isEmpty) {
        final meRes = await http.get(
            Uri.parse('$_baseUrl/users/me'), headers: _headers);
        if (meRes.statusCode == 200) {
          final body = jsonDecode(meRes.body) as Map<String, dynamic>;
          userId = body['data']?['user']?['id']?.toString() ??
              body['data']?['id']?.toString() ??
              body['id']?.toString() ??
              '';
          if (userId != null && userId.isNotEmpty) {
            await AppToken.setUserId(userId);
          }
        }
      }

      if (userId == null || userId.isEmpty) {
        setState(() => _badgesLoading = false);
        return;
      }

      await _fetchBadgesById(userId);
    } catch (e) {
      setState(() {
        _badgesError = e.toString();
        _badgesLoading = false;
      });
    }
  }

  Future<void> _fetchBadgesById(String id) async {
    try {
      final res = await http.get(
          Uri.parse('$_baseUrl/leaderboard/users/$id/badges'),
          headers: _headers);

      debugPrint('[Badges] status      : ${res.statusCode}');
      debugPrint('[Badges] raw body    : ${res.body}');

      if (res.statusCode != 200) {
        dynamic errBody;
        try {
          errBody = jsonDecode(res.body);
        } catch (_) {}
        final msg = (errBody is Map) ? (errBody['message'] ?? '') : '';
        throw Exception(msg.isEmpty ? 'HTTP ${res.statusCode}' : msg);
      }

      dynamic decoded;
      try {
        decoded = jsonDecode(res.body);
      } catch (e) {
        throw Exception('Response is not valid JSON: $e');
      }

      debugPrint('[Badges] decoded type: ${decoded.runtimeType}');

      final badges = _extractList(decoded);
      debugPrint('[Badges] items found : ${badges.length}');

      setState(() {
        _badges = badges;
        _badgesLoading = false;
      });
    } catch (e) {
      debugPrint('[Badges] ERROR: $e');
      setState(() {
        _badgesError = e.toString();
        _badgesLoading = false;
      });
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSand,
      body: Column(
        children: [
          _buildHeader(),
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _buildRankingsTab(),
                _buildBadgesTab(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: const SharedBottomNav(currentIndex: 4),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0A4040), kTeal],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 56, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.arrow_back_ios, color: kWhite, size: 20),
              ),
              const SizedBox(width: 12),
              const Text('Leaderboard',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: kWhite)),
              const Spacer(),
              // FIX: logo_full.png exists in pubspec.yaml; logo.png does not
              Image.asset(
                'assets/images/logo_full.png',
                width: 36,
                height: 36,
                errorBuilder: (_, __, ___) =>
                    const Text('🏆', style: TextStyle(fontSize: 26)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _filterChip('All', _typeFilter == '', () {
                  setState(() => _typeFilter = '');
                  _fetchLeaderboard();
                }),
                const SizedBox(width: 8),
                // FIX: 'DONOR' / 'BENEFICIARY' match the backend role enum.
                // If your API uses lowercase ('donors'/'beneficiaries'),
                // swap these values and check the debug logs.
                _filterChip('🌱 Donors', _typeFilter == 'DONOR', () {
                  setState(() => _typeFilter = 'DONOR');
                  _fetchLeaderboard();
                }),
                const SizedBox(width: 8),
                _filterChip('🤲 Beneficiaries', _typeFilter == 'BENEFICIARY', () {
                  setState(() => _typeFilter = 'BENEFICIARY');
                  _fetchLeaderboard();
                }),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _showCityFilter,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: _cityFilter.isNotEmpty
                          ? kTerra
                          : Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border:
                          Border.all(color: Colors.white.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.location_on_outlined,
                            color: kWhite, size: 13),
                        const SizedBox(width: 4),
                        Text(
                          _cityFilter.isEmpty ? 'City' : _cityFilter,
                          style: const TextStyle(
                              fontSize: 11,
                              color: kWhite,
                              fontWeight: FontWeight.w500),
                        ),
                        if (_cityFilter.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () {
                              setState(() => _cityFilter = '');
                              _fetchLeaderboard();
                            },
                            child: const Icon(Icons.close,
                                color: kWhite, size: 13),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active ? kTerra : Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.3)),
        ),
        child: Text(label,
            style: const TextStyle(
                fontSize: 11, color: kWhite, fontWeight: FontWeight.w500)),
      ),
    );
  }

  void _showCityFilter() {
    final ctrl = TextEditingController(text: _cityFilter);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Filter by city',
            style: TextStyle(fontSize: 15, color: kTeal)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'e.g. Oran, Alger…',
            hintStyle: TextStyle(color: kSage),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: kSage)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: kTeal, elevation: 0),
            onPressed: () {
              setState(() => _cityFilter = ctrl.text.trim());
              Navigator.pop(context);
              _fetchLeaderboard();
            },
            child: const Text('Apply',
                style:
                    TextStyle(color: kWhite, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: kWhite,
      child: TabBar(
        controller: _tabCtrl,
        labelColor: kTeal,
        unselectedLabelColor: kSage,
        indicatorColor: kTeal,
        indicatorWeight: 2.5,
        labelStyle:
            const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        tabs: const [
          Tab(text: '🏅  Rankings'),
          Tab(text: '🎖  My Badges'),
        ],
      ),
    );
  }

  Widget _buildRankingsTab() {
    if (_leadersLoading) {
      return const Center(child: CircularProgressIndicator(color: kTeal));
    }
    if (_leadersError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off, color: kSage, size: 36),
            const SizedBox(height: 8),
            Text(_leadersError!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: kSage, fontSize: 13)),
            TextButton(
                onPressed: _fetchLeaderboard,
                child: const Text('Retry',
                    style: TextStyle(color: kTeal))),
          ],
        ),
      );
    }
    if (_leaders.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('🏆', style: TextStyle(fontSize: 48)),
            SizedBox(height: 12),
            Text('No rankings yet',
                style: TextStyle(color: kSage, fontSize: 14)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      color: kTeal,
      onRefresh: _fetchLeaderboard,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: _leaders.length,
        itemBuilder: (_, i) => _buildLeaderCard(_leaders[i], i + 1),
      ),
    );
  }

  Widget _buildLeaderCard(Map<String, dynamic> user, int rank) {
    final name = user['name']?.toString() ?? 'Unknown';
    final city = user['city']?.toString() ?? '';
    final score = (user['monthlyScore'] ?? user['score'] ?? 0) as num;
    final avatar = user['avatar']?.toString();

    // FIX: use dedicated extractor that tries all known field name variants
    final donationCount = _extractDonationCount(user);

    final isTop3 = rank <= 3;
    final medal =
        rank == 1 ? '🥇' : rank == 2 ? '🥈' : rank == 3 ? '🥉' : '';
    final cardColor = rank == 1
        ? const Color(0xFFFFF8E1)
        : rank == 2
            ? const Color(0xFFF5F5F5)
            : rank == 3
                ? const Color(0xFFFFF3E0)
                : kWhite;
    final rankColor = rank == 1
        ? const Color(0xFFD4A017)
        : rank == 2
            ? const Color(0xFF9E9E9E)
            : rank == 3
                ? const Color(0xFFCD7F32)
                : kSage;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isTop3
            ? [
                BoxShadow(
                    color: rankColor.withOpacity(0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4))
              ]
            : [
                BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 6,
                    offset: const Offset(0, 2))
              ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            SizedBox(
              width: 36,
              child: isTop3
                  ? Text(medal,
                      style: const TextStyle(fontSize: 22),
                      textAlign: TextAlign.center)
                  : Text('#$rank',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: rankColor),
                      textAlign: TextAlign.center),
            ),
            const SizedBox(width: 12),
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: rankColor.withOpacity(0.4), width: 2),
              ),
              child: ClipOval(
                child: avatar != null && avatar.isNotEmpty
                    ? Image.network(avatar,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            _initialsAvatar(name, 44))
                    : _initialsAvatar(name, 44),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: isTop3
                              ? FontWeight.w700
                              : FontWeight.w600,
                          color: Colors.black87)),
                  if (city.isNotEmpty)
                    Text('📍 $city',
                        style: const TextStyle(
                            fontSize: 11, color: kSage)),
                  const SizedBox(height: 2),
                  Text('$donationCount donations',
                      style:
                          const TextStyle(fontSize: 11, color: kSage)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: rankColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('${score.toInt()} pts',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: rankColor)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _initialsAvatar(String name, double size) {
    final initials = name
        .trim()
        .split(' ')
        .take(2)
        .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
        .join();
    return Container(
      color: kSage,
      child: Center(
        child: Text(initials,
            style: TextStyle(
                fontSize: size * 0.34,
                fontWeight: FontWeight.bold,
                color: kWhite)),
      ),
    );
  }

  Widget _buildBadgesTab() {
    if (_badgesLoading) {
      return const Center(child: CircularProgressIndicator(color: kTeal));
    }
    if (_badgesError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off, color: kSage, size: 36),
            const SizedBox(height: 8),
            Text(_badgesError!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: kSage, fontSize: 13)),
            TextButton(
                onPressed: _fetchMyBadges,
                child: const Text('Retry',
                    style: TextStyle(color: kTeal))),
          ],
        ),
      );
    }
    if (_badges.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🎖', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            const Text('No badges yet',
                style: TextStyle(
                    color: kSage,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            const Text('Donate more food to earn your first badge!',
                style: TextStyle(color: kSage, fontSize: 13)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      color: kTeal,
      onRefresh: _fetchMyBadges,
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: 0.88,
        ),
        itemCount: _badges.length,
        itemBuilder: (_, i) => _buildBadgeCard(_badges[i]),
      ),
    );
  }

  Widget _buildBadgeCard(Map<String, dynamic> badge) {
    final name = badge['name']?.toString() ?? 'Badge';
    final description = badge['description']?.toString() ?? '';
    final icon = badge['icon']?.toString() ?? '🏅';
    final earnedAt = badge['earnedAt']?.toString() ??
        badge['createdAt']?.toString() ??
        '';
    final color = _badgeColor(name);

    return Container(
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: color.withOpacity(0.15),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                  color: color.withOpacity(0.12), shape: BoxShape.circle),
              child: Center(
                  child: Text(icon,
                      style: const TextStyle(fontSize: 28))),
            ),
            const SizedBox(height: 12),
            Text(name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87)),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(description,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10, color: kSage)),
            ],
            if (earnedAt.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20)),
                child: Text(_formatDate(earnedAt),
                    style: TextStyle(
                        fontSize: 10,
                        color: color,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _badgeColor(String name) {
    final n = name.toLowerCase();
    if (n.contains('gold') || n.contains('or')) return const Color(0xFFD4A017);
    if (n.contains('silver') || n.contains('argent')) {
      return const Color(0xFF9E9E9E);
    }
    if (n.contains('bronze')) return const Color(0xFFCD7F32);
    if (n.contains('first') || n.contains('premier')) return kTerra;
    return kTeal;
  }

  String _formatDate(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}