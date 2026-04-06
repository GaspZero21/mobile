import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../services/reservation_service.dart';
import '../widgets/shared_bottom_nav.dart';
import 'chat_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _fetch();
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

  void _showCancelDialog(Map<String, dynamic> reservation) {
    showDialog(
      context: context,
      barrierColor: Colors.black38,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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
                      horizontal: 28,
                      vertical: 12,
                    ),
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
    final String? photo    = donation['photoUrl'] as String?;
    final String  title    = donation['title'] ?? 'Donation';
    final String  status   = r['status'] ?? 'pending';
    final String  distance = donation['distance'] != null
        ? '${donation['distance']}m'
        : '';
    final String timeAgo = _timeAgo(r['createdAt']?.toString());

    final bool canCancel = status.toLowerCase() == 'pending' ||
        status.toLowerCase() == 'confirmed';
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
          // Photo
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

          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
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

                // Distance + time
                if (distance.isNotEmpty || timeAgo.isNotEmpty)
                  Text(
                    [
                      if (distance.isNotEmpty) distance,
                      if (timeAgo.isNotEmpty) timeAgo,
                    ].join(' | '),
                    style: const TextStyle(fontSize: 10, color: kSage),
                  ),
                const SizedBox(height: 4),

                // Status badge
                _statusBadge(status),
                const SizedBox(height: 8),

                // Cancel button
                if (canCancel)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kTerra,
                        elevation: 0,
                        padding:
                            const EdgeInsets.symmetric(vertical: 7),
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

                // Chat button — only when confirmed
                if (isConfirmed) ...[
                  const SizedBox(height: 6),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kTeal,
                        elevation: 0,
                        padding:
                            const EdgeInsets.symmetric(vertical: 7),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      onPressed: () {
                        final donorName = (r['donation']?['donor']
                                    ?['name'] ??
                                r['donor']?['name'] ??
                                'Donor')
                            as String;
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
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: kWhite,
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Row(
                children: [
                  SizedBox(width: 14),
                  Icon(Icons.search, color: kSage, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
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
                ],
              ),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: kTeal))
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
                      child: Text(
                        'No reservations yet',
                        style: TextStyle(color: kSage, fontSize: 14),
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
                            childAspectRatio: 0.7,
                          ),
                          itemCount: _reservations.length,
                          itemBuilder: (_, i) =>
                              _buildCard(_reservations[i]),
                        ),
                      ),
                    ),
      bottomNavigationBar: const SharedBottomNav(currentIndex: 1),
    );
  }
}