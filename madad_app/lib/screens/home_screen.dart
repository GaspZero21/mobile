import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../theme/colors.dart';
import '../widgets/shared_bottom_nav.dart';
import '../services/donation_service.dart';
import '../services/app_token.dart';
import 'add_donation_screen.dart';
import 'all_donations_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const String _baseUrl =
      'https://gasp-test-production.up.railway.app/api/v1';

  List<Map<String, dynamic>> _donations = [];
  bool _isLoading = true;
  String? _error;

  // ── Stats
  int _donationCount = 0;
  int _requestCount = 0;
  double _foodSavedKg = 0.0;
  double _reputation = 0.0;
  bool _statsLoading = true;

  LatLng _mapCenter = const LatLng(35.1897, 0.6456);
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _fetchAll();
  }

  Future<void> _fetchAll() async {
    setState(() {
      _isLoading = true;
      _statsLoading = true;
      _error = null;
    });
    await Future.wait([
      _fetchDonations(),
      _fetchStats(),
    ]);
  }

  Future<void> _fetchDonations() async {
    try {
      final data = await DonationService().getDonations();
      if (!mounted) return;

      LatLng? firstCoord;
      for (final d in data) {
        final lat = double.tryParse(d['latitude']?.toString() ?? '');
        final lng = double.tryParse(d['longitude']?.toString() ?? '');
        if (lat != null && lng != null) {
          firstCoord = LatLng(lat, lng);
          break;
        }
      }

      setState(() {
        _donations = data;
        _isLoading = false;
        if (firstCoord != null) _mapCenter = firstCoord;
      });

      if (firstCoord != null) {
        try {
          _mapController.move(firstCoord, 13);
        } catch (_) {}
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STATS — uses the same two endpoints confirmed in the Swagger screenshots:
  //   GET /api/v1/donations/my   →  donor's own donations
  //   GET /api/v1/reservations   →  current user's reservations (donor OR beneficiary)
  //
  // Reputation comes from the user profile rating field in /users/me
  // because there is no separate /users/{id}/reputation endpoint visible.
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _fetchStats() async {
    try {
      final token = AppToken.get();
      if (token == null) {
        if (mounted) setState(() => _statsLoading = false);
        return;
      }

      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      // Fire all three requests in parallel
      final responses = await Future.wait([
        http.get(Uri.parse('$_baseUrl/users/me'), headers: headers),        // [0] profile + rating
        http.get(Uri.parse('$_baseUrl/donations/my'), headers: headers),    // [1] my donations
        http.get(Uri.parse('$_baseUrl/reservations'), headers: headers),    // [2] my reservations
      ]);

      if (!mounted) return;

      // ── [0] /users/me  →  reputation / rating
      if (responses[0].statusCode == 200) {
        final body = jsonDecode(responses[0].body) as Map<String, dynamic>;
        // Try every known rating key path
        _reputation =
            _pickDouble(body, ['data', 'user', 'rating']) ??
            _pickDouble(body, ['data', 'user', 'reputation']) ??
            _pickDouble(body, ['data', 'rating']) ??
            _pickDouble(body, ['data', 'reputation']) ??
            0.0;
      }

      // ── [1] /donations/my  →  donation count + food saved
      if (responses[1].statusCode == 200) {
        final body = jsonDecode(responses[1].body) as Map<String, dynamic>;

        // The list lives under one of these paths — try each in order
        final list =
            _pickList(body, ['data', 'donations']) ??
            _pickList(body, ['data', 'data']) ??
            _pickList(body, ['data']) ??
            _pickList(body, ['donations']) ??
            [];

        _donationCount = list.length;

        // Also try top-level count/total field in case the API paginates
        if (_donationCount == 0) {
          _donationCount =
              (_pickNum(body, ['data', 'total']) ??
               _pickNum(body, ['data', 'count']) ??
               _pickNum(body, ['total']) ??
               _pickNum(body, ['count']) ??
               0)
              .toInt();
        }

        // Sum quantity from every possible field name
        double kg = 0.0;
        for (final item in list) {
          if (item is Map) {
            kg += (_numField(item, 'quantityKg') ??
                   _numField(item, 'quantity_kg') ??
                   _numField(item, 'weightKg') ??
                   _numField(item, 'weight_kg') ??
                   _numField(item, 'quantity') ??
                   _numField(item, 'weight') ??
                   0.0);
          }
        }
        _foodSavedKg = kg;

        debugPrint('[Stats] donations raw body keys: ${body.keys}');
        debugPrint('[Stats] donation list length: $_donationCount, kg: $_foodSavedKg');
        if (list.isNotEmpty && list.first is Map) {
          debugPrint('[Stats] first donation keys: ${(list.first as Map).keys}');
        }
      } else {
        debugPrint('[Stats] /donations/my → ${responses[1].statusCode}: ${responses[1].body}');
      }

      // ── [2] /reservations  →  reservation count
      if (responses[2].statusCode == 200) {
        final body = jsonDecode(responses[2].body) as Map<String, dynamic>;

        final list =
            _pickList(body, ['data', 'reservations']) ??
            _pickList(body, ['data', 'data']) ??
            _pickList(body, ['data']) ??
            _pickList(body, ['reservations']) ??
            [];

        _requestCount = list.length;

        if (_requestCount == 0) {
          _requestCount =
              (_pickNum(body, ['data', 'total']) ??
               _pickNum(body, ['data', 'count']) ??
               _pickNum(body, ['total']) ??
               _pickNum(body, ['count']) ??
               0)
              .toInt();
        }

        debugPrint('[Stats] reservations raw body keys: ${body.keys}');
        debugPrint('[Stats] reservation list length: $_requestCount');
      } else {
        debugPrint('[Stats] /reservations → ${responses[2].statusCode}: ${responses[2].body}');
      }

      if (mounted) setState(() => _statsLoading = false);
    } catch (e, st) {
      debugPrint('[Stats] error: $e\n$st');
      if (mounted) setState(() => _statsLoading = false);
    }
  }

  // ── Navigation helpers ────────────────────────────────────────────────────

  /// Walk [map] along [keys] and return the value as a List, or null.
  List<dynamic>? _pickList(Map<String, dynamic> map, List<String> keys) {
    dynamic cur = map;
    for (final k in keys) {
      if (cur is Map && cur.containsKey(k)) {
        cur = cur[k];
      } else {
        return null;
      }
    }
    return cur is List ? cur : null;
  }

  /// Walk [map] along [keys] and return the value as a num, or null.
  num? _pickNum(Map<String, dynamic> map, List<String> keys) {
    dynamic cur = map;
    for (final k in keys) {
      if (cur is Map && cur.containsKey(k)) {
        cur = cur[k];
      } else {
        return null;
      }
    }
    return cur is num ? cur : null;
  }

  /// Walk [map] along [keys] and return as double, or null.
  double? _pickDouble(Map<String, dynamic> map, List<String> keys) =>
      _pickNum(map, keys)?.toDouble();

  /// Read a single numeric field from a flat map, return double or null.
  double? _numField(Map item, String key) {
    final v = item[key];
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _openAddDonation() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AddDonationScreen()),
    );
    if (result == true) _fetchAll();
  }

  List<Marker> get _markers => _donations
      .where((d) => d['latitude'] != null && d['longitude'] != null)
      .map((d) {
        final lat = double.tryParse(d['latitude'].toString()) ?? 0.0;
        final lng = double.tryParse(d['longitude'].toString()) ?? 0.0;
        final urgent = d['isUrgent'] == true;
        return Marker(
          point: LatLng(lat, lng),
          width: 40,
          height: 40,
          child: GestureDetector(
            onTap: () => _showDonationPopup(d),
            child: Icon(Icons.location_on,
                color: urgent ? kTerra : kTeal, size: 36),
          ),
        );
      })
      .toList();

  void _showDonationPopup(Map<String, dynamic> d) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: kWhite, borderRadius: BorderRadius.circular(20)),
        child: Row(children: [
          const Icon(Icons.volunteer_activism, color: kTeal, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(d['title'] ?? '',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: kTeal)),
                Text(d['pickupAddress'] ?? '',
                    style: const TextStyle(fontSize: 12, color: kSage)),
                Text(d['status'] ?? '',
                    style: const TextStyle(fontSize: 12, color: kTerra)),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSand,
      body: RefreshIndicator(
        color: kTeal,
        onRefresh: _fetchAll,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              // ── Header
              Container(
                width: double.infinity,
                color: kTeal,
                padding: const EdgeInsets.fromLTRB(20, 55, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Center(
                      child: Text('Algeria',
                          style: TextStyle(fontSize: 13, color: kWhite)),
                    ),
                    const SizedBox(height: 10),
                    const Text('Welcome !',
                        style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: kWhite)),
                    const SizedBox(height: 16),
                    Container(
                      height: 50,
                      decoration: BoxDecoration(
                          color: kWhite,
                          borderRadius: BorderRadius.circular(30)),
                      child: Row(children: [
                        const SizedBox(width: 16),
                        const Expanded(
                          child: TextField(
                            decoration: InputDecoration(
                              hintText: 'Search For Donations',
                              hintStyle: TextStyle(color: kSage, fontSize: 14),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding:
                                  EdgeInsets.symmetric(vertical: 8),
                            ),
                          ),
                        ),
                        Container(
                          width: 50,
                          height: 50,
                          decoration: const BoxDecoration(
                            color: kTerra,
                            borderRadius: BorderRadius.only(
                              topRight: Radius.circular(30),
                              bottomRight: Radius.circular(30),
                            ),
                          ),
                          child: const Icon(Icons.search,
                              color: kWhite, size: 22),
                        ),
                      ]),
                    ),
                  ],
                ),
              ),

              // ── Body
              Container(
                color: kSand,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Live Map
                    Container(
                      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      decoration: BoxDecoration(
                          color: kWhite,
                          borderRadius: BorderRadius.circular(16)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.fromLTRB(16, 14, 16, 8),
                            child: Text('Live Map',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: kTeal)),
                          ),
                          ClipRRect(
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(16),
                              bottomRight: Radius.circular(16),
                            ),
                            child: SizedBox(
                              height: 200,
                              child: FlutterMap(
                                mapController: _mapController,
                                options: MapOptions(
                                  initialCenter: _mapCenter,
                                  initialZoom: 13,
                                ),
                                children: [
                                  TileLayer(
                                    urlTemplate:
                                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                    userAgentPackageName: 'com.madad.app',
                                  ),
                                  MarkerLayer(markers: _markers),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── Nearby Donations heading + View All
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Nearby Donations',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: kTeal)),
                          GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const AllDonationsScreen()),
                            ),
                            child: Row(children: const [
                              Text('View All',
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: kTerra,
                                      fontWeight: FontWeight.w600)),
                              SizedBox(width: 2),
                              Icon(Icons.chevron_right,
                                  color: kTerra, size: 18),
                            ]),
                          ),
                        ],
                      ),
                    ),

                    // Donation cards
                    SizedBox(
                      height: 230,
                      child: _isLoading
                          ? const Center(
                              child: CircularProgressIndicator(color: kTeal))
                          : _error != null
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.wifi_off,
                                          color: kSage, size: 32),
                                      const SizedBox(height: 8),
                                      const Text('Could not load donations',
                                          style: TextStyle(
                                              color: kSage, fontSize: 13)),
                                      TextButton(
                                        onPressed: _fetchAll,
                                        child: const Text('Retry',
                                            style:
                                                TextStyle(color: kTeal)),
                                      ),
                                    ],
                                  ))
                              : _donations.isEmpty
                                  ? Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.inbox_outlined,
                                              color: kSage, size: 36),
                                          const SizedBox(height: 8),
                                          const Text(
                                            'No donations yet.\nBe the first to post!',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                                color: kSage, fontSize: 13),
                                          ),
                                          TextButton(
                                            onPressed: _openAddDonation,
                                            child: const Text('Post Now',
                                                style: TextStyle(
                                                    color: kTeal)),
                                          ),
                                        ],
                                      ))
                                  : ListView.separated(
                                      scrollDirection: Axis.horizontal,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16),
                                      itemCount: _donations.length,
                                      separatorBuilder: (_, __) =>
                                          const SizedBox(width: 12),
                                      itemBuilder: (_, i) =>
                                          _buildCard(_donations[i]),
                                    ),
                    ),

                    const SizedBox(height: 14),

                    // Post button
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kTerra,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: _openAddDonation,
                          icon: const Icon(Icons.add_circle_outline,
                              color: kWhite, size: 22),
                          label: const Text('Post A New Donation',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: kWhite)),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Stats card
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                            color: kWhite,
                            borderRadius: BorderRadius.circular(16)),
                        child: _statsLoading
                            ? const SizedBox(
                                height: 120,
                                child: Center(
                                  child: CircularProgressIndicator(
                                      color: kTeal),
                                ),
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Your Activity Statistics',
                                      style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: kTeal)),
                                  const SizedBox(height: 18),
                                  _buildStat(
                                    'Donations',
                                    _donationCount,
                                    kTeal,
                                    (_donationCount / 10.0).clamp(0.0, 1.0),
                                  ),
                                  const SizedBox(height: 14),
                                  _buildStat(
                                    'Reservations',
                                    _requestCount,
                                    kTerra,
                                    (_requestCount / 10.0).clamp(0.0, 1.0),
                                  ),
                                  const SizedBox(height: 14),
                                  _buildStat(
                                    'Food Saved',
                                    _foodSavedKg > 0
                                        ? double.parse(
                                            _foodSavedKg.toStringAsFixed(1))
                                        : 0,
                                    kSage,
                                    (_foodSavedKg / 50.0).clamp(0.0, 1.0),
                                    suffix: ' Kg',
                                  ),
                                  const SizedBox(height: 14),
                                  _buildReputation(),
                                ],
                              ),
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const SharedBottomNav(currentIndex: 0),
    );
  }

  Widget _buildCard(Map<String, dynamic> d) {
    const String base = 'https://gasp-test-production.up.railway.app/';
    final String title = d['title'] ?? 'Donation';
    final String cat = d['category'] ?? '';
    final String status = d['status'] ?? 'available';
    final bool urgent = d['isUrgent'] == true;
    final Color statusColor =
        status == 'available' ? Colors.green : kTerra;
    final String? photo = d['photoUrl'] as String?;

    return Container(
      width: 125,
      decoration: BoxDecoration(
          color: kWhite, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(14),
              topRight: Radius.circular(14),
            ),
            child: SizedBox(
              height: 95,
              width: 125,
              child: photo != null && photo.isNotEmpty
                  ? Image.network(
                      photo.startsWith('http') ? photo : '$base$photo',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                          color: kSage,
                          child: const Icon(Icons.fastfood,
                              color: kWhite, size: 32)),
                    )
                  : Container(
                      color: kSage,
                      child: const Icon(Icons.fastfood,
                          color: kWhite, size: 32)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87)),
                  ),
                  if (urgent)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                          color: kTerra,
                          borderRadius: BorderRadius.circular(4)),
                      child: const Text('!',
                          style: TextStyle(
                              fontSize: 9,
                              color: kWhite,
                              fontWeight: FontWeight.bold)),
                    ),
                ]),
                const SizedBox(height: 3),
                Text(cat,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10, color: kSage)),
                const SizedBox(height: 3),
                Row(children: [
                  Icon(Icons.circle, size: 6, color: statusColor),
                  const SizedBox(width: 4),
                  Text(status,
                      style: TextStyle(fontSize: 10, color: statusColor)),
                ]),
                const SizedBox(height: 8),
                Container(
                  height: 28,
                  width: double.infinity,
                  decoration: BoxDecoration(
                      color: kTerra,
                      borderRadius: BorderRadius.circular(20)),
                  child: const Center(
                    child: Text('Reserve',
                        style: TextStyle(
                            fontSize: 10,
                            color: kWhite,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String label, num value, Color color, double ratio,
      {String suffix = ''}) {
    return Row(children: [
      SizedBox(
        width: 90,
        child: Text(label,
            style: const TextStyle(fontSize: 13, color: Colors.black87)),
      ),
      Expanded(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: ratio,
            backgroundColor: const Color(0xFFE8E3DA),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 9,
          ),
        ),
      ),
      const SizedBox(width: 10),
      Text('$value$suffix',
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.black87)),
    ]);
  }

  Widget _buildReputation() {
    final filled = _reputation.clamp(0.0, 5.0);
    return Row(children: [
      const SizedBox(
        width: 90,
        child: Text('Reputation',
            style: TextStyle(fontSize: 13, color: Colors.black87)),
      ),
      Row(
        children: List.generate(5, (i) {
          final starValue = i + 1;
          IconData icon;
          if (filled >= starValue) {
            icon = Icons.star;
          } else if (filled >= starValue - 0.5) {
            icon = Icons.star_half;
          } else {
            icon = Icons.star_border;
          }
          return Icon(icon, color: Colors.amber, size: 20);
        }),
      ),
      const SizedBox(width: 8),
      Text(
        _reputation > 0 ? _reputation.toStringAsFixed(1) : '—',
        style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.black54),
      ),
    ]);
  }
}