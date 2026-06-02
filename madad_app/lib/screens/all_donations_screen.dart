import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../services/donation_service.dart';
import '../services/reservation_service.dart';
import '../widgets/shared_bottom_nav.dart';
import '../widgets/quantity_picker_sheet.dart';
import '../widgets/report_user_sheet.dart';

class AllDonationsScreen extends StatefulWidget {
  const AllDonationsScreen({super.key});

  @override
  State<AllDonationsScreen> createState() =>
      _AllDonationsScreenState();
}

class _AllDonationsScreenState extends State<AllDonationsScreen> {
  static const String base =
      'https://gasp-test-production.up.railway.app/';

  List<Map<String, dynamic>> _all = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _isLoading = true;
  String? _error;
  final _searchCtrl = TextEditingController();

  /// Tracks how many units the current user reserved per donation (this session).
  final Map<String, double> _reservedCounts = {};

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

  @override
  void initState() {
    super.initState();
    _fetch();
    _searchCtrl.addListener(_applyLocalSearch);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await DonationService().getDonations(
        category:
            _activeCategory.isEmpty ? null : _activeCategory,
        isUrgent: _filterUrgent,
      );
      if (!mounted) return;
      setState(() {
        _all = data;
        _filtered = data;
        _isLoading = false;
      });
      _applyLocalSearch();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _applyLocalSearch() {
    final q = _searchCtrl.text.toLowerCase().trim();
    setState(() {
      _filtered = q.isEmpty
          ? _all
          : _all.where((d) {
              final title = (d['title'] ?? '').toLowerCase();
              final cat =
                  (d['category'] ?? '').toLowerCase();
              final address =
                  (d['pickupAddress'] ?? '').toLowerCase();
              return title.contains(q) ||
                  cat.contains(q) ||
                  address.contains(q);
            }).toList();
    });
  }

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
    final total = d['quantity']?.toString() ?? '';
    final remaining =
        d['remainingQuantity'] ?? d['availableQuantity'];

    if (total.isEmpty && remaining == null) {
      return const SizedBox.shrink();
    }

    final bool hasRemaining = remaining != null;
    final String label = hasRemaining
        ? '${_fmtNum(remaining)} / $total remaining'
        : total;

    Color pillColor = kTeal;
    if (hasRemaining) {
      final totalNum = _parseQtyNum(total);
      final remNum =
          _parseQtyNum(remaining.toString());
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
              horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: pillColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border:
                Border.all(color: pillColor.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.inventory_2_outlined,
                  size: 10, color: pillColor),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                      fontSize: 9,
                      color: pillColor,
                      fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        // "You reserved N" badge (shown only after a reservation)
        if (myCount > 0) ...[
          const SizedBox(height: 3),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 8, vertical: 3),
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
                    size: 10, color: Colors.green),
                const SizedBox(width: 4),
                Text(
                  'You reserved ${_fmtNum(myCount)}',
                  style: const TextStyle(
                      fontSize: 9,
                      color: Colors.green,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
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

  // ── Filter chips ───────────────────────────────────────────────────────────
  Widget _buildFilterChips() {
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 2),
        children: [
          ..._categories.map((cat) {
            final isActive = _activeCategory == cat['value'];
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _activeCategory = cat['value']!;
                    _isLoading = true;
                  });
                  _fetch();
                },
                child: AnimatedContainer(
                  duration:
                      const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
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
                          color:
                              isActive ? kWhite : kSage)),
                ),
              ),
            );
          }),
          Container(
              width: 1,
              height: 22,
              margin: const EdgeInsets.symmetric(
                  horizontal: 4, vertical: 7),
              color: const Color(0xFFDDDDDD)),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () {
              setState(() {
                _filterUrgent =
                    _filterUrgent == true ? null : true;
                _isLoading = true;
              });
              _fetch();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 6),
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

  // ── Details modal ──────────────────────────────────────────────────────────
  void _showDetailsModal(Map<String, dynamic> d) {
    final photo = d['photoUrl'] as String?;
    final title = d['title'] ?? 'Donation';
    final category = d['category'] ?? '';
    final donor = d['donor']?['name'] ?? '';
    final address = d['pickupAddress'] ?? '';
    final pickupType = d['pickupType'] ?? '';
    final status = d['status'] ?? 'available';
    final distance =
        d['distance'] != null ? '${d['distance']}m Away' : '';
    final urgent = d['isUrgent'] == true;
    final color = _markerColor(d);

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
            horizontal: 24, vertical: 60),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24)),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                children: [
                  SizedBox(
                    height: 200,
                    width: double.infinity,
                    child: photo != null && photo.isNotEmpty
                        ? Image.network(
                            photo.startsWith('http')
                                ? photo
                                : '$base$photo',
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                Container(
                                    color: kSage,
                                    child: const Icon(
                                        Icons.fastfood,
                                        color: kWhite,
                                        size: 48)),
                          )
                        : Container(
                            color: kSage,
                            child: const Icon(Icons.fastfood,
                                color: kWhite, size: 48)),
                  ),
                  Positioned(
                    top: 10,
                    left: 10,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                            color: kWhite.withOpacity(0.9),
                            shape: BoxShape.circle),
                        child: const Icon(Icons.close,
                            size: 18, color: kSage),
                      ),
                    ),
                  ),
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
                    ),
                  ),
                  if (urgent)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        color: Colors.red.withOpacity(0.85),
                        padding: const EdgeInsets.symmetric(
                            vertical: 4),
                        child: const Text(
                            '⚡ URGENT — Pick up as soon as possible!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                ],
              ),
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    _detailRow('Title :', title),
                    _detailRow('Category :', category),
                    _detailRow('Donor :', donor),
                    if (distance.isNotEmpty)
                      _detailRow('Location :', distance),
                    _detailRow('Pickup Address:', address),
                    if (pickupType.isNotEmpty)
                      _detailRow('Pickup Type:', pickupType),
                    _detailRow('Status:', status),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kTerra,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                              vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(20)),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          _showConfirmModal(d);
                        },
                        child: const Text('Reserve',
                            style: TextStyle(
                                color: kWhite,
                                fontSize: 15,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                    // After the Reserve ElevatedButton in the modal:
const SizedBox(height: 10),
SizedBox(
  width: double.infinity,
  child: OutlinedButton.icon(
    style: OutlinedButton.styleFrom(
      side: const BorderSide(color: Colors.red),
      padding: const EdgeInsets.symmetric(vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    onPressed: () {
      final donorId = d['donor']?['id']?.toString() ??
                      d['donor']?['_id']?.toString() ?? '';
      final donorName = d['donor']?['name'] ?? 'Donor';
      if (donorId.isNotEmpty) {
        Navigator.pop(context);
        showReportUserSheet(context, userId: donorId, userName: donorName);
      }
    },
    icon: const Icon(Icons.flag_outlined, color: Colors.red, size: 16),
    label: const Text('Report Donor',
        style: TextStyle(color: Colors.red, fontSize: 13)),
  ),
),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
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

  // ── Confirm modal ──────────────────────────────────────────────────────────
  void _showConfirmModal(Map<String, dynamic> d) {
    final photo = d['photoUrl'] as String?;
    final title = d['title'] ?? 'Donation';
    final category = d['category'] ?? '';
    final donor = d['donor']?['name'] ?? '';
    final address = d['pickupAddress'] ?? '';
    final pickupType = d['pickupType'] ?? '';
    final status = d['status'] ?? 'available';
    final distance =
        d['distance'] != null ? '${d['distance']}m Away' : '';
    final totalQty = d['quantity']?.toString() ?? '';
    final remaining =
        d['remainingQuantity'] ?? d['availableQuantity'];
    final remainingNum = remaining != null
        ? double.tryParse(remaining.toString())
        : (totalQty.isNotEmpty
            ? _parseQtyNum(totalQty)
            : null);

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
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(
                child: Text('Confirm Your Reservation',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: kTeal)),
              ),
              const SizedBox(height: 14),
              if (photo != null && photo.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    height: 160,
                    width: double.infinity,
                    child: Image.network(
                      photo.startsWith('http')
                          ? photo
                          : '$base$photo',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                          color: kSage,
                          child: const Icon(Icons.fastfood,
                              color: kWhite, size: 40)),
                    ),
                  ),
                ),
              const SizedBox(height: 14),
              _detailRow('Title :', title),
              _detailRow('Category :', category),
              _detailRow('Donor :', donor),
              if (distance.isNotEmpty)
                _detailRow('Location :', distance),
              _detailRow('Pickup Address:', address),
              if (pickupType.isNotEmpty)
                _detailRow('Pickup Type:', pickupType),
              _detailRow('Status:', status),

              // Quantity info block
              if (totalQty.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: kTeal.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      const Text('Quantity Info',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: kTeal)),
                      const SizedBox(height: 6),
                      Row(children: [
                        const Icon(
                            Icons.inventory_2_outlined,
                            size: 13,
                            color: kTeal),
                        const SizedBox(width: 6),
                        Text('Total: $totalQty',
                            style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black87)),
                      ]),
                      if (remaining != null) ...[
                        const SizedBox(height: 4),
                        Row(children: [
                          const Icon(
                              Icons.check_circle_outline,
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
                              fontSize: 10, color: kSage),
                        ),
                      ],
                    ],
                  ),
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
                            fontWeight: FontWeight.w600)),
                  ),
                  Row(children: [
                    if (canSplit) ...[
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kTeal,
                          elevation: 0,
                          padding:
                              const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(
                                      20)),
                        ),
                        onPressed: () async {
                          Navigator.pop(dialogCtx);
                          final qty =
                              await showQuantityPickerSheet(
                            context,
                            totalQuantity: totalQty,
                            remainingQty: remainingNum,
                          );
                          if (qty != null && mounted) {
                            await _doReserve(d,
                                quantity: qty);
                          }
                        },
                        child: const Text('Pick Amount',
                            style: TextStyle(
                                color: kWhite,
                                fontWeight: FontWeight.bold,
                                fontSize: 12)),
                      ),
                      const SizedBox(width: 8),
                    ],
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kTerra,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(20)),
                      ),
                      onPressed: () async {
                        Navigator.pop(dialogCtx);
                        await _doReserve(d);
                      },
                      icon: const Icon(
                          Icons.shopping_basket_outlined,
                          color: kWhite,
                          size: 18),
                      label: Text(
                        canSplit ? 'Reserve All' : 'Confirm',
                        style: const TextStyle(
                            color: kWhite,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ]),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Reserve ────────────────────────────────────────────────────────────────
  Future<void> _doReserve(Map<String, dynamic> d,
      {double? quantity}) async {
    final donationId =
        d['id']?.toString() ?? d['_id']?.toString() ?? '';
    if (donationId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not identify donation'),
          backgroundColor: Colors.red));
      return;
    }

    final double reservedQty = quantity ?? 1.0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
          child: CircularProgressIndicator(color: kTeal)),
    );

    try {
      await ReservationService()
          .createReservation(donationId, quantity: reservedQty);
      if (!mounted) return;
      Navigator.pop(context);

      setState(() {
        // Increment the "you reserved" counter
        _reservedCounts[donationId] =
            (_reservedCounts[donationId] ?? 0.0) + reservedQty;

        // Decrease remainingQuantity locally so the badge updates immediately
        void updateList(List<Map<String, dynamic>> list) {
          final idx = list.indexWhere((item) =>
              (item['id']?.toString() ??
                  item['_id']?.toString()) ==
              donationId);
          if (idx == -1) return;
          final current = double.tryParse(
                  list[idx]['remainingQuantity']?.toString() ??
                      list[idx]['quantity']?.toString() ??
                      '0') ??
              0.0;
          final newRemaining =
              (current - reservedQty).clamp(0.0, current);
          list[idx] =
              Map<String, dynamic>.from(list[idx])
                ..['remainingQuantity'] = newRemaining;
          // Only remove the card when nothing is left
          if (newRemaining <= 0) list.removeAt(idx);
        }

        updateList(_all);
        updateList(_filtered);
      });

      final msg = quantity != null
          ? 'Reserved ${reservedQty % 1 == 0 ? reservedQty.toInt() : reservedQty.toStringAsFixed(1)} units! Waiting for donor to accept.'
          : 'Reservation sent! Waiting for donor to accept (within 2h).';

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(msg),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4)));
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red));
    }
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSand,
      appBar: AppBar(
        backgroundColor: kTeal,
        foregroundColor: kWhite,
        title: const Text('All Donations',
            style:
                TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Container(
                  height: 42,
                  decoration: BoxDecoration(
                      color: kWhite,
                      borderRadius:
                          BorderRadius.circular(30)),
                  child: Row(children: [
                    const SizedBox(width: 14),
                    const Icon(Icons.search,
                        color: kSage, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        decoration: const InputDecoration(
                          hintText:
                              'Search by title, category…',
                          hintStyle: TextStyle(
                              color: kSage, fontSize: 13),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding:
                              EdgeInsets.symmetric(
                                  vertical: 10),
                        ),
                      ),
                    ),
                    if (_searchCtrl.text.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          _searchCtrl.clear();
                          _applyLocalSearch();
                        },
                        child: const Padding(
                          padding:
                              EdgeInsets.only(right: 12),
                          child: Icon(Icons.close,
                              color: kSage, size: 18),
                        ),
                      ),
                  ]),
                ),
              ),
              _buildFilterChips(),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child:
                  CircularProgressIndicator(color: kTeal))
          : _error != null
              ? Center(
                  child: Column(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.wifi_off,
                            color: kSage, size: 36),
                        const SizedBox(height: 8),
                        Text(_error!,
                            style: const TextStyle(
                                color: kSage)),
                        TextButton(
                            onPressed: _fetch,
                            child: const Text('Retry',
                                style: TextStyle(
                                    color: kTeal))),
                      ]))
              : _filtered.isEmpty
                  ? Center(
                      child: Column(
                          mainAxisAlignment:
                              MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.search_off,
                                color: kSage, size: 40),
                            const SizedBox(height: 12),
                            Text(
                              _searchCtrl.text.isNotEmpty
                                  ? 'No results for "${_searchCtrl.text}"'
                                  : 'No donations match this filter',
                              style: const TextStyle(
                                  color: kSage,
                                  fontSize: 14),
                            ),
                          ]))
                  : RefreshIndicator(
                      color: kTeal,
                      onRefresh: _fetch,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filtered.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 12),
                        itemBuilder: (_, i) =>
                            _buildCard(_filtered[i]),
                      ),
                    ),
      bottomNavigationBar:
          const SharedBottomNav(currentIndex: 0),
    );
  }

  // ── Donation card ──────────────────────────────────────────────────────────
  Widget _buildCard(Map<String, dynamic> d) {
    final photo = d['photoUrl'] as String?;
    final title = d['title'] ?? 'Donation';
    final category = d['category'] ?? '';
    final status = d['status'] ?? 'available';
    final urgent = d['isUrgent'] == true;
    final address = d['pickupAddress'] ?? '';
    final donor = d['donor']?['name'] ?? '';
    final statusColor =
        status == 'available' ? Colors.green : kTerra;
    final color = _markerColor(d);

    return GestureDetector(
      onTap: () => _showDetailsModal(d),
      child: Container(
        decoration: BoxDecoration(
          color: kWhite,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                bottomLeft: Radius.circular(16),
              ),
              child: Stack(
                children: [
                  SizedBox(
                    width: 100,
                    height: 110,
                    child: photo != null && photo.isNotEmpty
                        ? Image.network(
                            photo.startsWith('http')
                                ? photo
                                : '$base$photo',
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                Container(
                                    color: kSage,
                                    child: const Icon(
                                        Icons.fastfood,
                                        color: kWhite,
                                        size: 28)),
                          )
                        : Container(
                            color: kSage,
                            child: const Icon(Icons.fastfood,
                                color: kWhite, size: 28)),
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
                            color: Colors.white, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                              color: color.withOpacity(0.4),
                              blurRadius: 4,
                              spreadRadius: 1),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                          child: Text(title,
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87))),
                      if (urgent)
                        Container(
                          padding:
                              const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2),
                          decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius:
                                  BorderRadius.circular(6)),
                          child: const Text('URGENT',
                              style: TextStyle(
                                  fontSize: 9,
                                  color: kWhite,
                                  fontWeight:
                                      FontWeight.bold)),
                        ),
                    ]),
                    const SizedBox(height: 3),
                    Text(category,
                        style: const TextStyle(
                            fontSize: 11, color: kSage)),
                    const SizedBox(height: 3),
                    Row(children: [
                      const Icon(
                          Icons.location_on_outlined,
                          size: 11,
                          color: kSage),
                      const SizedBox(width: 3),
                      Expanded(
                          child: Text(address,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: kSage))),
                    ]),
                    const SizedBox(height: 3),
                    if (donor.isNotEmpty)
                      Row(children: [
                        const Icon(Icons.person_outline,
                            size: 11, color: kSage),
                        const SizedBox(width: 3),
                        Text(donor,
                            style: const TextStyle(
                                fontSize: 11,
                                color: kSage)),
                      ]),
                    const SizedBox(height: 4),
                    _buildQuantityBadge(d),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        Row(children: [
                          Icon(Icons.circle,
                              size: 7, color: statusColor),
                          const SizedBox(width: 4),
                          Text(status,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: statusColor)),
                        ]),
                        GestureDetector(
                          onTap: () =>
                              _showConfirmModal(d),
                          child: Container(
                            padding:
                                const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 6),
                            decoration: BoxDecoration(
                                color: kTerra,
                                borderRadius:
                                    BorderRadius.circular(
                                        20)),
                            child: const Text('Reserve',
                                style: TextStyle(
                                    color: kWhite,
                                    fontSize: 11,
                                    fontWeight:
                                        FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}