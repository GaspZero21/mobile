import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../theme/colors.dart';
import '../widgets/shared_bottom_nav.dart';
import '../services/donation_service.dart';
import '../services/reservation_service.dart';
import '../services/app_token.dart';
import 'add_donation_screen.dart';
import 'all_donations_screen.dart';
import '../widgets/quantity_picker_sheet.dart';
import '../main.dart'; // MadadLogo

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const String _baseUrl =
      'https://gasp-test-production.up.railway.app/api/v1';
  static const String _imgBase =
      'https://gasp-test-production.up.railway.app/';

  List<Map<String, dynamic>> _donations = [];
  bool _isLoading = true;
  String? _error;

  /// Tracks how many units the current user reserved per donation (this session).
  final Map<String, double> _reservedCounts = {};

  // ── Stats
  int _donationCount = 0;
  int _requestCount = 0;
  double _foodSavedKg = 0.0;
  double _reputation = 0.0;
  bool _statsLoading = true;

  // ── Filters
  static const _categories = [
    {'label': 'All', 'value': ''},
    {'label': '🥦 Fruits & Veg', 'value': 'fruits_vegetables'},
    {'label': '🌾 Dry Goods', 'value': 'dry_goods'},
    {'label': '🍲 Cooked Meal', 'value': 'cooked_meal'},
    {'label': '🥛 Dairy', 'value': 'dairy'},
    {'label': '🥖 Bakery', 'value': 'bakery'},
    {'label': '📦 Other', 'value': 'other'},
  ];
  String _activeCategory = '';
  bool? _filterUrgent;

  // Oran, Algeria
  static const _oranCenter = LatLng(35.6969, -0.6331);
  LatLng _mapCenter = _oranCenter;

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
    await Future.wait([_fetchDonations(), _fetchStats()]);
  }

  Future<void> _fetchDonations() async {
    try {
      final data = await DonationService().getDonations(
        category:
            _activeCategory.isEmpty ? null : _activeCategory,
        isUrgent: _filterUrgent,
      );
      if (!mounted) return;

      LatLng? firstCoord;
      for (final d in data) {
        final lat =
            double.tryParse(d['latitude']?.toString() ?? '');
        final lng =
            double.tryParse(d['longitude']?.toString() ?? '');
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

      try {
        _mapController.move(firstCoord ?? _oranCenter, 13);
      } catch (_) {}
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

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
      final responses = await Future.wait([
        http.get(Uri.parse('$_baseUrl/users/me'),
            headers: headers),
        http.get(Uri.parse('$_baseUrl/donations/my'),
            headers: headers),
        http.get(Uri.parse('$_baseUrl/reservations'),
            headers: headers),
      ]);
      if (!mounted) return;

      if (responses[0].statusCode == 200) {
        final body = jsonDecode(responses[0].body)
            as Map<String, dynamic>;
        _reputation =
            _pickDouble(body, ['data', 'user', 'rating']) ??
                _pickDouble(
                    body, ['data', 'user', 'reputation']) ??
                _pickDouble(body, ['data', 'rating']) ??
                0.0;
      }
      if (responses[1].statusCode == 200) {
        final body = jsonDecode(responses[1].body)
            as Map<String, dynamic>;
        final list =
            _pickList(body, ['data', 'donations']) ??
                _pickList(body, ['data']) ??
                _pickList(body, ['donations']) ??
                [];
        _donationCount = list.length;
        double kg = 0.0;
        for (final item in list) {
          if (item is Map) {
            kg += (_numField(item, 'quantityKg') ??
                _numField(item, 'totalQuantity') ??
                _numField(item, 'quantity') ??
                0.0);
          }
        }
        _foodSavedKg = kg;
      }
      if (responses[2].statusCode == 200) {
        final body = jsonDecode(responses[2].body)
            as Map<String, dynamic>;
        final list =
            _pickList(body, ['data', 'reservations']) ??
                _pickList(body, ['data']) ??
                _pickList(body, ['reservations']) ??
                [];
        _requestCount = list.length;
      }
      if (mounted) setState(() => _statsLoading = false);
    } catch (_) {
      if (mounted) setState(() => _statsLoading = false);
    }
  }

  // ── JSON helpers ──────────────────────────────────────────────────────────
  List<dynamic>? _pickList(
      Map<String, dynamic> map, List<String> keys) {
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

  double? _pickDouble(
      Map<String, dynamic> map, List<String> keys) {
    dynamic cur = map;
    for (final k in keys) {
      if (cur is Map && cur.containsKey(k)) {
        cur = cur[k];
      } else {
        return null;
      }
    }
    return cur is num ? cur.toDouble() : null;
  }

  double? _numField(Map item, String key) {
    final v = item[key];
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  // ── Marker color ──────────────────────────────────────────────────────────
  Color _markerColor(Map<String, dynamic> d) {
    final apiColor =
        (d['markerColor'] ?? '').toString().toLowerCase();
    if (apiColor == 'red') return Colors.red;
    if (apiColor == 'orange') return Colors.orange;
    if (apiColor == 'green') return Colors.green;
    if (d['isUrgent'] == true) return Colors.red;
    final cat =
        (d['category'] ?? '').toString().toLowerCase();
    if (cat == 'cooked_meal' || cat == 'dairy') {
      return Colors.red;
    }
    if (cat == 'dry_goods') return Colors.orange;
    return Colors.green;
  }

  // ── Quantity badge ─────────────────────────────────────────────────────────
  Widget _buildQuantityBadge(Map<String, dynamic> d) {
    final donationId =
        d['id']?.toString() ?? d['_id']?.toString() ?? '';
    final totalQty = d['totalQuantity'];
    final unit = d['quantityUnit']?.toString() ?? '';
    final legacyQty = d['quantity']?.toString() ?? '';
    final remaining =
        d['remainingQuantity'] ?? d['availableQuantity'];

    String total = '';
    if (totalQty != null) {
      total = unit.isNotEmpty
          ? '${_fmtNum(totalQty)} $unit'
          : _fmtNum(totalQty);
    } else if (legacyQty.isNotEmpty) {
      total = legacyQty;
    }

    if (total.isEmpty && remaining == null) {
      return const SizedBox.shrink();
    }

    final String label = remaining != null
        ? '${_fmtNum(remaining)} / $total left'
        : total;

    Color pillColor = kTeal;
    if (remaining != null && totalQty != null) {
      final totalNum =
          double.tryParse(totalQty.toString()) ?? 0;
      final remNum =
          double.tryParse(remaining.toString()) ?? 0;
      if (totalNum > 0) {
        final pct = remNum / totalNum;
        if (pct < 0.1) {
          pillColor = Colors.red;
        } else if (pct < 0.3) {
          pillColor = Colors.orange;
        }
      }
    }

    final double myCount =
        _reservedCounts[donationId] ?? 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Stock badge
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: pillColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: pillColor.withOpacity(0.3)),
          ),
          child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.inventory_2_outlined,
                    size: 9, color: pillColor),
                const SizedBox(width: 3),
                Flexible(
                  child: Text(label,
                      style: TextStyle(
                          fontSize: 9,
                          color: pillColor,
                          fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis),
                ),
              ]),
        ),
        // "You reserved N" badge
        if (myCount > 0) ...[
          const SizedBox(height: 3),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: Colors.green.withOpacity(0.35)),
            ),
            child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_outline,
                      size: 9, color: Colors.green),
                  const SizedBox(width: 3),
                  Text(
                    'You reserved ${_fmtNum(myCount)}',
                    style: const TextStyle(
                        fontSize: 9,
                        color: Colors.green,
                        fontWeight: FontWeight.w600),
                  ),
                ]),
          ),
        ],
      ],
    );
  }

  double _parseQtyNum(String raw) {
    final m = RegExp(r'[\d.]+').firstMatch(raw);
    return m != null
        ? double.tryParse(m.group(0)!) ?? 0.0
        : 0.0;
  }

  String _fmtNum(dynamic v) {
    final d = double.tryParse(v.toString()) ?? 0.0;
    return d == d.roundToDouble()
        ? d.toInt().toString()
        : d.toStringAsFixed(1);
  }

  // ── Map markers ───────────────────────────────────────────────────────────
  List<Marker> get _markers => _donations
      .where((d) =>
          d['latitude'] != null && d['longitude'] != null)
      .map((d) {
        final lat =
            double.tryParse(d['latitude'].toString()) ?? 0.0;
        final lng =
            double.tryParse(d['longitude'].toString()) ?? 0.0;
        final color = _markerColor(d);
        return Marker(
          point: LatLng(lat, lng),
          width: 44,
          height: 44,
          child: GestureDetector(
            onTap: () => _showDetailsModal(d),
            child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                          color: color.withOpacity(0.2),
                          shape: BoxShape.circle)),
                  Icon(Icons.location_on,
                      color: color, size: 36),
                ]),
          ),
        );
      })
      .toList();

  // ── Filter chips ──────────────────────────────────────────────────────────
  Widget _buildFilterChips() {
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding:
            const EdgeInsets.symmetric(horizontal: 16),
        children: [
          ..._categories.map((cat) {
            final isActive =
                _activeCategory == cat['value'];
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _activeCategory = cat['value']!;
                    _isLoading = true;
                  });
                  _fetchDonations();
                },
                child: AnimatedContainer(
                  duration:
                      const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: isActive ? kTeal : kWhite,
                    borderRadius:
                        BorderRadius.circular(20),
                    border: Border.all(
                        color: isActive
                            ? kTeal
                            : const Color(0xFFDDDDDD)),
                  ),
                  child: Text(cat['label']!,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: isActive
                              ? kWhite
                              : kSage)),
                ),
              ),
            );
          }),
          Container(
              width: 1,
              height: 24,
              margin: const EdgeInsets.symmetric(
                  horizontal: 4, vertical: 6),
              color: const Color(0xFFDDDDDD)),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () {
              setState(() {
                _filterUrgent =
                    _filterUrgent == true ? null : true;
                _isLoading = true;
              });
              _fetchDonations();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: _filterUrgent == true
                    ? Colors.red
                    : kWhite,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: _filterUrgent == true
                        ? Colors.red
                        : const Color(0xFFDDDDDD)),
              ),
              child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bolt,
                        size: 12,
                        color: _filterUrgent == true
                            ? kWhite
                            : Colors.orange),
                    const SizedBox(width: 4),
                    Text('Urgent',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: _filterUrgent == true
                                ? kWhite
                                : kSage)),
                  ]),
            ),
          ),
        ],
      ),
    );
  }

  // ── Details modal ─────────────────────────────────────────────────────────
  void _showDetailsModal(Map<String, dynamic> d) {
    final photo = d['photoUrl'] as String?;
    final title = d['title'] ?? 'Donation';
    final category = d['category'] ?? '';
    final donor = d['donor']?['name'] ?? '';
    final address = d['pickupAddress'] ?? '';
    final pickupType = d['pickupType'] ?? '';
    final status = d['status'] ?? 'available';
    final distance = d['distance'] != null
        ? '${d['distance']} m away'
        : '';
    final description = d['description'] ?? '';
    final expiresAt =
        d['expiresAt'] ?? d['expiredAt'] ?? '';
    final urgent = d['isUrgent'] == true;
    final color = _markerColor(d);

    final totalQty = d['totalQuantity'];
    final unit = d['quantityUnit']?.toString() ?? '';
    final qtyStr = totalQty != null
        ? (unit.isNotEmpty
            ? '${_fmtNum(totalQty)} $unit'
            : _fmtNum(totalQty))
        : (d['quantity']?.toString() ?? '');

    final colorLabel = color == Colors.red
        ? (urgent ? 'URGENT' : 'PERISHABLE')
        : color == Colors.orange
            ? 'DRY GOODS'
            : 'FRESH';

    showDialog(
      context: context,
      barrierColor: Colors.black38,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.symmetric(
            horizontal: 20, vertical: 50),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24)),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(children: [
                  SizedBox(
                      height: 200,
                      width: double.infinity,
                      child: photo != null &&
                              photo.isNotEmpty
                          ? Image.network(
                              photo.startsWith('http')
                                  ? photo
                                  : '$_imgBase$photo',
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  _photoPlaceholder())
                          : _photoPlaceholder()),
                  Positioned(
                      top: 10,
                      left: 10,
                      child: GestureDetector(
                        onTap: () =>
                            Navigator.pop(context),
                        child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                                color: kWhite
                                    .withOpacity(0.9),
                                shape: BoxShape.circle),
                            child: const Icon(Icons.close,
                                size: 18, color: kSage)),
                      )),
                  Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                            color: color,
                            borderRadius:
                                BorderRadius.circular(20)),
                        child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.circle,
                                  color: Colors.white,
                                  size: 8),
                              const SizedBox(width: 4),
                              Text(colorLabel,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight:
                                          FontWeight.bold)),
                            ]),
                      )),
                  if (urgent)
                    Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          color:
                              Colors.red.withOpacity(0.85),
                          padding: const EdgeInsets.symmetric(
                              vertical: 4),
                          child: const Text(
                              '⚡ URGENT — Pick up as soon as possible!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight:
                                      FontWeight.bold)),
                        )),
                ]),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      20, 16, 20, 20),
                  child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: kTeal)),
                        if (category.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding:
                                const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 3),
                            decoration: BoxDecoration(
                                color:
                                    kTeal.withOpacity(0.1),
                                borderRadius:
                                    BorderRadius.circular(
                                        12)),
                            child: Text(category,
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: kTeal,
                                    fontWeight:
                                        FontWeight.w600)),
                          ),
                        ],
                        const SizedBox(height: 14),
                        const Divider(
                            height: 1,
                            color: Color(0xFFEEEEEE)),
                        const SizedBox(height: 14),
                        if (donor.isNotEmpty)
                          _infoRow(Icons.person_outline,
                              'Donor', donor),
                        if (address.isNotEmpty)
                          _infoRow(
                              Icons.location_on_outlined,
                              'Pickup Address',
                              address),
                        if (distance.isNotEmpty)
                          _infoRow(Icons.near_me_outlined,
                              'Distance', distance),
                        if (pickupType.isNotEmpty)
                          _infoRow(
                              Icons.directions_outlined,
                              'Pickup Type',
                              pickupType),
                        if (qtyStr.isNotEmpty)
                          _infoRow(Icons.scale_outlined,
                              'Quantity', qtyStr),
                        if (expiresAt.isNotEmpty)
                          _infoRow(
                              Icons.schedule_outlined,
                              'Expires',
                              _formatDate(expiresAt)),
                        _infoRow(Icons.circle, 'Status',
                            status,
                            valueColor:
                                status == 'available'
                                    ? Colors.green
                                    : kTerra),
                        if (description.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          const Text('Description',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight:
                                      FontWeight.bold,
                                  color:
                                      Colors.black87)),
                          const SizedBox(height: 4),
                          Text(description,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: kSage,
                                  height: 1.5)),
                        ],
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style:
                                ElevatedButton.styleFrom(
                              backgroundColor: kTerra,
                              elevation: 0,
                              padding:
                                  const EdgeInsets.symmetric(
                                      vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(
                                          20)),
                            ),
                            onPressed: () {
                              Navigator.pop(context);
                              _showConfirmModal(d);
                            },
                            child: const Text(
                                'Reserve This Donation',
                                style: TextStyle(
                                    color: kWhite,
                                    fontSize: 15,
                                    fontWeight:
                                        FontWeight.bold)),
                          ),
                        ),
                      ]),
                ),
              ]),
        ),
      ),
    );
  }

  // ── Confirm modal ─────────────────────────────────────────────────────────
  void _showConfirmModal(Map<String, dynamic> d) {
    final photo = d['photoUrl'] as String?;
    final title = d['title'] ?? 'Donation';
    final category = d['category'] ?? '';
    final donor = d['donor']?['name'] ?? '';
    final address = d['pickupAddress'] ?? '';
    final pickupType = d['pickupType'] ?? '';
    final status = d['status'] ?? 'available';
    final distance = d['distance'] != null
        ? '${d['distance']} m away'
        : '';

    final totalQty = d['totalQuantity'];
    final unit = d['quantityUnit']?.toString() ?? '';
    final totalQtyStr = totalQty != null
        ? (unit.isNotEmpty
            ? '${_fmtNum(totalQty)} $unit'
            : _fmtNum(totalQty))
        : (d['quantity']?.toString() ?? '');

    final remaining =
        d['remainingQuantity'] ?? d['availableQuantity'];
    final remainingNum = remaining != null
        ? double.tryParse(remaining.toString())
        : (totalQty != null
            ? double.tryParse(totalQty.toString())
            : (totalQtyStr.isNotEmpty
                ? _parseQtyNum(totalQtyStr)
                : null));

    final bool canSplit =
        remainingNum != null && remainingNum > 0;

    showDialog(
      context: context,
      barrierColor: Colors.black38,
      builder: (dialogCtx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(
            horizontal: 24, vertical: 60),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24)),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Center(
                    child: Text(
                        'Confirm Your Reservation',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: kTeal))),
                const SizedBox(height: 14),
                if (photo != null && photo.isNotEmpty)
                  ClipRRect(
                    borderRadius:
                        BorderRadius.circular(14),
                    child: SizedBox(
                        height: 160,
                        width: double.infinity,
                        child: Image.network(
                          photo.startsWith('http')
                              ? photo
                              : '$_imgBase$photo',
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _photoPlaceholder(),
                        )),
                  ),
                const SizedBox(height: 14),
                _detailRow('Title :', title),
                _detailRow('Category :', category),
                if (donor.isNotEmpty)
                  _detailRow('Donor :', donor),
                if (distance.isNotEmpty)
                  _detailRow('Distance :', distance),
                _detailRow('Pickup Address:', address),
                if (pickupType.isNotEmpty)
                  _detailRow('Pickup Type:', pickupType),
                _detailRow('Status:', status),
                if (totalQtyStr.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: kTeal.withOpacity(0.06),
                        borderRadius:
                            BorderRadius.circular(12)),
                    child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          const Text('Quantity Info',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight:
                                      FontWeight.w700,
                                  color: kTeal)),
                          const SizedBox(height: 6),
                          Row(children: [
                            const Icon(
                                Icons.inventory_2_outlined,
                                size: 13,
                                color: kTeal),
                            const SizedBox(width: 6),
                            Text('Total: $totalQtyStr',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color:
                                        Colors.black87)),
                          ]),
                          if (remaining != null) ...[
                            const SizedBox(height: 4),
                            Row(children: [
                              const Icon(
                                  Icons
                                      .check_circle_outline,
                                  size: 13,
                                  color: Colors.green),
                              const SizedBox(width: 6),
                              Text(
                                'Still available: ${_fmtNum(remaining)}',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.green,
                                    fontWeight:
                                        FontWeight.w600),
                              ),
                            ]),
                          ],
                          if (canSplit) ...[
                            const SizedBox(height: 4),
                            const Text(
                              '💡 You can reserve a part of this donation',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: kSage),
                            ),
                          ],
                        ]),
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () =>
                          Navigator.pop(dialogCtx),
                      child: const Text('Cancel',
                          style: TextStyle(
                              color: kTerra,
                              fontSize: 14,
                              fontWeight:
                                  FontWeight.w600)),
                    ),
                    Row(children: [
                      if (canSplit) ...[
                        ElevatedButton(
                          style:
                              ElevatedButton.styleFrom(
                                  backgroundColor: kTeal,
                                  elevation: 0,
                                  padding: const EdgeInsets
                                      .symmetric(
                                      horizontal: 14,
                                      vertical: 12),
                                  shape:
                                      RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius
                                                  .circular(
                                                      20))),
                          onPressed: () async {
                            Navigator.pop(dialogCtx);
                            final qty =
                                await showQuantityPickerSheet(
                                    context,
                                    totalQuantity:
                                        totalQtyStr,
                                    remainingQty:
                                        remainingNum);
                            if (qty != null && mounted) {
                              await _doReserve(d,
                                  quantity: qty);
                            }
                          },
                          child: const Text('Pick Amount',
                              style: TextStyle(
                                  color: kWhite,
                                  fontWeight:
                                      FontWeight.bold,
                                  fontSize: 12)),
                        ),
                        const SizedBox(width: 8),
                      ],
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: kTerra,
                            elevation: 0,
                            padding:
                                const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(
                                        20))),
                        onPressed: () async {
                          Navigator.pop(dialogCtx);
                          await _doReserve(d);
                        },
                        icon: const Icon(
                            Icons
                                .shopping_basket_outlined,
                            color: kWhite,
                            size: 18),
                        label: Text(
                            canSplit
                                ? 'Reserve All'
                                : 'Confirm',
                            style: const TextStyle(
                                color: kWhite,
                                fontWeight:
                                    FontWeight.bold)),
                      ),
                    ]),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Reserve ───────────────────────────────────────────────────────────────
  Future<void> _doReserve(Map<String, dynamic> d,
      {double? quantity}) async {
    final donationId =
        d['id']?.toString() ?? d['_id']?.toString() ?? '';
    if (donationId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Could not identify donation'),
              backgroundColor: Colors.red));
      return;
    }

    final double reservedQty = quantity ?? 1.0;

    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
            child: CircularProgressIndicator(color: kTeal)));

    try {
      await ReservationService()
          .createReservation(donationId, quantity: reservedQty);
      if (!mounted) return;
      Navigator.pop(context);

      setState(() {
        // Increment the "you reserved" counter
        _reservedCounts[donationId] =
            (_reservedCounts[donationId] ?? 0.0) +
                reservedQty;

        // Decrease remainingQuantity locally so badge updates immediately
        final idx = _donations.indexWhere((item) =>
            (item['id']?.toString() ??
                item['_id']?.toString()) ==
            donationId);
        if (idx != -1) {
          final current = double.tryParse(
                  _donations[idx]['remainingQuantity']
                          ?.toString() ??
                      _donations[idx]['quantity']
                          ?.toString() ??
                      '0') ??
              0.0;
          final newRemaining =
              (current - reservedQty).clamp(0.0, current);
          _donations[idx] =
              Map<String, dynamic>.from(_donations[idx])
                ..['remainingQuantity'] = newRemaining;
          // Only remove when fully depleted
          if (newRemaining <= 0) _donations.removeAt(idx);
        }
      });

      final msg = quantity != null
          ? 'Reserved ${reservedQty % 1 == 0 ? reservedQty.toInt() : reservedQty.toStringAsFixed(1)} units! Waiting for donor to accept.'
          : 'Reservation sent! Waiting for donor to accept (within 2h).';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(msg),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4)));

      _fetchStats();
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red));
    }
  }

  Future<void> _openAddDonation() async {
    final result = await Navigator.push<bool>(context,
        MaterialPageRoute(
            builder: (_) => const AddDonationScreen()));
    if (result == true) _fetchAll();
  }

  Widget _photoPlaceholder() => Container(
      color: kSage,
      child: const Center(
          child:
              Icon(Icons.fastfood, color: kWhite, size: 48)));

  Widget _infoRow(IconData icon, String label, String value,
      {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: kSage),
            const SizedBox(width: 8),
            SizedBox(
                width: 110,
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87))),
            Expanded(
                child: Text(value,
                    style: TextStyle(
                        fontSize: 12,
                        color: valueColor ?? kSage,
                        fontWeight: valueColor != null
                            ? FontWeight.w600
                            : FontWeight.normal))),
          ]),
    );
  }

  Widget _detailRow(String label, String value) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
                width: 110,
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87))),
            Expanded(
                child: Text(value,
                    style: const TextStyle(
                        fontSize: 13, color: kSage))),
          ]));

  String _formatDate(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────
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
              // ── Teal header
              Container(
                width: double.infinity,
                color: kTeal,
                padding: const EdgeInsets.fromLTRB(
                    20, 55, 20, 16),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: MadadLogo(
                        height: 70,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 14),
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
                          borderRadius:
                              BorderRadius.circular(30)),
                      child: Row(children: [
                        const SizedBox(width: 16),
                        const Expanded(
                          child: TextField(
                            decoration: InputDecoration(
                              hintText:
                                  'Search For Donations',
                              hintStyle: TextStyle(
                                  color: kSage,
                                  fontSize: 14),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding:
                                  EdgeInsets.symmetric(
                                      vertical: 8),
                            ),
                          ),
                        ),
                        Container(
                          width: 50,
                          height: 50,
                          decoration: const BoxDecoration(
                            color: kTerra,
                            borderRadius: BorderRadius.only(
                              topRight:
                                  Radius.circular(30),
                              bottomRight:
                                  Radius.circular(30),
                            ),
                          ),
                          child: const Icon(Icons.search,
                              color: kWhite, size: 22),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 12),
                    _buildFilterChips(),
                    const SizedBox(height: 4),
                  ],
                ),
              ),

              // ── Body
              Container(
                color: kSand,
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    // Live Map
                    Container(
                      margin: const EdgeInsets.fromLTRB(
                          16, 16, 16, 0),
                      decoration: BoxDecoration(
                          color: kWhite,
                          borderRadius:
                              BorderRadius.circular(16)),
                      child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(
                                      16, 14, 16, 4),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment
                                        .spaceBetween,
                                children: [
                                  const Text('Live Map',
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight:
                                              FontWeight
                                                  .bold,
                                          color: kTeal)),
                                  Row(children: [
                                    _legendDot(Colors.green,
                                        'Fresh'),
                                    const SizedBox(
                                        width: 8),
                                    _legendDot(Colors.orange,
                                        'Dry'),
                                    const SizedBox(
                                        width: 8),
                                    _legendDot(Colors.red,
                                        'Urgent'),
                                  ]),
                                ],
                              ),
                            ),
                            ClipRRect(
                              borderRadius:
                                  const BorderRadius.only(
                                bottomLeft:
                                    Radius.circular(16),
                                bottomRight:
                                    Radius.circular(16),
                              ),
                              child: SizedBox(
                                height: 200,
                                child: FlutterMap(
                                  mapController:
                                      _mapController,
                                  options: MapOptions(
                                      initialCenter:
                                          _oranCenter,
                                      initialZoom: 13),
                                  children: [
                                    TileLayer(
                                      urlTemplate:
                                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                      userAgentPackageName:
                                          'com.madad.app',
                                    ),
                                    MarkerLayer(
                                        markers: _markers),
                                  ],
                                ),
                              ),
                            ),
                          ]),
                    ),

                    // Nearby heading
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                          16, 18, 16, 10),
                      child: Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              _activeCategory.isEmpty &&
                                      _filterUrgent == null
                                  ? 'Nearby Donations'
                                  : 'Filtered Donations',
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: kTeal),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const AllDonationsScreen())),
                            child: Row(children: const [
                              Text('View All',
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: kTerra,
                                      fontWeight:
                                          FontWeight.w600)),
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
                              child:
                                  CircularProgressIndicator(
                                      color: kTeal))
                          : _error != null
                              ? Center(
                                  child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment
                                              .center,
                                      children: [
                                        const Icon(
                                            Icons.wifi_off,
                                            color: kSage,
                                            size: 32),
                                        const SizedBox(
                                            height: 8),
                                        const Text(
                                            'Could not load donations',
                                            style: TextStyle(
                                                color: kSage,
                                                fontSize:
                                                    13)),
                                        TextButton(
                                            onPressed:
                                                _fetchAll,
                                            child: const Text(
                                                'Retry',
                                                style: TextStyle(
                                                    color:
                                                        kTeal))),
                                      ]))
                              : _donations.isEmpty
                                  ? Center(
                                      child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment
                                                  .center,
                                          children: [
                                            const Icon(
                                                Icons
                                                    .inbox_outlined,
                                                color: kSage,
                                                size: 36),
                                            const SizedBox(
                                                height: 8),
                                            Text(
                                              _activeCategory
                                                          .isNotEmpty ||
                                                      _filterUrgent !=
                                                          null
                                                  ? 'No donations match this filter'
                                                  : 'No donations yet.\nBe the first to post!',
                                              textAlign:
                                                  TextAlign
                                                      .center,
                                              style: const TextStyle(
                                                  color: kSage,
                                                  fontSize:
                                                      13),
                                            ),
                                            if (_activeCategory
                                                    .isEmpty &&
                                                _filterUrgent ==
                                                    null)
                                              TextButton(
                                                  onPressed:
                                                      _openAddDonation,
                                                  child: const Text(
                                                      'Post Now',
                                                      style: TextStyle(
                                                          color:
                                                              kTeal))),
                                          ]))
                                  : ListView.separated(
                                      scrollDirection:
                                          Axis.horizontal,
                                      padding:
                                          const EdgeInsets
                                              .symmetric(
                                              horizontal: 16),
                                      itemCount:
                                          _donations.length,
                                      separatorBuilder:
                                          (_, __) =>
                                              const SizedBox(
                                                  width: 12),
                                      itemBuilder: (_, i) =>
                                          _buildCard(
                                              _donations[i]),
                                    ),
                    ),

                    const SizedBox(height: 14),

                    // Post button
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16),
                      child: SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: kTerra,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(
                                          14))),
                          onPressed: _openAddDonation,
                          icon: const Icon(
                              Icons.add_circle_outline,
                              color: kWhite,
                              size: 22),
                          label: const Text(
                              'Post A New Donation',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: kWhite)),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Activity stats
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                            color: kWhite,
                            borderRadius:
                                BorderRadius.circular(16)),
                        child: _statsLoading
                            ? const SizedBox(
                                height: 120,
                                child: Center(
                                    child:
                                        CircularProgressIndicator(
                                            color: kTeal)))
                            : Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                      'Your Activity Statistics',
                                      style: TextStyle(
                                          fontSize: 15,
                                          fontWeight:
                                              FontWeight.bold,
                                          color: kTeal)),
                                  const SizedBox(height: 18),
                                  _buildStat(
                                      'Donations',
                                      _donationCount,
                                      kTeal,
                                      (_donationCount / 10.0)
                                          .clamp(0.0, 1.0)),
                                  const SizedBox(height: 14),
                                  _buildStat(
                                      'Reservations',
                                      _requestCount,
                                      kTerra,
                                      (_requestCount / 10.0)
                                          .clamp(0.0, 1.0)),
                                  const SizedBox(height: 14),
                                  _buildStat(
                                      'Food Saved',
                                      _foodSavedKg > 0
                                          ? double.parse(
                                              _foodSavedKg
                                                  .toStringAsFixed(
                                                      1))
                                          : 0,
                                      kSage,
                                      (_foodSavedKg / 50.0)
                                          .clamp(0.0, 1.0),
                                      suffix: ' '),
                                  const SizedBox(height: 14),
                                  _buildReputation(),
                                ]),
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
      bottomNavigationBar:
          const SharedBottomNav(currentIndex: 0),
    );
  }

  // ── Donation card ─────────────────────────────────────────────────────────
  Widget _buildCard(Map<String, dynamic> d) {
    final String title = d['title'] ?? 'Donation';
    final String cat = d['category'] ?? '';
    final String status = d['status'] ?? 'available';
    final bool urgent = d['isUrgent'] == true;
    final Color statusColor =
        status == 'available' ? Colors.green : kTerra;
    final String? photo = d['photoUrl'] as String?;
    final Color color = _markerColor(d);

    return GestureDetector(
      onTap: () => _showDetailsModal(d),
      child: Container(
        width: 125,
        decoration: BoxDecoration(
          color: kWhite,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(14),
                    topRight: Radius.circular(14)),
                child: Stack(children: [
                  SizedBox(
                    height: 95,
                    width: 125,
                    child: photo != null && photo.isNotEmpty
                        ? Image.network(
                            photo.startsWith('http')
                                ? photo
                                : '$_imgBase$photo',
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                Container(
                                    color: kSage,
                                    child: const Icon(
                                        Icons.fastfood,
                                        color: kWhite,
                                        size: 32)))
                        : Container(
                            color: kSage,
                            child: const Icon(Icons.fastfood,
                                color: kWhite, size: 32)),
                  ),
                  Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Colors.white,
                              width: 1.5),
                          boxShadow: [
                            BoxShadow(
                                color:
                                    color.withOpacity(0.4),
                                blurRadius: 4,
                                spreadRadius: 1)
                          ],
                        ),
                      )),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                            child: Text(title,
                                maxLines: 1,
                                overflow:
                                    TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight:
                                        FontWeight.bold,
                                    color:
                                        Colors.black87))),
                        if (urgent)
                          Container(
                            padding:
                                const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 1),
                            decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius:
                                    BorderRadius.circular(
                                        4)),
                            child: const Text('!',
                                style: TextStyle(
                                    fontSize: 9,
                                    color: kWhite,
                                    fontWeight:
                                        FontWeight.bold)),
                          ),
                      ]),
                      const SizedBox(height: 3),
                      Text(cat,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 10, color: kSage)),
                      const SizedBox(height: 3),
                      _buildQuantityBadge(d),
                      const SizedBox(height: 4),
                      Row(children: [
                        Icon(Icons.circle,
                            size: 6, color: statusColor),
                        const SizedBox(width: 4),
                        Text(status,
                            style: TextStyle(
                                fontSize: 10,
                                color: statusColor)),
                      ]),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () => _showDetailsModal(d),
                        child: Container(
                          height: 28,
                          width: double.infinity,
                          decoration: BoxDecoration(
                              color: kTerra,
                              borderRadius:
                                  BorderRadius.circular(20)),
                          child: const Center(
                            child: Text('Reserve',
                                style: TextStyle(
                                    fontSize: 10,
                                    color: kWhite,
                                    fontWeight:
                                        FontWeight.bold)),
                          ),
                        ),
                      ),
                    ]),
              ),
            ]),
      ),
    );
  }

  Widget _legendDot(Color color, String label) =>
      Row(children: [
        Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
                color: color, shape: BoxShape.circle)),
        const SizedBox(width: 3),
        Text(label,
            style:
                const TextStyle(fontSize: 9, color: kSage)),
      ]);

  Widget _buildStat(String label, num value, Color color,
      double ratio,
      {String suffix = ''}) {
    return Row(children: [
      SizedBox(
          width: 90,
          child: Text(label,
              style: const TextStyle(
                  fontSize: 13, color: Colors.black87))),
      Expanded(
          child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: LinearProgressIndicator(
            value: ratio,
            backgroundColor: const Color(0xFFE8E3DA),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 9),
      )),
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
              style: TextStyle(
                  fontSize: 13, color: Colors.black87))),
      Row(
          children: List.generate(5, (i) {
        final v = i + 1;
        return Icon(
            filled >= v
                ? Icons.star
                : filled >= v - 0.5
                    ? Icons.star_half
                    : Icons.star_border,
            color: Colors.amber,
            size: 20);
      })),
      const SizedBox(width: 8),
      Text(
          _reputation > 0
              ? _reputation.toStringAsFixed(1)
              : '—',
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.black54)),
    ]);
  }
}