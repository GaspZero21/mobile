import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../services/donation_service.dart';
import '../services/reservation_service.dart';
import '../widgets/shared_bottom_nav.dart';

class AllDonationsScreen extends StatefulWidget {
  const AllDonationsScreen({super.key});

  @override
  State<AllDonationsScreen> createState() => _AllDonationsScreenState();
}

class _AllDonationsScreenState extends State<AllDonationsScreen> {
  static const String base = 'https://gasp-test-production.up.railway.app/';

  List<Map<String, dynamic>> _all = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _isLoading = true;
  String? _error;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetch();
    _searchCtrl.addListener(_onSearch);
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
      final data = await DonationService().getDonations();
      if (!mounted) return;
      setState(() {
        _all = data;
        _filtered = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _onSearch() {
    final q = _searchCtrl.text.toLowerCase().trim();
    setState(() {
      _filtered = q.isEmpty
          ? _all
          : _all.where((d) {
              final title = (d['title'] ?? '').toLowerCase();
              final category = (d['category'] ?? '').toLowerCase();
              final address = (d['pickupAddress'] ?? '').toLowerCase();
              return title.contains(q) ||
                  category.contains(q) ||
                  address.contains(q);
            }).toList();
    });
  }

  // ── Step 1: Details modal ─────────────────────────────────────────────────
  void _showDetailsModal(Map<String, dynamic> d) {
    final photo = d['photoUrl'] as String?;
    final title = d['title'] ?? 'Donation';
    final category = d['category'] ?? '';
    final donor = d['donor']?['name'] ?? '';
    final address = d['pickupAddress'] ?? '';
    final pickupType = d['pickupType'] ?? '';
    final status = d['status'] ?? 'available';
    final distance = d['distance'] != null ? '${d['distance']}m Away' : '';

    showDialog(
      context: context,
      barrierColor: Colors.black38,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Photo with close button
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                  child: SizedBox(
                    height: 200,
                    width: double.infinity,
                    child: photo != null && photo.isNotEmpty
                        ? Image.network(
                            photo.startsWith('http') ? photo : '$base$photo',
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              color: kSage,
                              child: const Icon(Icons.fastfood,
                                  color: kWhite, size: 48),
                            ),
                          )
                        : Container(
                            color: kSage,
                            child: const Icon(Icons.fastfood,
                                color: kWhite, size: 48),
                          ),
                  ),
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
                        color: kWhite.withValues(alpha: 0.9),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, size: 18, color: kSage),
                    ),
                  ),
                ),
              ],
            ),

            // Details
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _detailRow('Title :', title),
                  _detailRow('Category :', category),
                  _detailRow('Donor :', donor),
                  if (distance.isNotEmpty) _detailRow('Location :', distance),
                  _detailRow('Pickup Address:', address),
                  if (pickupType.isNotEmpty)
                    _detailRow('Pickup Type:', pickupType),
                  _detailRow('Statut:', status),
                  const SizedBox(height: 16),

                  // Reserve button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kTerra,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        _showConfirmModal(d);
                      },
                      child: const Text(
                        'Reserve',
                        style: TextStyle(
                          color: kWhite,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, color: kSage),
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 2: Confirm reservation modal ────────────────────────────────────
  void _showConfirmModal(Map<String, dynamic> d) {
    final photo = d['photoUrl'] as String?;
    final title = d['title'] ?? 'Donation';
    final category = d['category'] ?? '';
    final donor = d['donor']?['name'] ?? '';
    final address = d['pickupAddress'] ?? '';
    final pickupType = d['pickupType'] ?? '';
    final status = d['status'] ?? 'available';
    final distance = d['distance'] != null ? '${d['distance']}m Away' : '';

    showDialog(
      context: context,
      barrierColor: Colors.black38,
      builder: (dialogCtx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              const Center(
                child: Text(
                  'Confirm Your Reservation',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: kTeal,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Photo
              if (photo != null && photo.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    height: 160,
                    width: double.infinity,
                    child: Image.network(
                      photo.startsWith('http') ? photo : '$base$photo',
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        color: kSage,
                        child: const Icon(Icons.fastfood,
                            color: kWhite, size: 40),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 14),

              // Details
              _detailRow('Title :', title),
              _detailRow('Category :', category),
              _detailRow('Donor :', donor),
              if (distance.isNotEmpty) _detailRow('Location :', distance),
              _detailRow('Pickup Address:', address),
              if (pickupType.isNotEmpty)
                _detailRow('Pickup Type:', pickupType),
              _detailRow('Statut:', status),
              const SizedBox(height: 20),

              // Cancel / Confirm buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogCtx),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        color: kTerra,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kTerra,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    onPressed: () async {
                      Navigator.pop(dialogCtx);
                      await _doReserve(d);
                    },
                    icon: const Icon(Icons.shopping_basket_outlined,
                        color: kWhite, size: 18),
                    label: const Text(
                      'Confirm',
                      style: TextStyle(
                        color: kWhite,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Step 3: Call API ──────────────────────────────────────────────────────
  Future<void> _doReserve(Map<String, dynamic> d) async {
    final donationId = d['id']?.toString() ?? d['_id']?.toString() ?? '';
    if (donationId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not identify donation'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          const Center(child: CircularProgressIndicator(color: kTeal)),
    );

    try {
      await ReservationService().createReservation(donationId);
      if (!mounted) return;
      Navigator.pop(context); // close loading

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Reservation sent! Waiting for donor to accept (within 2h).',
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 4),
        ),
      );

      setState(() {
        _all.removeWhere((item) =>
            (item['id']?.toString() ?? item['_id']?.toString()) == donationId);
        _filtered.removeWhere((item) =>
            (item['id']?.toString() ?? item['_id']?.toString()) == donationId);
      });
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // close loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSand,
      appBar: AppBar(
        backgroundColor: kTeal,
        foregroundColor: kWhite,
        title: const Text(
          'All Donations',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: kWhite,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 14),
                  const Icon(Icons.search, color: kSage, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Search by title, category…',
                        hintStyle: TextStyle(color: kSage, fontSize: 13),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kTeal))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.wifi_off, color: kSage, size: 36),
                      const SizedBox(height: 8),
                      Text(_error!, style: const TextStyle(color: kSage)),
                      TextButton(
                        onPressed: _fetch,
                        child: const Text('Retry',
                            style: TextStyle(color: kTeal)),
                      ),
                    ],
                  ),
                )
              : _filtered.isEmpty
                  ? const Center(
                      child: Text(
                        'No donations found',
                        style: TextStyle(color: kSage, fontSize: 14),
                      ),
                    )
                  : RefreshIndicator(
                      color: kTeal,
                      onRefresh: _fetch,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filtered.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: 12),
                        itemBuilder: (_, i) => _buildCard(_filtered[i]),
                      ),
                    ),
      bottomNavigationBar: const SharedBottomNav(currentIndex: 0),
    );
  }

  Widget _buildCard(Map<String, dynamic> d) {
    final photo = d['photoUrl'] as String?;
    final title = d['title'] ?? 'Donation';
    final category = d['category'] ?? '';
    final status = d['status'] ?? 'available';
    final urgent = d['isUrgent'] == true;
    final address = d['pickupAddress'] ?? '';
    final donor = d['donor']?['name'] ?? '';
    final statusColor = status == 'available' ? Colors.green : kTerra;

    return GestureDetector(
      onTap: () => _showDetailsModal(d),
      child: Container(
        decoration: BoxDecoration(
          color: kWhite,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            // Photo
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                bottomLeft: Radius.circular(16),
              ),
              child: SizedBox(
                width: 100,
                height: 110,
                child: photo != null && photo.isNotEmpty
                    ? Image.network(
                        photo.startsWith('http') ? photo : '$base$photo',
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          color: kSage,
                          child: const Icon(Icons.fastfood,
                              color: kWhite, size: 28),
                        ),
                      )
                    : Container(
                        color: kSage,
                        child: const Icon(Icons.fastfood,
                            color: kWhite, size: 28),
                      ),
              ),
            ),

            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        if (urgent)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: kTerra,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'URGENT',
                              style: TextStyle(
                                  fontSize: 9,
                                  color: kWhite,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(category,
                        style: const TextStyle(fontSize: 11, color: kSage)),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined,
                            size: 11, color: kSage),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            address,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                const TextStyle(fontSize: 11, color: kSage),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    if (donor.isNotEmpty)
                      Row(
                        children: [
                          const Icon(Icons.person_outline,
                              size: 11, color: kSage),
                          const SizedBox(width: 3),
                          Text(donor,
                              style: const TextStyle(
                                  fontSize: 11, color: kSage)),
                        ],
                      ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.circle, size: 7, color: statusColor),
                            const SizedBox(width: 4),
                            Text(status,
                                style: TextStyle(
                                    fontSize: 11, color: statusColor)),
                          ],
                        ),
                        GestureDetector(
                          onTap: () => _showConfirmModal(d),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: kTerra,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'Reserve',
                              style: TextStyle(
                                color: kWhite,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
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