import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../theme/colors.dart';
import '../services/app_token.dart';
import '../widgets/shared_bottom_nav.dart';

// ─────────────────────────────────────────────────────────────────────────────
// GamificationScreen  — 4 tabs: Points · Badges · Leaderboard · Food Saver
// ─────────────────────────────────────────────────────────────────────────────
class GamificationScreen extends StatefulWidget {
  const GamificationScreen({super.key});
  @override
  State<GamificationScreen> createState() => _GamificationScreenState();
}

class _GamificationScreenState extends State<GamificationScreen>
    with SingleTickerProviderStateMixin {
  static const String _base =
      'https://gasp-test-production.up.railway.app/api/v1';
  late TabController _tab;

  // ── Leaderboard state
  List<Map<String, dynamic>> _leaders = [];
  bool _leadersLoading = true;
  String? _leadersError;
  // FIX: lowercase values to match Swagger 'donors' / 'beneficiaries'
  String _typeFilter = '';
  String _cityFilter = '';

  // ── Badges state
  List<Map<String, dynamic>> _badges = [];
  bool _badgesLoading = true;
  String? _badgesError;

  // ── My stats (for points tab)
  int _myScore = 0;
  int _myRank = 0;
  int _myDonations = 0;
  bool _statsLoading = true;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
    _fetchAll();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Map<String, String> get _headers {
    final t = AppToken.get();
    return {
      'Content-Type': 'application/json',
      if (t != null) 'Authorization': 'Bearer $t'
    };
  }

  Future<void> _fetchAll() async {
    await Future.wait([_fetchLeaderboard(), _fetchMyBadges(), _fetchMyStats()]);
  }

  List<Map<String, dynamic>> _extractList(dynamic raw) {
    if (raw == null) return [];
    if (raw is String) {
      try { return _extractList(jsonDecode(raw)); } catch (_) { return []; }
    }
    if (raw is List) {
      return raw.whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e as Map)).toList();
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
        return sorted.map((k) => raw[k]).whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    }
    return [];
  }

  // ── GET /api/v1/leaderboard ───────────────────────────────────────────────
  Future<void> _fetchLeaderboard() async {
    setState(() { _leadersLoading = true; _leadersError = null; });
    try {
      final params = <String, String>{'limit': '20'};
      // FIX: lowercase 'donors' / 'beneficiaries' per Swagger
      if (_typeFilter.isNotEmpty) params['type'] = _typeFilter;
      if (_cityFilter.isNotEmpty) params['city'] = _cityFilter;

      final res = await http.get(
          Uri.parse('$_base/leaderboard').replace(queryParameters: params),
          headers: _headers);

      debugPrint('[Gamification/Leaderboard] status: ${res.statusCode}');
      debugPrint('[Gamification/Leaderboard] body  : ${res.body}');

      if (res.statusCode != 200) {
        dynamic errBody;
        try { errBody = jsonDecode(res.body); } catch (_) {}
        final msg = (errBody is Map) ? (errBody['message'] ?? '') : '';
        throw Exception(msg.isEmpty ? 'HTTP ${res.statusCode}' : msg);
      }

      dynamic decoded;
      try { decoded = jsonDecode(res.body); }
      catch (e) { throw Exception('Response is not valid JSON: $e'); }

      final leaders = _extractList(decoded);
      debugPrint('[Gamification/Leaderboard] items: ${leaders.length}');

      setState(() { _leaders = leaders; _leadersLoading = false; });
    } catch (e) {
      debugPrint('[Gamification/Leaderboard] ERROR: $e');
      setState(() { _leadersError = e.toString(); _leadersLoading = false; });
    }
  }

  // ── GET /api/v1/leaderboard/users/{id}/badges ─────────────────────────────
  Future<void> _fetchMyBadges() async {
    setState(() { _badgesLoading = true; _badgesError = null; });
    try {
      String? userId = AppToken.getUserId();
      if (userId == null || userId.isEmpty) {
        final r = await http.get(Uri.parse('$_base/users/me'), headers: _headers);
        if (r.statusCode == 200) {
          final b = jsonDecode(r.body) as Map<String, dynamic>;
          userId = b['data']?['user']?['id']?.toString() ??
              b['data']?['id']?.toString() ?? '';
          if (userId != null && userId.isNotEmpty) {
            await AppToken.setUserId(userId);
          }
        }
      }
      if (userId == null || userId.isEmpty) {
        setState(() => _badgesLoading = false);
        return;
      }

      final res = await http.get(
          Uri.parse('$_base/leaderboard/users/$userId/badges'),
          headers: _headers);

      debugPrint('[Gamification/Badges] status: ${res.statusCode}');
      debugPrint('[Gamification/Badges] body  : ${res.body}');

      if (res.statusCode != 200) {
        dynamic errBody;
        try { errBody = jsonDecode(res.body); } catch (_) {}
        final msg = (errBody is Map) ? (errBody['message'] ?? '') : '';
        throw Exception(msg.isEmpty ? 'HTTP ${res.statusCode}' : msg);
      }

      dynamic decoded;
      try { decoded = jsonDecode(res.body); }
      catch (e) { throw Exception('Response is not valid JSON: $e'); }

      final badges = _extractList(decoded);
      debugPrint('[Gamification/Badges] items: ${badges.length}');

      setState(() { _badges = badges; _badgesLoading = false; });
    } catch (e) {
      debugPrint('[Gamification/Badges] ERROR: $e');
      setState(() { _badgesError = e.toString(); _badgesLoading = false; });
    }
  }

  // ── Load my own stats from /users/me ──────────────────────────────────────
  Future<void> _fetchMyStats() async {
    try {
      final res = await http.get(Uri.parse('$_base/users/me'), headers: _headers);
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final user = body['data']?['user'] as Map<String, dynamic>? ??
            body['data'] as Map<String, dynamic>? ?? {};
        setState(() {
          // FIX: try monthlyScore first, then reputationScore (Swagger field), then score
          _myScore = ((user['monthlyScore'] ?? user['reputationScore'] ?? user['score'] ?? 0) as num).toInt();
          _myRank = ((user['rank'] ?? 0) as num).toInt();
          // FIX: donationCount is the direct field per Swagger
          _myDonations = ((user['donationCount'] ?? 0) as num).toInt();
          _statsLoading = false;
        });
      } else {
        setState(() => _statsLoading = false);
      }
    } catch (_) {
      setState(() => _statsLoading = false);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
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
              controller: _tab,
              children: [
                _buildPointsTab(),
                _buildBadgesTab(),
                _buildLeaderboardTab(),
                _buildFoodSaverTab(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: const SharedBottomNav(currentIndex: 4),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────
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
      child: Row(children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(Icons.arrow_back_ios, color: kWhite, size: 20),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Text('Community & Rewards',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kWhite)),
        ),
        if (!_statsLoading && _myScore > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.3))),
            child: Row(children: [
              const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
              const SizedBox(width: 4),
              Text('$_myScore pts',
                  style: const TextStyle(color: kWhite, fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ]),
          ),
      ]),
    );
  }

  // ── Tab bar ───────────────────────────────────────────────────────────────
  Widget _buildTabBar() {
    return Container(
      color: kWhite,
      child: TabBar(
        controller: _tab,
        labelColor: kTeal,
        unselectedLabelColor: kSage,
        indicatorColor: kTeal,
        indicatorWeight: 2.5,
        labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        tabs: const [
          Tab(text: '⭐  Points'),
          Tab(text: '🎖  Badges'),
          Tab(text: '🏅  Rankings'),
          Tab(text: '🛡  Food Saver'),
        ],
      ),
    );
  }

  // ── POINTS TAB ────────────────────────────────────────────────────────────
  Widget _buildPointsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (!_statsLoading) ...[
          Row(children: [
            _statCard('Monthly score', '$_myScore pts', kTeal),
            const SizedBox(width: 10),
            _statCard('My rank', _myRank > 0 ? '#$_myRank' : '—', kTerra),
            const SizedBox(width: 10),
            _statCard('Donations', '$_myDonations', kSage),
          ]),
          const SizedBox(height: 20),
        ],
        _sectionLabel('Earn points'),
        _pointsCard([
          _PointRow('+10', 'Publish a donation', 'max 5/day', plus: true),
          _PointRow('+5', 'Donation collected (confirmed)', '', plus: true),
          _PointRow('+5', 'Reservation honoured (beneficiary)', '', plus: true),
          _PointRow('+2', 'Leave a review', '1 per transaction', plus: true),
          _PointRow('+3', 'Useful report (validated by admin)', '', plus: true),
          _PointRow('+15', 'Validate a new Food Saver member', '', plus: true),
          _PointRow('+20', 'Refer a friend who makes a donation', '', plus: true),
        ]),
        const SizedBox(height: 16),
        _sectionLabel('Penalties'),
        _pointsCard([
          _PointRow('-10', 'Last-minute cancellation', '', plus: false),
          _PointRow('-15', 'No-show at pickup', '', plus: false),
          _PointRow('-20 to -50', 'Confirmed report (dangerous donation)',
              'varies', plus: false),
        ]),
        const SizedBox(height: 16),
        _sectionLabel('How the monthly reset works'),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: kWhite, borderRadius: BorderRadius.circular(16)),
          child: const Text(
            'Points reset to zero at the start of each month so everyone has an equal chance. '
            'Badges earned are permanent and stay on your profile forever.',
            style: TextStyle(fontSize: 13, color: kSage, height: 1.7),
          ),
        ),
      ],
    );
  }

  Widget _statCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
            color: kWhite, borderRadius: BorderRadius.circular(14)),
        child: Column(children: [
          Text(value,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(label, textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10, color: kSage)),
        ]),
      ),
    );
  }

  Widget _pointsCard(List<_PointRow> rows) {
    return Container(
      decoration: BoxDecoration(
          color: kWhite, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: rows.asMap().entries.map((e) {
          final row = e.value;
          final isLast = e.key == rows.length - 1;
          return Column(children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: row.plus
                        ? Colors.green.withOpacity(0.12)
                        : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(row.pts,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold,
                          color: row.plus
                              ? Colors.green.shade700 : Colors.red.shade700)),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(row.action,
                    style: const TextStyle(fontSize: 12, color: Colors.black87))),
                if (row.limit.isNotEmpty)
                  Text(row.limit, style: const TextStyle(fontSize: 10, color: kSage)),
              ]),
            ),
            if (!isLast)
              const Divider(height: 1, indent: 16, endIndent: 16,
                  color: Color(0xFFEEEEEE)),
          ]);
        }).toList(),
      ),
    );
  }

  // ── BADGES TAB ────────────────────────────────────────────────────────────
  Widget _buildBadgesTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_badgesLoading)
          const Center(child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(color: kTeal)))
        else if (_badges.isNotEmpty) ...[
          _sectionLabel('Your earned badges'),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, crossAxisSpacing: 12,
              mainAxisSpacing: 12, childAspectRatio: 0.9,
            ),
            itemCount: _badges.length,
            itemBuilder: (_, i) => _buildApiBadgeCard(_badges[i]),
          ),
          const SizedBox(height: 20),
        ],
        _sectionLabel('Beginner badges'),
        _buildBadgeGrid(_beginnerBadges),
        const SizedBox(height: 16),
        _sectionLabel('Regular engagement'),
        _buildBadgeGrid(_regularBadges),
        const SizedBox(height: 16),
        _sectionLabel('Excellence'),
        _buildBadgeGrid(_excellenceBadges),
        const SizedBox(height: 16),
        _sectionLabel('Special / event'),
        _buildBadgeGrid(_specialBadges),
      ],
    );
  }

  Widget _buildApiBadgeCard(Map<String, dynamic> b) {
    final name   = b['name']?.toString() ?? 'Badge';
    final desc   = b['description']?.toString() ?? '';
    final icon   = b['icon']?.toString() ?? '🏅';
    final earned = b['earnedAt']?.toString() ?? b['createdAt']?.toString() ?? '';
    final color  = _badgeColor(name);

    return Container(
      decoration: BoxDecoration(
          color: kWhite, borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: color.withOpacity(0.15),
              blurRadius: 10, offset: const Offset(0, 3))]),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
                color: color.withOpacity(0.12), shape: BoxShape.circle),
            child: Center(child: Text(icon, style: const TextStyle(fontSize: 24))),
          ),
          const SizedBox(height: 10),
          Text(name, textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                  color: Colors.black87)),
          if (desc.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(desc, textAlign: TextAlign.center, maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10, color: kSage)),
          ],
          if (earned.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20)),
              child: Text(_fmtDate(earned),
                  style: TextStyle(fontSize: 10, color: color,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _buildBadgeGrid(List<_BadgeDef> badges) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, crossAxisSpacing: 12,
        mainAxisSpacing: 12, childAspectRatio: 0.9,
      ),
      itemCount: badges.length,
      itemBuilder: (_, i) {
        final b = badges[i];
        final earned = _badges.any((e) => (e['name'] ?? '')
            .toString().toLowerCase().contains(b.name.toLowerCase()));
        return Container(
          decoration: BoxDecoration(
            color: kWhite, borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: earned ? b.color.withOpacity(0.4) : const Color(0xFFEEEEEE)),
          ),
          child: Stack(children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    color: earned ? b.color.withOpacity(0.12) : kSage.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: earned
                        ? Text(b.icon, style: const TextStyle(fontSize: 24))
                        : const Icon(Icons.lock_outline, color: kSage, size: 22),
                  ),
                ),
                const SizedBox(height: 10),
                Text(b.name, textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                        color: earned ? Colors.black87 : kSage)),
                const SizedBox(height: 3),
                Text(b.desc, textAlign: TextAlign.center, maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10,
                        color: earned ? kSage : kSage.withOpacity(0.5))),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: b.tierColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20)),
                  child: Text(b.tier,
                      style: TextStyle(fontSize: 9, color: b.tierColor,
                          fontWeight: FontWeight.w600)),
                ),
              ]),
            ),
            if (earned)
              Positioned(
                top: 8, right: 8,
                child: Container(
                  width: 18, height: 18,
                  decoration: const BoxDecoration(
                      color: Colors.green, shape: BoxShape.circle),
                  child: const Icon(Icons.check, color: kWhite, size: 12),
                ),
              ),
          ]),
        );
      },
    );
  }

  // ── LEADERBOARD TAB ───────────────────────────────────────────────────────
  Widget _buildLeaderboardTab() {
    return Column(children: [
      Container(
        color: kWhite,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        child: SizedBox(
          height: 32,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _chip('All', _typeFilter == '', () {
                setState(() { _typeFilter = ''; _leadersLoading = true; });
                _fetchLeaderboard();
              }),
              const SizedBox(width: 8),
              // FIX: lowercase 'donors' / 'beneficiaries'
              _chip('Donors', _typeFilter == 'donors', () {
                setState(() { _typeFilter = 'donors'; _leadersLoading = true; });
                _fetchLeaderboard();
              }),
              const SizedBox(width: 8),
              _chip('Beneficiaries', _typeFilter == 'beneficiaries', () {
                setState(() { _typeFilter = 'beneficiaries'; _leadersLoading = true; });
                _fetchLeaderboard();
              }),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _showCityDialog,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: _cityFilter.isNotEmpty ? kTerra : kWhite,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFDDDDDD)),
                  ),
                  child: Row(children: [
                    Icon(Icons.location_on_outlined, size: 12,
                        color: _cityFilter.isNotEmpty ? kWhite : kSage),
                    const SizedBox(width: 4),
                    Text(_cityFilter.isEmpty ? 'City' : _cityFilter,
                        style: TextStyle(fontSize: 11,
                            color: _cityFilter.isNotEmpty ? kWhite : kSage)),
                    if (_cityFilter.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () {
                          setState(() { _cityFilter = ''; _leadersLoading = true; });
                          _fetchLeaderboard();
                        },
                        child: const Icon(Icons.close, color: kWhite, size: 12),
                      ),
                    ],
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
      const Divider(height: 1, color: Color(0xFFEEEEEE)),
      Expanded(
        child: _leadersLoading
            ? const Center(child: CircularProgressIndicator(color: kTeal))
            : _leadersError != null
                ? Center(child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.wifi_off, color: kSage, size: 36),
                      const SizedBox(height: 8),
                      Text(_leadersError!, style: const TextStyle(color: kSage)),
                      TextButton(onPressed: _fetchLeaderboard,
                          child: const Text('Retry', style: TextStyle(color: kTeal))),
                    ]))
                : _leaders.isEmpty
                    ? const Center(child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('🏆', style: TextStyle(fontSize: 48)),
                          SizedBox(height: 12),
                          Text('No rankings yet',
                              style: TextStyle(color: kSage, fontSize: 14)),
                        ]))
                    : RefreshIndicator(
                        color: kTeal,
                        onRefresh: _fetchLeaderboard,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                          itemCount: _leaders.length,
                          itemBuilder: (_, i) =>
                              _buildLeaderCard(_leaders[i], i + 1),
                        ),
                      ),
      ),
    ]);
  }

  Widget _chip(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: active ? kTeal : kWhite,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? kTeal : const Color(0xFFDDDDDD)),
        ),
        child: Text(label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500,
                color: active ? kWhite : kSage)),
      ),
    );
  }

  void _showCityDialog() {
    final ctrl = TextEditingController(text: _cityFilter);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Filter by city',
            style: TextStyle(fontSize: 15, color: kTeal)),
        content: TextField(controller: ctrl, autofocus: true,
            decoration: const InputDecoration(hintText: 'e.g. Oran, Alger…')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: kSage))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kTeal, elevation: 0),
            onPressed: () {
              setState(() { _cityFilter = ctrl.text.trim(); _leadersLoading = true; });
              Navigator.pop(context);
              _fetchLeaderboard();
            },
            child: const Text('Apply',
                style: TextStyle(color: kWhite, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderCard(Map<String, dynamic> user, int rank) {
    final name   = user['name']?.toString() ?? 'Unknown';
    final city   = user['city']?.toString() ?? '';
    final score  = (user['monthlyScore'] ?? user['reputationScore'] ?? user['score'] ?? 0) as num;
    final avatar = user['avatar']?.toString();

    // FIX: donationCount is the direct Swagger field
    final donationCount = (user['donationCount'] ?? 0) as num;

    final isTop3    = rank <= 3;
    final medal     = rank == 1 ? '🥇' : rank == 2 ? '🥈' : rank == 3 ? '🥉' : '';
    final rankColor = rank == 1 ? const Color(0xFFD4A017)
        : rank == 2 ? const Color(0xFF9E9E9E)
        : rank == 3 ? const Color(0xFFCD7F32)
        : kSage;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: rank == 1 ? const Color(0xFFFFF8E1)
            : rank == 2 ? const Color(0xFFF5F5F5)
            : rank == 3 ? const Color(0xFFFFF3E0) : kWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(
            color: isTop3 ? rankColor.withOpacity(0.15) : Colors.black.withOpacity(0.04),
            blurRadius: isTop3 ? 12 : 6, offset: const Offset(0, 3))],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          SizedBox(
            width: 36,
            child: isTop3
                ? Text(medal, style: const TextStyle(fontSize: 22),
                    textAlign: TextAlign.center)
                : Text('#$rank',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold,
                        color: rankColor),
                    textAlign: TextAlign.center),
          ),
          const SizedBox(width: 12),
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(shape: BoxShape.circle,
                border: Border.all(color: rankColor.withOpacity(0.4), width: 2)),
            child: ClipOval(
              child: avatar != null && avatar.isNotEmpty
                  ? Image.network(avatar, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _initialsCircle(name, 44))
                  : _initialsCircle(name, 44),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: TextStyle(fontSize: 13,
                  fontWeight: isTop3 ? FontWeight.bold : FontWeight.w600,
                  color: Colors.black87)),
              if (city.isNotEmpty)
                Text('📍 $city', style: const TextStyle(fontSize: 11, color: kSage)),
              // FIX: show donationCount
              Text('${donationCount.toInt()} donation${donationCount.toInt() == 1 ? '' : 's'}',
                  style: const TextStyle(fontSize: 11, color: kSage)),
            ],
          )),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
                color: rankColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20)),
            child: Text('${score.toInt()} pts',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                    color: rankColor)),
          ),
        ]),
      ),
    );
  }

  Widget _initialsCircle(String name, double size) {
    final ini = name.trim().split(' ').take(2)
        .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '').join();
    return Container(color: kSage,
        child: Center(child: Text(ini,
            style: TextStyle(fontSize: size * 0.34,
                fontWeight: FontWeight.bold, color: kWhite))));
  }

  // ── FOOD SAVER TAB ────────────────────────────────────────────────────────
  Widget _buildFoodSaverTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFF0A4040), kTeal],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15), shape: BoxShape.circle),
                child: const Center(child: Text('🛡', style: TextStyle(fontSize: 24))),
              ),
              const SizedBox(width: 14),
              const Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Food Saver', style: TextStyle(fontSize: 18,
                      fontWeight: FontWeight.bold, color: kWhite)),
                  Text('Community trust validators',
                      style: TextStyle(fontSize: 12, color: Colors.white70)),
                ],
              )),
            ]),
            const SizedBox(height: 14),
            const Text(
              'Food Savers are trusted members who verify new users, build neighbourhood trust, '
              'and earn points for every successful validation.',
              style: TextStyle(fontSize: 13, color: Colors.white70, height: 1.6),
            ),
          ]),
        ),
        const SizedBox(height: 20),
        _sectionLabel('Eligibility criteria'),
        Container(
          decoration: BoxDecoration(
              color: kWhite, borderRadius: BorderRadius.circular(16)),
          child: Column(children: [
            _criteriaRow(Icons.star_outline, '200+ reputation points'),
            const Divider(height: 1, indent: 16, endIndent: 16, color: Color(0xFFEEEEEE)),
            _criteriaRow(Icons.history, 'At least 20 transactions without any report'),
            const Divider(height: 1, indent: 16, endIndent: 16, color: Color(0xFFEEEEEE)),
            _criteriaRow(Icons.calendar_today_outlined, 'Account at least 3 months old'),
            const Divider(height: 1, indent: 16, endIndent: 16, color: Color(0xFFEEEEEE)),
            _criteriaRow(Icons.group_outlined, 'Optionally co-opted by other Food Savers'),
          ]),
        ),
        const SizedBox(height: 20),
        _sectionLabel('Validation flow'),
        ..._foodSaverSteps.asMap().entries.map((e) {
          final isLast = e.key == _foodSaverSteps.length - 1;
          return _buildFlowStep(e.value, e.key + 1, isLast: isLast);
        }),
        const SizedBox(height: 20),
        _sectionLabel('Anti-abuse rules'),
        Container(
          decoration: BoxDecoration(
              color: kWhite, borderRadius: BorderRadius.circular(16)),
          child: Column(children: [
            _ruleRow('Max 5 validations / month', 'Prevents bulk or fake validations'),
            const Divider(height: 1, indent: 16, endIndent: 16, color: Color(0xFFEEEEEE)),
            _ruleRow('Responsibility clause', '-30 pts if validated user causes harm'),
            const Divider(height: 1, indent: 16, endIndent: 16, color: Color(0xFFEEEEEE)),
            _ruleRow('Inactivity', 'Status revoked after 6 months without validating'),
            const Divider(height: 1, indent: 16, endIndent: 16, color: Color(0xFFEEEEEE)),
            _ruleRow('Family limit', 'Cannot validate members at the same address'),
          ]),
        ),
        const SizedBox(height: 20),
        _sectionLabel('Fallback when no Food Saver is nearby'),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: kTeal.withOpacity(0.07),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: kTeal.withOpacity(0.2))),
          child: const Text(
            '• Remote validation via quick video call with a Food Saver from another neighbourhood.\n'
            '• OR automatic validation after 10 successful transactions.',
            style: TextStyle(fontSize: 12, color: kTeal, height: 1.7),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _criteriaRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
              color: kTeal.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 16, color: kTeal),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(text,
            style: const TextStyle(fontSize: 13, color: Colors.black87))),
      ]),
    );
  }

  Widget _ruleRow(String title, String desc) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 8, height: 8, margin: const EdgeInsets.only(top: 5),
          decoration: const BoxDecoration(color: kTerra, shape: BoxShape.circle),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 12,
              fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 2),
          Text(desc, style: const TextStyle(fontSize: 11, color: kSage)),
        ])),
      ]),
    );
  }

  Widget _buildFlowStep(_FoodSaverStep step, int num, {required bool isLast}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(children: [
          Container(
            width: 32, height: 32,
            decoration: const BoxDecoration(color: kTeal, shape: BoxShape.circle),
            child: Center(child: Text('$num',
                style: const TextStyle(color: kWhite, fontSize: 12,
                    fontWeight: FontWeight.bold))),
          ),
          if (!isLast)
            Container(width: 2, height: 32, color: kTeal.withOpacity(0.2)),
        ]),
        const SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: kWhite, borderRadius: BorderRadius.circular(14)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(step.title, style: const TextStyle(fontSize: 13,
                    fontWeight: FontWeight.bold, color: Colors.black87)),
                const SizedBox(height: 4),
                Text(step.desc, style: const TextStyle(fontSize: 12,
                    color: kSage, height: 1.6)),
              ]),
            ),
          ),
        ),
      ],
    );
  }

  // ── Shared helpers ────────────────────────────────────────────────────────
  Widget _sectionLabel(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(text.toUpperCase(),
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold,
              color: kSage, letterSpacing: 0.8)));

  Color _badgeColor(String name) {
    final n = name.toLowerCase();
    if (n.contains('gold') || n.contains('or') || n.contains('champion'))
      return const Color(0xFFD4A017);
    if (n.contains('silver') || n.contains('argent')) return const Color(0xFF9E9E9E);
    if (n.contains('bronze')) return const Color(0xFFCD7F32);
    if (n.contains('food') || n.contains('garde') || n.contains('horloge')) return kTeal;
    return kTerra;
  }

  String _fmtDate(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  // ── Static badge definitions ──────────────────────────────────────────────
  static final _beginnerBadges = [
    _BadgeDef('J\'me lance', '🌱', 'First donation published', 'Beginner',
        kTeal, const Color(0xFF0F6E56)),
    _BadgeDef('Sauveur débutant', '🤲', 'First donation collected',
        'Beginner', kTeal, const Color(0xFF0F6E56)),
    _BadgeDef('Fiable', '✅', 'Profile fully completed', 'Beginner',
        kTeal, const Color(0xFF0F6E56)),
  ];
  static final _regularBadges = [
    _BadgeDef('Main verte', '🌿', '10 donations published', 'Regular',
        const Color(0xFF185FA5), const Color(0xFF185FA5)),
    _BadgeDef('Recycleur', '♻️', '20 donations collected', 'Regular',
        const Color(0xFF185FA5), const Color(0xFF185FA5)),
    _BadgeDef('Team Gasp\'Zero', '📣', 'App shared 5 times', 'Regular',
        const Color(0xFF185FA5), const Color(0xFF185FA5)),
  ];
  static final _excellenceBadges = [
    _BadgeDef('Garde du Frigo', '🛡', '100 pts + Food Saver validated',
        'Excellence', const Color(0xFF534AB7), const Color(0xFF534AB7)),
    _BadgeDef('Horloge suisse', '⏳', '50 txn, zero cancellations',
        'Excellence', const Color(0xFF534AB7), const Color(0xFF534AB7)),
    _BadgeDef('Équilibré', '🔄', '5 different categories donated',
        'Excellence', const Color(0xFF534AB7), const Color(0xFF534AB7)),
    _BadgeDef('Hibou', '🦉', '5 donations posted after 10pm', 'Excellence',
        const Color(0xFF534AB7), const Color(0xFF534AB7)),
  ];
  static final _specialBadges = [
    _BadgeDef('Champion du mois', '🏆', '#1 on monthly leaderboard',
        'Special', const Color(0xFFD4A017), const Color(0xFF854F0B)),
    _BadgeDef('Flash', '⚡', 'Donation collected < 30 min', 'Special',
        const Color(0xFFD4A017), const Color(0xFF854F0B)),
    _BadgeDef('Pompier', '🚒', '10 urgent donations collected', 'Special',
        const Color(0xFFD4A017), const Color(0xFF854F0B)),
  ];

  static final _foodSaverSteps = [
    _FoodSaverStep('New user signs up',
        'Profile is marked "New member — pending validation". Limited to 2 reservations/day, lower listing priority.'),
    _FoodSaverStep('Algorithm suggests nearby Food Savers',
        'Food Savers in the same neighbourhood receive a push notification to validate the new member.'),
    _FoodSaverStep('Optional in-person meeting',
        'Organised via in-app chat. Verifies the person is real, explains best practices, builds neighbourhood trust.'),
    _FoodSaverStep('Food Saver confirms in-app',
        '"I met this person and confirm their registration." An optional comment is visible on the profile.'),
    _FoodSaverStep('Account fully activated',
        'All limits lifted. New member earns "Recommended by community" badge. Food Saver earns +15 pts.'),
  ];
}

// ── Simple data classes ───────────────────────────────────────────────────────
class _PointRow {
  final String pts, action, limit;
  final bool plus;
  const _PointRow(this.pts, this.action, this.limit, {required this.plus});
}

class _BadgeDef {
  final String name, icon, desc, tier;
  final Color color, tierColor;
  const _BadgeDef(this.name, this.icon, this.desc, this.tier, this.color, this.tierColor);
}

class _FoodSaverStep {
  final String title, desc;
  const _FoodSaverStep(this.title, this.desc);
}