import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../services/reservation_service.dart';
import '../widgets/shared_bottom_nav.dart';
import 'chat_screen.dart';

// ── Extracted dialog widget to avoid controller-disposed-after-use bug ────────
class _EditQuantityDialog extends StatefulWidget {
  final Map<String, dynamic> reservation;
  final Future<void> Function(Map<String, dynamic>, double) onUpdate;

  const _EditQuantityDialog({
    required this.reservation,
    required this.onUpdate,
  });

  @override
  State<_EditQuantityDialog> createState() => _EditQuantityDialogState();
}

class _EditQuantityDialogState extends State<_EditQuantityDialog> {
  late final TextEditingController _controller;
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final rawQty = widget.reservation['requestedQuantity'];
    final currentQty = rawQty is num
        ? rawQty.toDouble()
        : double.tryParse(rawQty?.toString() ?? '') ?? 1.0;
    _controller = TextEditingController(text: currentQty.toStringAsFixed(2));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Update Quantity',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close, color: kSage),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                widget.reservation['donation']?['title'] ?? 'Reservation',
                style: const TextStyle(fontSize: 13, color: kSage),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _controller,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Requested Quantity',
                  labelStyle: const TextStyle(color: kSage),
                  hintText: 'e.g. 2.5',
                  prefixIcon: const Icon(Icons.edit_outlined, color: kSage),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: kSage),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: kTeal, width: 2),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF7F7F5),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a quantity';
                  }
                  final parsed = double.tryParse(value.trim());
                  if (parsed == null || parsed <= 0) {
                    return 'Enter a valid positive number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _loading ? null : () => Navigator.pop(context),
                    child: const Text(
                      'Discard',
                      style: TextStyle(color: kSage),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kTeal,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      elevation: 0,
                    ),
                    onPressed: _loading
                        ? null
                        : () async {
                            if (!_formKey.currentState!.validate()) return;
                            final newQty =
                                double.parse(_controller.text.trim());
                            setState(() => _loading = true);
                            Navigator.pop(context);
                            await widget.onUpdate(widget.reservation, newQty);
                          },
                    child: _loading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              color: kWhite,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Update',
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
}

// ── Main screen ───────────────────────────────────────────────────────────────
class MyReservationsScreen extends StatefulWidget {
  const MyReservationsScreen({super.key});

  @override
  State<MyReservationsScreen> createState() => _MyReservationsScreenState();
}

class _MyReservationsScreenState extends State<MyReservationsScreen> {
  static const String _base = 'https://gasp-test-production.up.railway.app/';

  List<Map<String, dynamic>> _reservations = [];
  bool _isLoading = true;
  String? _error;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _activeStatus = 'All';

