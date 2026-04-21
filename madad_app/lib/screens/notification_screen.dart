import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../services/notification_service.dart';
import '../services/donation_service.dart';
import '../services/reservation_service.dart';
import '../widgets/shared_bottom_nav.dart';
import 'chat_screen.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  static const String _base = 'https://gasp-test-production.up.railway.app/';

  List<Map<String, dynamic>> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final res = await NotificationService().getNotifications();
      final data = res['data'] as Map<String, dynamic>;
      final list = data['notifications'] as List;
      setState(() {
        _notifications = List<Map<String, dynamic>>.from(list);
        _unreadCount   = (data['unreadCount'] as num?)?.toInt() ?? 0;
        _isLoading     = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  Future<void> _markAllRead() async {
    await NotificationService().markAllRead();
    setState(() {
      for (final n in _notifications) n['isRead'] = true;
      _unreadCount = 0;
    });
  }

  Future<void> _markRead(Map<String, dynamic> notif) async {
    if (notif['isRead'] == true) return;
    await NotificationService().markRead(notif['id'] as String);
    setState(() {
      notif['isRead'] = true;
      if (_unreadCount > 0) _unreadCount--;
    });
  }

  // ── Main tap router ───────────────────────────────────────────────────────
  Future<void> _onTap(Map<String, dynamic> notif) async {
    await _markRead(notif);
    if (!mounted) return;

    final String type = notif['type']?.toString() ?? '';

    final String? donationId =
        notif['donationId']?.toString() ??
        notif['data']?['donationId']?.toString() ??
        notif['metadata']?['donationId']?.toString();

    final String? reservationId =
        notif['reservationId']?.toString() ??
        notif['data']?['reservationId']?.toString() ??
        notif['metadata']?['reservationId']?.toString();

    final String? chatId =
        notif['chatId']?.toString() ??
        notif['conversationId']?.toString() ??
        notif['data']?['chatId']?.toString() ??
        notif['data']?['conversationId']?.toString();

    final String senderName =
        notif['data']?['senderName']?.toString() ??
        notif['senderName']?.toString() ??
        'Chat';

    switch (type) {
      // ── Someone reserved MY donation ─────────────────────────────────────
      case 'RESERVATION_REQUESTED':
        if (reservationId != null && reservationId.isNotEmpty) {
          await _navigateToReservation(reservationId, type, showActions: true);
        } else if (donationId != null && donationId.isNotEmpty) {
          await _navigateToDonation(donationId, notif);
        }
        break;

      // ── Donor accepted / cancelled my reservation ─────────────────────────
      case 'RESERVATION_ACCEPTED':
      case 'RESERVATION_CANCELLED':
      case 'RESERVATION_CANCELED':
        if (reservationId != null && reservationId.isNotEmpty) {
          await _navigateToReservation(reservationId, type, showActions: false);
        } else if (donationId != null && donationId.isNotEmpty) {
          await _navigateToDonation(donationId, notif);
        }
        break;

      // ── New donation nearby ───────────────────────────────────────────────
      case 'DONATION_POSTED':
        if (donationId != null && donationId.isNotEmpty) {
          await _navigateToDonation(donationId, notif);
        }
        break;

      // ── Donation completed ────────────────────────────────────────────────
      case 'DONATION_COMPLETED':
        if (donationId != null && donationId.isNotEmpty) {
          await _navigateToDonation(donationId, notif);
        } else if (reservationId != null && reservationId.isNotEmpty) {
          await _navigateToReservation(reservationId, type,
              showActions: false);
        }
        break;

      // ── New chat message ──────────────────────────────────────────────────
      case 'NEW_MESSAGE':
        if (reservationId != null && reservationId.isNotEmpty) {
          _openChat(
            reservationId: reservationId,
            otherName: senderName,
            donationTitle: notif['data']?['donationTitle']?.toString() ??
                notif['donationTitle']?.toString() ??
                '',
          );
        } else {
          _snack('Could not open chat — no reservation linked.');
        }
        break;

      default:
        if (donationId != null && donationId.isNotEmpty) {
          await _navigateToDonation(donationId, notif);
        } else if (reservationId != null && reservationId.isNotEmpty) {
          await _navigateToReservation(reservationId, type,
              showActions: false);
        }
    }
  }

  // ── Load donation → show modal ────────────────────────────────────────────
  Future<void> _navigateToDonation(
      String donationId, Map<String, dynamic> notif) async {
    _showLoader();
    try {
      final donation = await DonationService().getDonationById(donationId);
      if (!mounted) return;
      Navigator.pop(context);
      _showDonationModal(donation, notif);
    } catch (_) {
      if (!mounted) return;
      Navigator.pop(context);
      _snack('Could not load donation details', isError: true);
    }
  }

  // ── Load reservation → show reservation card modal ────────────────────────
  Future<void> _navigateToReservation(
    String reservationId,
    String type, {
    required bool showActions,
  }) async {
    _showLoader();
    try {
      final reservation =
          await ReservationService().getReservationById(reservationId);
      if (!mounted) return;
      Navigator.pop(context);
      _showReservationModal(reservation, type, showActions: showActions);
    } catch (_) {
      if (!mounted) return;
      Navigator.pop(context);
      _snack('Could not load reservation details', isError: true);
    }
  }

  // ── Open ChatScreen (matches MyReservationsScreen's call exactly) ─────────
  void _openChat({
    required String reservationId,
    required String otherName,
    required String donationTitle,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          reservationId: reservationId,
          otherName: otherName,
          donationTitle: donationTitle,
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // RESERVATION MODAL — styled exactly like MyReservationsScreen cards
  // with Confirm / Cancel actions when showActions == true
  // ─────────────────────────────────────────────────────────────────────────
  void _showReservationModal(
    Map<String, dynamic> r,
    String type, {
    required bool showActions,
  }) {
    final donation   = r['donation'] as Map<String, dynamic>? ?? r;
    final String? photo  = donation['photoUrl'] as String?;
    final String  title  = donation['title'] ?? r['title'] ?? 'Donation';
    final String  status = r['status'] ?? 'pending';
    final String  address =
        donation['pickupAddress'] ?? r['pickupAddress'] ?? '';
    final String  category  = donation['category'] ?? '';
    final String  pickupType = donation['pickupType'] ?? '';
    final String  quantity  = donation['quantity']?.toString() ?? '';
    final bool    urgent    = donation['isUrgent'] == true;
    final String  donorName =
        donation['donor']?['name'] ?? r['donor']?['name'] ?? 'Donor';
    final String  donTitle  = title;
    final String  reservationId =
        r['id']?.toString() ?? r['_id']?.toString() ?? '';
    final String  createdAt = r['createdAt'] ?? '';

    Color statusColor;
    String statusLabel;
    switch (status.toLowerCase()) {
      case 'confirmed':
      case 'accepted':
        statusColor = Colors.green;
        statusLabel = '✓ Confirmed';
        break;
      case 'cancelled':
      case 'canceled':
        statusColor = Colors.red;
        statusLabel = '✗ Cancelled';
        break;
      case 'completed':
        statusColor = kTeal;
        statusLabel = '✓ Completed';
        break;
      default:
        statusColor = Colors.orange;
        statusLabel = '⏳ Pending';
    }

    final bool canConfirm = showActions &&
        status.toLowerCase() == 'pending' &&
        type == 'RESERVATION_REQUESTED';
    final bool canCancel  = showActions &&
        (status.toLowerCase() == 'pending' ||
         status.toLowerCase() == 'confirmed' ||
         status.toLowerCase() == 'accepted');
    final bool canChat    = status.toLowerCase() == 'confirmed' ||
        status.toLowerCase() == 'accepted';

    showDialog(
      context: context,
      barrierColor: Colors.black38,
      builder: (_) => Dialog(
        insetPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [

              // ── Photo + close ───────────────────────────────────────────
              Stack(
                children: [
                  SizedBox(
                    height: 180,
                    width: double.infinity,
                    child: photo != null && photo.isNotEmpty
                        ? Image.network(
                            photo.startsWith('http') ? photo : '$_base$photo',
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _placeholder(),
                          )
                        : _placeholder(),
                  ),
                  Positioned(
                    top: 10, left: 10,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                          color: kWhite.withValues(alpha: 0.9),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, size: 18, color: kSage),
                      ),
                    ),
                  ),
                  // Status badge on photo
                  Positioned(
                    bottom: 10, right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(statusLabel,
                          style: const TextStyle(
                              color: kWhite,
                              fontSize: 11,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                  if (urgent)
                    Positioned(
                      top: 10, right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('⚡ URGENT',
                            style: TextStyle(
                                color: kWhite,
                                fontSize: 10,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                ],
              ),

              // ── Details ─────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: kTeal)),
                    if (category.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: kTeal.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(category,
                            style: const TextStyle(
                                fontSize: 11,
                                color: kTeal,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                    const SizedBox(height: 14),
                    const Divider(height: 1, color: Color(0xFFEEEEEE)),
                    const SizedBox(height: 14),

                    _infoRow(Icons.person_outline, 'Donor', donorName),
                    if (address.isNotEmpty)
                      _infoRow(Icons.location_on_outlined,
                          'Pickup Address', address),
                    if (pickupType.isNotEmpty)
                      _infoRow(Icons.directions_outlined,
                          'Pickup Type', pickupType),
                    if (quantity.isNotEmpty)
                      _infoRow(Icons.scale_outlined, 'Quantity', quantity),
                    if (createdAt.isNotEmpty)
                      _infoRow(Icons.schedule_outlined, 'Reserved on',
                          _formatDate(createdAt)),

                    const SizedBox(height: 20),

                    // ── Action buttons ────────────────────────────────────

                    // CONFIRM (donor only — RESERVATION_REQUESTED)
                    if (canConfirm)
                      _actionButton(
                        label: 'Confirm Reservation',
                        icon: Icons.check_circle_outline,
                        color: Colors.green,
                        onTap: () async {
                          Navigator.pop(context);
                          await _doConfirm(reservationId);
                        },
                      ),

                    if (canConfirm) const SizedBox(height: 10),

                    // CHAT
                    if (canChat) ...[
                      _actionButton(
                        label: 'Open Chat',
                        icon: Icons.chat_bubble_outline,
                        color: kTeal,
                        onTap: () {
                          Navigator.pop(context);
                          _openChat(
                            reservationId: reservationId,
                            otherName: donorName,
                            donationTitle: donTitle,
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                    ],

                    // CANCEL
                    if (canCancel)
                      _actionButton(
                        label: 'Cancel Reservation',
                        icon: Icons.cancel_outlined,
                        color: kTerra,
                        onTap: () {
                          Navigator.pop(context);
                          _showCancelConfirm(r);
                        },
                      ),

                    // CLOSE (when no actions available)
                    if (!canConfirm && !canCancel)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: kTeal),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20)),
                            padding:
                                const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Close',
                              style: TextStyle(
                                  color: kTeal,
                                  fontWeight: FontWeight.bold)),
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

  // ── Confirm a reservation (donor accepts beneficiary's request) ───────────
  Future<void> _doConfirm(String reservationId) async {
    if (reservationId.isEmpty) return;
    _showLoader();
    try {
      await ReservationService().confirmReservation(reservationId);
      if (!mounted) return;
      Navigator.pop(context);
      _snack('Reservation confirmed!');
      _fetch(); // refresh notification list
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      _snack('Error: $e', isError: true);
    }
  }

  // ── Cancel dialog (same style as MyReservationsScreen) ───────────────────
  void _showCancelConfirm(Map<String, dynamic> r) {
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
              const Text('Are You Sure ?',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87)),
              const SizedBox(height: 16),
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.red, width: 3),
                ),
                child:
                    const Icon(Icons.close, color: Colors.red, size: 40),
              ),
              const SizedBox(height: 16),
              const Text(
                'Do You Want to Cancel This\nReservation?',
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
                        borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 28, vertical: 12),
                    elevation: 0,
                  ),
                  onPressed: () async {
                    Navigator.pop(context);
                    await _doCancel(r);
                  },
                  child: const Text('Cancel Reservation',
                      style: TextStyle(
                          color: kWhite, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _doCancel(Map<String, dynamic> r) async {
    final id = r['id']?.toString() ?? r['_id']?.toString() ?? '';
    if (id.isEmpty) return;
    _showLoader();
    try {
      await ReservationService().cancelReservation(id);
      if (!mounted) return;
      Navigator.pop(context);
      _snack('Reservation cancelled.');
      _fetch();
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      _snack('Error: $e', isError: true);
    }
  }

  // ── Donation detail modal (for DONATION_POSTED / DONATION_COMPLETED) ──────
  void _showDonationModal(
      Map<String, dynamic> d, Map<String, dynamic> notif) {
    final photo       = d['photoUrl'] as String?;
    final title       = d['title'] ?? 'Donation';
    final category    = d['category'] ?? '';
    final donor       = d['donor']?['name'] ?? '';
    final address     = d['pickupAddress'] ?? '';
    final pickupType  = d['pickupType'] ?? '';
    final status      = d['status'] ?? 'available';
    final distance    =
        d['distance'] != null ? '${d['distance']} m away' : '';
    final description = d['description'] ?? '';
    final expiresAt   = d['expiresAt'] ?? d['expiredAt'] ?? '';
    final quantity    = d['quantity']?.toString() ?? '';
    final urgent      = d['isUrgent'] == true;
    final type        = notif['type']?.toString() ?? '';

    final bool canReserve = status == 'available' &&
        !['RESERVATION_REQUESTED', 'RESERVATION_ACCEPTED'].contains(type);

    showDialog(
      context: context,
      barrierColor: Colors.black38,
      builder: (_) => Dialog(
        insetPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 50),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                children: [
                  SizedBox(
                    height: 200, width: double.infinity,
                    child: photo != null && photo.isNotEmpty
                        ? Image.network(
                            photo.startsWith('http') ? photo : '$_base$photo',
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _placeholder(),
                          )
                        : _placeholder(),
                  ),
                  Positioned(
                    top: 10, left: 10,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                          color: kWhite.withValues(alpha: 0.9),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close,
                            size: 18, color: kSage),
                      ),
                    ),
                  ),
                  if (urgent)
                    Positioned(
                      bottom: 0, left: 0, right: 0,
                      child: Container(
                        color: Colors.red.withValues(alpha: 0.85),
                        padding:
                            const EdgeInsets.symmetric(vertical: 4),
                        child: const Text(
                          '⚡ URGENT — Pick up as soon as possible!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: kTeal)),
                    if (category.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: kTeal.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(category,
                            style: const TextStyle(
                                fontSize: 11,
                                color: kTeal,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                    const SizedBox(height: 14),
                    const Divider(height: 1, color: Color(0xFFEEEEEE)),
                    const SizedBox(height: 14),
                    if (donor.isNotEmpty)
                      _infoRow(Icons.person_outline, 'Donor', donor),
                    if (address.isNotEmpty)
                      _infoRow(Icons.location_on_outlined,
                          'Pickup Address', address),
                    if (distance.isNotEmpty)
                      _infoRow(
                          Icons.near_me_outlined, 'Distance', distance),
                    if (pickupType.isNotEmpty)
                      _infoRow(Icons.directions_outlined,
                          'Pickup Type', pickupType),
                    if (quantity.isNotEmpty)
                      _infoRow(
                          Icons.scale_outlined, 'Quantity', quantity),
                    if (expiresAt.isNotEmpty)
                      _infoRow(Icons.schedule_outlined, 'Expires',
                          _formatDate(expiresAt)),
                    _infoRow(Icons.circle, 'Status', status,
                        valueColor: status == 'available'
                            ? Colors.green
                            : kTerra),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      const Text('Description',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87)),
                      const SizedBox(height: 4),
                      Text(description,
                          style: const TextStyle(
                              fontSize: 12, color: kSage, height: 1.5)),
                    ],
                    const SizedBox(height: 20),
                    if (canReserve)
                      _actionButton(
                        label: 'Reserve This Donation',
                        icon: Icons.shopping_basket_outlined,
                        color: kTerra,
                        onTap: () {
                          Navigator.pop(context);
                          _showReserveConfirm(d);
                        },
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

  // ── Reserve confirm dialog ────────────────────────────────────────────────
  void _showReserveConfirm(Map<String, dynamic> d) {
    final photo      = d['photoUrl'] as String?;
    final title      = d['title'] ?? 'Donation';
    final category   = d['category'] ?? '';
    final donor      = d['donor']?['name'] ?? '';
    final address    = d['pickupAddress'] ?? '';
    final pickupType = d['pickupType'] ?? '';
    final status     = d['status'] ?? 'available';

    showDialog(
      context: context,
      barrierColor: Colors.black38,
      builder: (dialogCtx) => Dialog(
        insetPadding:
            const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: SingleChildScrollView(
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
                      height: 160, width: double.infinity,
                      child: Image.network(
                        photo.startsWith('http') ? photo : '$_base$photo',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _placeholder(),
                      ),
                    ),
                  ),
                const SizedBox(height: 14),
                _detailRow('Title :', title),
                _detailRow('Category :', category),
                if (donor.isNotEmpty) _detailRow('Donor :', donor),
                _detailRow('Pickup Address:', address),
                if (pickupType.isNotEmpty)
                  _detailRow('Pickup Type:', pickupType),
                _detailRow('Status:', status),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogCtx),
                      child: const Text('Back',
                          style: TextStyle(
                              color: kSage,
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kTerra,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                      ),
                      onPressed: () async {
                        Navigator.pop(dialogCtx);
                        await _doReserve(d);
                      },
                      icon: const Icon(Icons.shopping_basket_outlined,
                          color: kWhite, size: 18),
                      label: const Text('Confirm',
                          style: TextStyle(
                              color: kWhite,
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _doReserve(Map<String, dynamic> d) async {
    final donationId =
        d['id']?.toString() ?? d['_id']?.toString() ?? '';
    if (donationId.isEmpty) return;
    _showLoader();
    try {
      await ReservationService().createReservation(donationId);
      if (!mounted) return;
      Navigator.pop(context);
      _snack('Reservation sent! Waiting for donor to accept (within 2h).');
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      _snack('Error: $e', isError: true);
    }
  }

  // ── Shared UI helpers ─────────────────────────────────────────────────────

  Widget _actionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) =>
      SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 13),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
          ),
          onPressed: onTap,
          icon: Icon(icon, color: kWhite, size: 18),
          label: Text(label,
              style: const TextStyle(
                  color: kWhite,
                  fontSize: 14,
                  fontWeight: FontWeight.bold)),
        ),
      );

  void _showLoader() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          const Center(child: CircularProgressIndicator(color: kTeal)),
    );
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red : Colors.green,
    ));
  }

  Widget _placeholder() => Container(
        color: kSage,
        child: const Center(
            child: Icon(Icons.fastfood, color: kWhite, size: 48)));

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
                    color: Colors.black87)),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    fontSize: 12,
                    color: valueColor ?? kSage,
                    fontWeight: valueColor != null
                        ? FontWeight.w600
                        : FontWeight.normal)),
          ),
        ],
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
                      color: Colors.black87)),
            ),
            Expanded(
              child: Text(value,
                  style: const TextStyle(fontSize: 13, color: kSage)),
            ),
          ],
        ),
      );

  // ── Icon / colour per type ────────────────────────────────────────────────
  IconData _iconFor(String? type) {
    switch (type) {
      case 'DONATION_POSTED':      return Icons.volunteer_activism_outlined;
      case 'RESERVATION_REQUESTED': return Icons.bookmark_add_outlined;
      case 'RESERVATION_ACCEPTED': return Icons.check_circle_outline;
      case 'RESERVATION_CANCELLED':
      case 'RESERVATION_CANCELED': return Icons.cancel_outlined;
      case 'DONATION_COMPLETED':   return Icons.volunteer_activism;
      case 'NEW_MESSAGE':          return Icons.chat_bubble_outline;
      default:                     return Icons.notifications_outlined;
    }
  }

  Color _colorFor(String? type) {
    switch (type) {
      case 'DONATION_POSTED':      return kTeal;
      case 'RESERVATION_REQUESTED': return kTerra;
      case 'RESERVATION_ACCEPTED': return Colors.green;
      case 'RESERVATION_CANCELLED':
      case 'RESERVATION_CANCELED': return Colors.redAccent;
      case 'DONATION_COMPLETED':   return kTeal;
      case 'NEW_MESSAGE':          return Colors.blueAccent;
      default:                     return kSage;
    }
  }

  String _tapHint(String? type) {
    switch (type) {
      case 'NEW_MESSAGE':            return 'Tap to open chat';
      case 'DONATION_POSTED':
      case 'DONATION_COMPLETED':     return 'Tap to view donation';
      case 'RESERVATION_REQUESTED':  return 'Tap to confirm or cancel';
      case 'RESERVATION_ACCEPTED':
      case 'RESERVATION_CANCELLED':
      case 'RESERVATION_CANCELED':   return 'Tap to view reservation';
      default:                       return 'Tap to view details';
    }
  }

  String _timeAgo(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1)  return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours   < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

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
      body: Column(
        children: [
          // Header
          Container(
            color: kTeal,
            padding: const EdgeInsets.fromLTRB(16, 56, 16, 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Notifications',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: kWhite)),
                if (_unreadCount > 0)
                  GestureDetector(
                    onTap: _markAllRead,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                          color: kTerra,
                          borderRadius: BorderRadius.circular(20)),
                      child: Text('Mark all read ($_unreadCount)',
                          style: const TextStyle(
                              color: kWhite, fontSize: 12)),
                    ),
                  ),
              ],
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: kTeal))
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.wifi_off,
                                color: kSage, size: 36),
                            const SizedBox(height: 8),
                            Text(_error!,
                                style: const TextStyle(
                                    color: kSage, fontSize: 13)),
                            TextButton(
                              onPressed: _fetch,
                              child: const Text('Retry',
                                  style: TextStyle(color: kTeal)),
                            ),
                          ],
                        ),
                      )
                    : _notifications.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.notifications_off_outlined,
                                    color: kSage, size: 48),
                                SizedBox(height: 12),
                                Text('No notifications yet',
                                    style: TextStyle(
                                        color: kSage, fontSize: 14)),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            color: kTeal,
                            onRefresh: _fetch,
                            child: ListView.separated(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 8),
                              itemCount: _notifications.length,
                              separatorBuilder: (_, __) => const Divider(
                                  height: 1,
                                  indent: 72,
                                  color: Color(0xFFE0E0E0)),
                              itemBuilder: (_, i) =>
                                  _buildItem(_notifications[i]),
                            ),
                          ),
          ),
        ],
      ),
      bottomNavigationBar: const SharedBottomNav(currentIndex: 3),
    );
  }

  Widget _buildItem(Map<String, dynamic> n) {
    final bool isRead = n['isRead'] == true;
    final String? type = n['type'] as String?;

    return InkWell(
      onTap: () => _onTap(n),
      child: Container(
        color: isRead
            ? Colors.transparent
            : kTeal.withValues(alpha: 0.05),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon bubble
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: _colorFor(type).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(_iconFor(type),
                  color: _colorFor(type), size: 22),
            ),
            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(n['title'] ?? '',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: isRead
                                    ? FontWeight.w500
                                    : FontWeight.bold,
                                color: Colors.black87)),
                      ),
                      const SizedBox(width: 8),
                      Text(_timeAgo(n['createdAt'] as String?),
                          style: const TextStyle(
                              fontSize: 11, color: kSage)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(n['message'] ?? '',
                      style: const TextStyle(
                          fontSize: 12, color: kSage, height: 1.4)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        type == 'NEW_MESSAGE'
                            ? Icons.chat_bubble_outline
                            : type == 'RESERVATION_REQUESTED'
                                ? Icons.touch_app_outlined
                                : Icons.open_in_new,
                        size: 11,
                        color: kTerra,
                      ),
                      const SizedBox(width: 3),
                      Text(_tapHint(type),
                          style: const TextStyle(
                              fontSize: 10,
                              color: kTerra,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                ],
              ),
            ),

            // Unread dot
            if (!isRead)
              Container(
                width: 8, height: 8,
                margin: const EdgeInsets.only(top: 4, left: 8),
                decoration: const BoxDecoration(
                    color: kTerra, shape: BoxShape.circle),
              ),
          ],
        ),
      ),
    );
  }
}