  List<Map<String, dynamic>> get _filteredReservations {
    if (_searchQuery.isEmpty && _activeStatus == 'All') return _reservations;

    final q = _searchQuery.toLowerCase();
    return _reservations.where((r) {
      final title =
          (r['donation']?['title'] ?? '').toString().toLowerCase();
      final status = (r['status'] ?? '').toString().toLowerCase();
      final donorName =
          (r['donation']?['donor']?['name'] ?? '').toString().toLowerCase();

      final matchesSearch = q.isEmpty ||
          title.contains(q) ||
          status.contains(q) ||
          donorName.contains(q);
      final matchesStatus =
          _activeStatus == 'All' || status == _activeStatus.toLowerCase();

      return matchesSearch && matchesStatus;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await ReservationService().getMyReservations();
      if (!mounted) return;
      setState(() {
        _reservations = data;
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

  // ── Cancel dialog ─────────────────────────────────────────────────────────
  void _showCancelDialog(Map<String, dynamic> reservation) {
    showDialog(
      context: context,
      barrierColor: Colors.black38,
      builder: (_) => Dialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.topLeft,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close, color: kSage),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Are You Sure ?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.red, width: 3),
                ),
                child: const Icon(Icons.close, color: Colors.red, size: 40),
              ),
              const SizedBox(height: 16),
              const Text(
                'Do You Want Cancel This\nReservation ?',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.black54),
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kTerra,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 28, vertical: 12),
                    elevation: 0,
                  ),
                  onPressed: () async {
                    Navigator.pop(context);
                    await _doCancel(reservation);
                  },
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                        color: kWhite, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _doCancel(Map<String, dynamic> reservation) async {
    final id = reservation['id']?.toString() ?? '';
    if (id.isEmpty) return;
    try {
      await ReservationService().cancelReservation(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reservation cancelled'),
          backgroundColor: kTerra,
        ),
      );
      _fetch();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ── Edit Quantity dialog — uses extracted StatefulWidget ──────────────────
  void _showEditQuantityDialog(Map<String, dynamic> reservation) {
    showDialog(
      context: context,
      barrierColor: Colors.black38,
      builder: (_) => _EditQuantityDialog(
        reservation: reservation,
        onUpdate: _doUpdateQuantity,
      ),
    );
  }

  Future<void> _doUpdateQuantity(
    Map<String, dynamic> reservation,
    double newQty,
  ) async {
    final id = reservation['id']?.toString() ?? '';
    if (id.isEmpty) return;
    try {
      // Ensure BENEFICIARY role + fresh token before the PATCH (fixes 403)
      await ReservationService().ensureBeneficiaryRole();
      await ReservationService().updateReservationQuantity(id, newQty);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Quantity updated successfully'),
          backgroundColor: kTeal,
        ),
      );
      _fetch();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ── Status badge ──────────────────────────────────────────────────────────
  Widget _statusBadge(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'confirmed':
        color = Colors.green;
        break;
      case 'cancelled':
      case 'canceled':
        color = Colors.red;
        break;
      default:
        color = Colors.orange;
    }
    return Row(
      children: [
        Icon(Icons.circle, size: 7, color: color),
        const SizedBox(width: 4),
        Text(status, style: TextStyle(fontSize: 11, color: color)),
      ],
    );
  }

  // ── Reservation card ──────────────────────────────────────────────────────
  Widget _buildCard(Map<String, dynamic> r) {
    final donation = r['donation'] as Map<String, dynamic>? ?? r;
    final String? photo = donation['photoUrl'] as String?;
    final String title = donation['title'] ?? 'Donation';
    final String status = r['status'] ?? 'pending';
    final String distance =
        donation['distance'] != null ? '${donation['distance']}m' : '';
    final String timeAgo = _timeAgo(r['createdAt']?.toString());

    final bool isPending = status.toLowerCase() == 'pending';
    final bool canCancel =
        isPending || status.toLowerCase() == 'confirmed';
    final bool isConfirmed = status.toLowerCase() == 'confirmed';

    return Container(
      width: 140,
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
            child: SizedBox(
              height: 100,
              width: double.infinity,
              child: photo != null && photo.isNotEmpty
                  ? Image.network(
                      photo.startsWith('http') ? photo : '$_base$photo',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
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

          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '• $title',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 3),

                if (distance.isNotEmpty || timeAgo.isNotEmpty)
                  Text(
                    [
                      if (distance.isNotEmpty) distance,
                      if (timeAgo.isNotEmpty) timeAgo,
                    ].join(' | '),
                    style: const TextStyle(fontSize: 10, color: kSage),
                  ),
                const SizedBox(height: 4),

                _statusBadge(status),
                const SizedBox(height: 8),

                if (isPending)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: kTeal),
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      onPressed: () => _showEditQuantityDialog(r),
                      icon: const Icon(Icons.edit_outlined,
                          color: kTeal, size: 13),
                      label: const Text(
                        'Edit Qty',
                        style: TextStyle(
                          color: kTeal,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                if (isPending) const SizedBox(height: 6),

                if (canCancel)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kTerra,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      onPressed: () => _showCancelDialog(r),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: kWhite,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                if (isConfirmed) ...[
                  const SizedBox(height: 6),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kTeal,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      onPressed: () {
                        final donorName =
                            (r['donation']?['donor']?['name'] ??
                                    r['donor']?['name'] ??
                                    'Donor') as String;
                        final donTitle =
                            (r['donation']?['title'] ?? '') as String;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatScreen(
                              reservationId: r['id'] as String,
                              otherName: donorName,
                              donationTitle: donTitle,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.chat_bubble_outline,
                          color: kWhite, size: 14),
                      label: const Text(
                        'Chat',
                        style: TextStyle(
                          color: kWhite,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _timeAgo(String? isoDate) {
    if (isoDate == null) return '';
    final dt = DateTime.tryParse(isoDate);
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}min Ago';
    if (diff.inHours < 24) return '${diff.inHours}h Ago';
    return '${diff.inDays}d Ago';
  }

  // ── Status filter chips ───────────────────────────────────────────────────
  Widget _buildFilterChips() {
    const statuses = [
      'All',
      'pending',
      'confirmed',
      'cancelled',
      'completed'
    ];
    return SizedBox(
      height: 36,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: statuses.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final s = statuses[i];
          final isActive = _activeStatus == s;
          return GestureDetector(
            onTap: () => setState(() => _activeStatus = s),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isActive ? kTeal : kWhite,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isActive ? kTeal : const Color(0xFFDDDDDD),
                ),
              ),
              child: Text(
                s == 'All' ? 'All' : s[0].toUpperCase() + s.substring(1),
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isActive ? kWhite : kSage,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSand,
      appBar: AppBar(
        backgroundColor: kTeal,
        foregroundColor: kWhite,
        title: const Text(
          'My Reservations',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
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
                          controller: _searchController,
                          onChanged: (value) =>
                              setState(() => _searchQuery = value.trim()),
                          decoration: const InputDecoration(
                            hintText: 'Search For Food',
                            hintStyle:
                                TextStyle(color: kSage, fontSize: 13),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding:
                                EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                      if (_searchQuery.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                          child: const Padding(
                            padding: EdgeInsets.only(right: 12),
                            child:
                                Icon(Icons.close, color: kSage, size: 18),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 4),
              _buildFilterChips(),
              const SizedBox(height: 10),
            ],
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
                      Text(_error!,
                          style: const TextStyle(color: kSage)),
                      TextButton(
                        onPressed: _fetch,
                        child: const Text('Retry',
                            style: TextStyle(color: kTeal)),
                      ),
                    ],
                  ),
                )
              : _reservations.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.bookmark_border,
                              size: 64, color: kSage),
                          SizedBox(height: 12),
                          Text(
                            'No reservations yet',
                            style: TextStyle(
                              color: kSage,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Browse donations and reserve one!',
                            style: TextStyle(color: kSage, fontSize: 13),
                          ),
                        ],
                      ),
                    )
                  : _filteredReservations.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.search_off,
                                  size: 56, color: kSage),
                              const SizedBox(height: 12),
                              Text(
                                _searchQuery.isNotEmpty
                                    ? 'No results for "$_searchQuery"'
                                    : 'No $_activeStatus reservations',
                                style: const TextStyle(
                                  color: kSage,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Try a different search or filter',
                                style:
                                    TextStyle(color: kSage, fontSize: 12),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          color: kTeal,
                          onRefresh: _fetch,
                          child: Container(
                            margin: const EdgeInsets.only(top: 16),
                            decoration: const BoxDecoration(
                              color: kWhite,
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(24),
                                topRight: Radius.circular(24),
                              ),
                            ),
                            child: GridView.builder(
                              padding: const EdgeInsets.all(16),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: 0.62,
                              ),
                              itemCount: _filteredReservations.length,
                              itemBuilder: (_, i) =>
                                  _buildCard(_filteredReservations[i]),
                            ),
                          ),
                        ),
      bottomNavigationBar: const SharedBottomNav(currentIndex: 1),
    );
  }
}