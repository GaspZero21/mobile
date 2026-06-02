import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../theme/colors.dart';
import '../services/app_token.dart';
import '../services/reservation_service.dart';
import '../widgets/shared_bottom_nav.dart';
import 'package:image_picker/image_picker.dart';
import '../services/donation_service.dart';
import '../widgets/report_user_sheet.dart';

// ── My Donations List ─────────────────────────────────────────────────────────
class MyDonationsScreen extends StatefulWidget {
  const MyDonationsScreen({super.key});

  @override
  State<MyDonationsScreen> createState() => _MyDonationsScreenState();
}

class _MyDonationsScreenState extends State<MyDonationsScreen> {
  static const String baseUrl =
      'https://gasp-test-production.up.railway.app/api/v1';

  List<Map<String, dynamic>> _donations = [];
  bool    _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Map<String, String> get _headers {
    final token = AppToken.get();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Safely extract the donation id — API may return 'id' or '_id'
  String _donationId(Map<String, dynamic> d) =>
      d['id']?.toString() ?? d['_id']?.toString() ?? '';

  Future<void> _fetch() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final res  = await http.get(
          Uri.parse('$baseUrl/donations/my'), headers: _headers);
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode != 200) {
        throw Exception(body['message'] ?? 'Error ${res.statusCode}');
      }
      final data = body['data'];
      List list  = [];
      if (data is List) {
        list = data;
      } else if (data is Map) {
        if (data['donations'] is List) list = data['donations'];
        else if (data['items'] is List) list = data['items'];
        else list = [data];
      } else if (body['donations'] is List) {
        list = body['donations'];
      }
      setState(() {
        _donations = List<Map<String, dynamic>>.from(list);
        _isLoading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _isLoading = false; });
    }
  }
  
  Future<void> _delete(String id) async {
    if (id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot identify donation'),
            backgroundColor: Colors.red));
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete donation?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel', style: TextStyle(color: kSage))),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete',
                  style: TextStyle(color: Colors.red,
                      fontWeight: FontWeight.bold))),
        ],
      ),
    );
    if (confirm != true) return;

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
          child: CircularProgressIndicator(color: kTeal)),
    );

    try {
      final res = await http.delete(
          Uri.parse('$baseUrl/donations/$id'), headers: _headers);
      if (!mounted) return;
      Navigator.pop(context); // dismiss loading

      debugPrint('[Delete] status=${res.statusCode} body=${res.body}');

      if (res.statusCode >= 200 && res.statusCode < 300) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Donation deleted'),
              backgroundColor: Colors.green));
        _fetch(); // refresh list
      } else {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(body['message'] ?? 'Delete failed'),
              backgroundColor: Colors.red));
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }
  Future<void> _cancelDonation(String id) async {
   final confirm = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Cancel donation?'),
      content: const Text('This will cancel the donation and notify beneficiaries.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Back', style: TextStyle(color: kSage)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Cancel Donation',
              style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
        ),
      ],
    ),
    );
    if (confirm != true) return;
    showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator(color: kTeal)),
    );
   try {
    await DonationService().cancelDonation(id);
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Donation cancelled'), backgroundColor: Colors.orange),
    );
    _fetch();
    } catch (e) {
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
    );
   }
  }

  void _openEdit(Map<String, dynamic> donation) {
    Navigator.push(context,
      MaterialPageRoute(builder: (_) => EditDonationScreen(donation: donation)),
    ).then((updated) { if (updated == true) _fetch(); });
  }

  void _showReservations(Map<String, dynamic> donation) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReservationsSheet(donation: donation),
    ).then((_) => _fetch());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSand,
      appBar: AppBar(
        backgroundColor: kTeal,
        foregroundColor: kWhite,
        title: const Text('My Donations',
            style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetch),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kTeal))
          : _error != null
              ? Center(child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.wifi_off, color: kSage, size: 36),
                    const SizedBox(height: 8),
                    Text(_error!, style: const TextStyle(color: kSage),
                        textAlign: TextAlign.center),
                    TextButton(onPressed: _fetch,
                        child: const Text('Retry',
                            style: TextStyle(color: kTeal))),
                  ]))
              : _donations.isEmpty
                  ? const Center(child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox_outlined, color: kSage, size: 48),
                        SizedBox(height: 12),
                        Text('You have no donations yet',
                            style: TextStyle(color: kSage, fontSize: 14)),
                      ]))
                  : RefreshIndicator(
                      color: kTeal,
                      onRefresh: _fetch,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _donations.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, i) => _buildCard(_donations[i]),
                      ),
                    ),
      bottomNavigationBar: const SharedBottomNav(currentIndex: 4),
    );
  }

  Widget _buildCard(Map<String, dynamic> d) {
    const base   = 'https://gasp-test-production.up.railway.app/';
    final photo  = d['photoUrl'] as String?;
    final status = d['status'] ?? 'available';
    final urgent = d['isUrgent'] == true;
    final statusColor = status == 'available' ? Colors.green : kTerra;
    final id = _donationId(d);

    return Container(
      decoration: BoxDecoration(
          color: kWhite, borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            bottomLeft: Radius.circular(16),
          ),
          child: SizedBox(
            width: 110, height: 120,
            child: photo != null && photo.isNotEmpty
                ? Image.network(
                    photo.startsWith('http') ? photo : '$base$photo',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                        color: kSage,
                        child: const Icon(Icons.fastfood,
                            color: kWhite, size: 32)),
                  )
                : Container(color: kSage,
                    child: const Icon(Icons.fastfood, color: kWhite, size: 32)),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(child: Text(d['title'] ?? '',
                      style: const TextStyle(fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87))),
                  if (urgent)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: kTerra,
                          borderRadius: BorderRadius.circular(6)),
                      child: const Text('URGENT', style: TextStyle(
                          fontSize: 9, color: kWhite,
                          fontWeight: FontWeight.bold)),
                    ),
                ]),
                const SizedBox(height: 4),
                Row(children: [
                  Icon(Icons.circle, size: 7, color: statusColor),
                  const SizedBox(width: 4),
                  Text(status, style: TextStyle(fontSize: 11, color: statusColor)),
                ]),
                const SizedBox(height: 2),
                Text(d['category'] ?? '',
                    style: const TextStyle(fontSize: 11, color: kSage)),
                if (d['totalQuantity'] != null)
                  Text(
                    '${d['totalQuantity']} ${d['quantityUnit'] ?? ''}',
                    style: const TextStyle(fontSize: 11, color: kSage),
                  ),
                const SizedBox(height: 10),
                Row(children: [
  _btn('Reservations', kTeal, () => _showReservations(d)),
  const SizedBox(width: 6),
  _btn('Edit', kTerra, () => _openEdit(d), icon: Icons.edit_outlined),
  const SizedBox(width: 6),
  // Cancel donation button (only when available)
  if (status == 'available') ...[
    GestureDetector(
      onTap: () => _cancelDonation(id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(8)),
        child: const Icon(Icons.cancel_outlined,
            color: Colors.orange, size: 16),
      ),
    ),
    const SizedBox(width: 6),
  ],
  GestureDetector(
    onTap: () => _delete(id),
    child: Container(
      width: 30, height: 30,
      decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(8)),
      child: const Icon(Icons.delete_outline,
          color: Colors.red, size: 16),
    ),
  ),
]),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  Widget _btn(String label, Color color, VoidCallback onTap,
      {IconData? icon}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(20)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[
              Icon(icon, color: kWhite, size: 11),
              const SizedBox(width: 3),
            ],
            Text(label, style: const TextStyle(
                color: kWhite, fontSize: 10, fontWeight: FontWeight.w600)),
          ]),
        ),
      );
}

// ── Reservations bottom sheet ─────────────────────────────────────────────────
class _ReservationsSheet extends StatefulWidget {
  final Map<String, dynamic> donation;
  const _ReservationsSheet({required this.donation});

  @override
  State<_ReservationsSheet> createState() => _ReservationsSheetState();
}

class _ReservationsSheetState extends State<_ReservationsSheet> {
  List<Map<String, dynamic>> _reservations = [];
  bool    _loading = true;
  String? _actionError;

  static const String baseUrl =
      'https://gasp-test-production.up.railway.app/api/v1';

  Map<String, String> get _headers {
    final token = AppToken.get();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  String _donationId(Map<String, dynamic> d) =>
      d['id']?.toString() ?? d['_id']?.toString() ?? '';

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
  setState(() { _loading = true; _actionError = null; });
  try {
    final donationId = _donationId(widget.donation);
    if (donationId.isEmpty) throw Exception('Unknown donation ID');

    // Use the dedicated endpoint: GET /donations/{id}/reservations
    final res = await http.get(
      Uri.parse('$baseUrl/donations/$donationId/reservations'),
      headers: _headers,
    );

    if (res.statusCode != 200) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      throw Exception(body['message'] ?? 'Error ${res.statusCode}');
    }

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final data = body['data'];
    List list = [];
    if (data is List) {
      list = data;
    } else if (data is Map) {
      if (data['reservations'] is List) list = data['reservations'];
      else if (data['items'] is List)   list = data['items'];
    } else if (body['reservations'] is List) {
      list = body['reservations'];
    }

    if (!mounted) return;
    setState(() {
      _reservations = List<Map<String, dynamic>>.from(list);
      _loading = false;
    });
  } catch (e) {
    if (!mounted) return;
    setState(() { _loading = false; _actionError = e.toString(); });
  }
}

  Future<void> _confirm(String id) async {
    _showLoadingOverlay();
    try {
      await ReservationService().confirmReservation(id);
      if (!mounted) return;
      Navigator.pop(context);
      _snack('Reservation confirmed ✓', Colors.green);
      _fetch();
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      _snack('Error: $e', Colors.red);
    }
  }

  Future<void> _cancel(String id) async {
    final ok = await _confirmDialog(
      title: 'Cancel this reservation?',
      message: 'The beneficiary will be notified.',
      actionLabel: 'Yes, Cancel',
    );
    if (!ok) return;
    _showLoadingOverlay();
    try {
      await ReservationService().cancelReservation(id);
      if (!mounted) return;
      Navigator.pop(context);
      _snack('Reservation cancelled', kTerra);
      _fetch();
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      _snack('Error: $e', Colors.red);
    }
  }

  Future<void> _complete(String id) async {
    final ok = await _confirmDialog(
      title: 'Mark as completed?',
      message: 'Confirm the beneficiary has picked up this donation.',
      actionLabel: 'Yes, Complete',
      actionColor: Colors.green,
    );
    if (!ok) return;
    _showLoadingOverlay();
    try {
      await ReservationService().completeReservation(id);
      if (!mounted) return;
      Navigator.pop(context);
      _snack('Donation completed 🎉', Colors.green);
      _fetch();
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      _snack('Error: $e', Colors.red);
    }
  }

  Future<void> _updateQuantity(String id, double currentQty) async {
    final ctrl = TextEditingController(text: currentQty.toString());
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Update Quantity',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: kTeal)),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            hintText: 'Enter new quantity',
            hintStyle: TextStyle(color: kSage),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: kSage)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: kTeal, elevation: 0),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Update',
                style: TextStyle(color: kWhite, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final newQty = double.tryParse(ctrl.text.trim());
    if (newQty == null || newQty <= 0) {
      _snack('Enter a valid quantity', Colors.orange);
      return;
    }
    _showLoadingOverlay();
    try {
      final token = AppToken.get();
      final headers = {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };
      final res = await http.patch(
        Uri.parse('$baseUrl/reservations/$id'),
        headers: headers,
        body: jsonEncode({'requestedQuantity': newQty}),
      );
      if (!mounted) return;
      Navigator.pop(context);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        _snack('Quantity updated ✓', Colors.green);
        _fetch();
      } else {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        _snack(body['message'] ?? 'Update failed', Colors.red);
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      _snack('Error: $e', Colors.red);
    }
  }

  void _showLoadingOverlay() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
          child: CircularProgressIndicator(color: kTeal)),
    );
  }

  Future<bool> _confirmDialog({
    required String title,
    required String message,
    required String actionLabel,
    Color actionColor = kTerra,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            title: Text(title,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold)),
            content: Text(message,
                style: const TextStyle(fontSize: 13, color: kSage)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Back',
                    style: TextStyle(color: kSage)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: actionColor,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                ),
                onPressed: () => Navigator.pop(context, true),
                child: Text(actionLabel,
                    style: const TextStyle(
                        color: kWhite, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed': return Colors.green;
      case 'cancelled':
      case 'canceled':  return Colors.red;
      case 'completed': return kTeal;
      default:          return Colors.orange;
    }
  }

  IconData _statusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed': return Icons.check_circle_outline;
      case 'cancelled':
      case 'canceled':  return Icons.cancel_outlined;
      case 'completed': return Icons.done_all;
      default:          return Icons.hourglass_empty;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4,
            decoration: BoxDecoration(color: kSage.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),

        Text('Reservations for "${widget.donation['title']}"',
            style: const TextStyle(fontSize: 15,
                fontWeight: FontWeight.bold, color: kTeal),
            textAlign: TextAlign.center),
        const SizedBox(height: 4),

        const Text(
          'You must confirm or cancel each request within 2 hours.',
          style: TextStyle(fontSize: 11, color: kSage),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),

        if (_loading)
          const Padding(padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(color: kTeal))
        else if (_actionError != null)
          Padding(padding: const EdgeInsets.all(16),
              child: Text(_actionError!,
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                  textAlign: TextAlign.center))
        else if (_reservations.isEmpty)
          const Padding(padding: EdgeInsets.all(32),
              child: Text('No reservations yet',
                  style: TextStyle(color: kSage, fontSize: 14)))
        else
          ConstrainedBox(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.55),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _reservations.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: Color(0xFFEEEEEE)),
              itemBuilder: (_, i) => _tile(_reservations[i]),
            ),
          ),
      ]),
    );
  }

  Widget _tile(Map<String, dynamic> r) {
    final requester = r['requester'] ?? r['beneficiary'] ?? r['user'] ?? {};
    final name      = requester['name'] as String? ?? 'Unknown';
    final status    = (r['status'] as String? ?? 'pending').toLowerCase();
    final id        = r['id']?.toString() ?? r['_id']?.toString() ?? '';
    final isPending   = status == 'pending';
    final isConfirmed = status == 'confirmed';

    final rawQty = r['requestedQuantity'] ?? r['quantity'] ?? 0;
    final double requestedQty = rawQty is num
        ? rawQty.toDouble()
        : double.tryParse(rawQty.toString()) ?? 0.0;

    final createdAt = r['createdAt'] as String?;
    String timeStr = '';
    if (createdAt != null) {
      final dt = DateTime.tryParse(createdAt)?.toLocal();
      if (dt != null) {
        timeStr =
            '${dt.day.toString().padLeft(2,'0')}/'
            '${dt.month.toString().padLeft(2,'0')} '
            '${dt.hour.toString().padLeft(2,'0')}:'
            '${dt.minute.toString().padLeft(2,'0')}';
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: kSage.withOpacity(0.2),
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(
                    color: kTeal, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            const SizedBox(width: 12),

            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 13,
                    fontWeight: FontWeight.w600, color: Colors.black87)),
                if (timeStr.isNotEmpty)
                  Text(timeStr, style: const TextStyle(
                      fontSize: 11, color: kSage)),
                Text(
                  'Qty: ${requestedQty == requestedQty.roundToDouble() ? requestedQty.toInt() : requestedQty.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 11, color: kSage),
                ),
              ],
            )),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _statusColor(status).withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(_statusIcon(status),
                    size: 12, color: _statusColor(status)),
                const SizedBox(width: 4),
                Text(status,
                    style: TextStyle(fontSize: 11,
                        color: _statusColor(status),
                        fontWeight: FontWeight.w600)),
              ]),
            ),
          ]),
          // After the status badge container, add:
const SizedBox(width: 8),
GestureDetector(
  onTap: () {
    final requesterId = requester['id']?.toString() ?? requester['_id']?.toString() ?? '';
    if (requesterId.isNotEmpty) {
      showReportUserSheet(context, userId: requesterId, userName: name);
    }
  },
  child: Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.red.shade50,
      borderRadius: BorderRadius.circular(12),
    ),
    child: const Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.flag_outlined, size: 12, color: Colors.red),
      SizedBox(width: 3),
      Text('Report', style: TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.w600)),
    ]),
  ),
),

          if (isPending || isConfirmed) ...[
            const SizedBox(height: 10),
            Row(children: [
              const SizedBox(width: 56),

              if (isPending) ...[
                _actionBtn(label: 'Confirm', color: Colors.green,
                    icon: Icons.check, onTap: () => _confirm(id)),
                const SizedBox(width: 6),
                _actionBtn(label: 'Qty', color: kTeal,
                    icon: Icons.edit_outlined,
                    onTap: () => _updateQuantity(id, requestedQty)),
                const SizedBox(width: 6),
                _actionBtn(label: 'Cancel', color: kTerra,
                    icon: Icons.close, onTap: () => _cancel(id)),
              ],

              if (isConfirmed) ...[
                _actionBtn(label: 'Completed', color: kTeal,
                    icon: Icons.done_all, onTap: () => _complete(id)),
                const SizedBox(width: 8),
                _actionBtn(label: 'Cancel', color: kTerra,
                    icon: Icons.close, onTap: () => _cancel(id)),
              ],
            ]),
          ],
        ],
      ),
    );
  }

  Widget _actionBtn({
    required String label,
    required Color color,
    required IconData icon,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(20)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: kWhite, size: 13),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(
                color: kWhite, fontSize: 11, fontWeight: FontWeight.bold)),
          ]),
        ),
      );
}

// ── Edit Donation Screen ──────────────────────────────────────────────────────
class EditDonationScreen extends StatefulWidget {
  final Map<String, dynamic> donation;
  const EditDonationScreen({super.key, required this.donation});

  @override
  State<EditDonationScreen> createState() => _EditDonationScreenState();
}

class _EditDonationScreenState extends State<EditDonationScreen> {
  static const String baseUrl =
      'https://gasp-test-production.up.railway.app/api/v1';

  late final TextEditingController _titleController;
  late final TextEditingController _quantityController;
  late final TextEditingController _unitController;
  late final TextEditingController _addressController;
  late final TextEditingController _descriptionController;

  String?   _selectedCategory;
  String?   _selectedUnit;
  String    _pickupTypeKey = 'Home';
  bool      _isUrgent   = false;
  DateTime? _expiresAt;
  bool      _isLoading  = false;
  bool      _isLocating = false;
  double?   _latitude;
  double?   _longitude;

  Uint8List? _photoBytes;
  String?    _photoName;
  String?    _existingPhotoUrl;

  static const _pickupTypes = {
    'Home':         'home',
    'Public Place': 'public_place',
  };

  final List<Map<String, String>> _categories = [
    {'value': 'fruits_vegetables', 'label': 'Fruits & Vegetables'},
    {'value': 'dry_goods',         'label': 'Dry Goods'},
    {'value': 'cooked_meal',       'label': 'Cooked Meal'},
    {'value': 'dairy',             'label': 'Dairy'},
    {'value': 'bakery',            'label': 'Bakery'},
    {'value': 'other',             'label': 'Other'},
  ];

  final List<String> _units = ['kg', 'g', 'L', 'ml', 'pieces', 'portions', 'boxes', 'bags'];

  @override
  void initState() {
    super.initState();
    final d = widget.donation;
    _titleController       = TextEditingController(text: d['title'] ?? '');
    _addressController     = TextEditingController(text: d['pickupAddress'] ?? '');
    _descriptionController = TextEditingController(text: d['description'] ?? '');
    _selectedCategory      = d['category'] as String?;
    _isUrgent              = d['isUrgent'] == true;
    _existingPhotoUrl      = d['photoUrl'] as String?;
    _latitude  = double.tryParse(d['latitude']?.toString() ?? '');
    _longitude = double.tryParse(d['longitude']?.toString() ?? '');

    _quantityController = TextEditingController(
        text: d['totalQuantity']?.toString() ?? '');

    final unitFromApi = d['quantityUnit']?.toString() ?? 'kg';
    _selectedUnit = _units.contains(unitFromApi) ? unitFromApi : _units.first;
    _unitController = TextEditingController(text: _selectedUnit);

    final apiType = d['pickupType'] as String? ?? 'home';
    _pickupTypeKey = _pickupTypes.entries
        .firstWhere((e) => e.value == apiType,
            orElse: () => const MapEntry('Home', 'home'))
        .key;

    final exp = d['expiresAt'] as String?;
    if (exp != null) _expiresAt = DateTime.tryParse(exp);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _quantityController.dispose();
    _unitController.dispose();
    _addressController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() {
      _photoBytes = bytes;
      _photoName  = picked.name;
    });
  }

  bool get _hasNewPhoto => _photoBytes != null;
  bool get _hasPhoto =>
      _photoBytes != null ||
      (_existingPhotoUrl != null && _existingPhotoUrl!.isNotEmpty);

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiresAt ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(primary: kTeal)),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _expiresAt = picked);
  }

  String get _expiresAtDisplay {
    if (_expiresAt == null) return 'Expiry Date';
    return '${_expiresAt!.year}-'
        '${_expiresAt!.month.toString().padLeft(2, '0')}-'
        '${_expiresAt!.day.toString().padLeft(2, '0')}';
  }

  Future<void> _detectLocation() async {
    setState(() => _isLocating = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _snack('Location permission denied');
        return;
      }
      final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium);
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?lat=${position.latitude}&lon=${position.longitude}&format=json',
      );
      final response =
          await http.get(uri, headers: {'User-Agent': 'MadadApp/1.0'});
      String address =
          '${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}';
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final dn   = json['display_name'] as String?;
        if (dn != null && dn.isNotEmpty) address = dn;
      }
      setState(() {
        _latitude  = position.latitude;
        _longitude = position.longitude;
        _addressController.text = address;
      });
    } catch (e) {
      _snack('Location failed: $e');
    } finally {
      setState(() => _isLocating = false);
    }
  }

  Future<void> _onSave() async {
    if (_titleController.text.trim().isEmpty) {
      _snack('Please enter a title'); return;
    }
    if (_selectedCategory == null) {
      _snack('Please select a category'); return;
    }
    if (_addressController.text.trim().isEmpty) {
      _snack('Please enter a pickup address'); return;
    }
    final qtyValue = double.tryParse(_quantityController.text.trim());
    if (qtyValue == null || qtyValue <= 0) {
      _snack('Please enter a valid quantity'); return;
    }
    final unit = _selectedUnit ?? _unitController.text.trim();
    if (unit.isEmpty) {
      _snack('Please select a unit'); return;
    }

    setState(() => _isLoading = true);
    try {
      final id    = widget.donation['id']?.toString() ??
                    widget.donation['_id']?.toString() ?? '';
      final token = AppToken.get();

      if (_photoBytes != null) {
        final uri     = Uri.parse('$baseUrl/donations/$id');
        final request = http.MultipartRequest('PUT', uri);
        if (token != null) request.headers['Authorization'] = 'Bearer $token';

        request.fields['title']         = _titleController.text.trim();
        request.fields['category']      = _selectedCategory!;
        request.fields['totalQuantity'] = qtyValue.toString();
        request.fields['quantityUnit']  = unit;
        request.fields['pickupAddress'] = _addressController.text.trim();
        request.fields['pickupType']    = _pickupTypes[_pickupTypeKey]!;
        request.fields['isUrgent']      = _isUrgent.toString();
        if (_descriptionController.text.trim().isNotEmpty) {
          request.fields['description'] = _descriptionController.text.trim();
        }
        if (_expiresAt != null) request.fields['expiresAt'] = _expiresAtDisplay;
        if (_latitude  != null) request.fields['latitude']  = _latitude.toString();
        if (_longitude != null) request.fields['longitude'] = _longitude.toString();

        request.files.add(http.MultipartFile.fromBytes(
            'photo', _photoBytes!, filename: _photoName ?? 'photo.jpg'));

        final streamed = await request.send();
        final response = await http.Response.fromStream(streamed);
        if (response.statusCode >= 200 && response.statusCode < 300) {
          if (!mounted) return;
          Navigator.pop(context, true);
        } else {
          final b = jsonDecode(response.body);
          _snack(b['message'] ?? 'Update failed');
        }
      } else {
        final payload = <String, dynamic>{
          'title':         _titleController.text.trim(),
          'category':      _selectedCategory!,
          'totalQuantity': qtyValue,
          'quantityUnit':  unit,
          'pickupAddress': _addressController.text.trim(),
          'pickupType':    _pickupTypes[_pickupTypeKey]!,
          'isUrgent':      _isUrgent,
        };
        if (_descriptionController.text.trim().isNotEmpty) {
          payload['description'] = _descriptionController.text.trim();
        }
        if (_expiresAt != null) payload['expiresAt'] = _expiresAtDisplay;
        if (_latitude  != null) payload['latitude']  = _latitude;
        if (_longitude != null) payload['longitude'] = _longitude;

        final res = await http.put(
          Uri.parse('$baseUrl/donations/$id'),
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
          body: jsonEncode(payload),
        );

        if (res.statusCode >= 200 && res.statusCode < 300) {
          if (!mounted) return;
          Navigator.pop(context, true);
        } else {
          final b = jsonDecode(res.body);
          _snack(b['message'] ?? 'Update failed');
        }
      }
    } catch (e) {
      _snack('Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _snack(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    const base = 'https://gasp-test-production.up.railway.app/';
    return Scaffold(
      backgroundColor: kSand,
      body: Column(children: [
        Container(
          color: kSand,
          padding: const EdgeInsets.fromLTRB(16, 56, 16, 12),
          child: Stack(alignment: Alignment.center, children: [
            const Text('Edit Donation', style: TextStyle(fontSize: 20,
                fontWeight: FontWeight.bold, color: kTeal)),
            Align(
              alignment: Alignment.centerLeft,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.arrow_back_ios, color: kTeal, size: 20),
              ),
            ),
          ]),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Photo picker
                GestureDetector(
                  onTap: _pickPhoto,
                  child: Container(
                    width: double.infinity, height: 130,
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: _hasPhoto ? Colors.transparent : kTeal,
                          width: 1.5),
                      borderRadius: BorderRadius.circular(12),
                      color: kWhite,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: _hasNewPhoto
                          ? Image.memory(_photoBytes!, fit: BoxFit.cover,
                              width: double.infinity)
                          : (_existingPhotoUrl != null &&
                                  _existingPhotoUrl!.isNotEmpty)
                              ? Stack(fit: StackFit.expand, children: [
                                  Image.network(
                                    _existingPhotoUrl!.startsWith('http')
                                        ? _existingPhotoUrl!
                                        : '$base$_existingPhotoUrl',
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        _photoPlaceholder(),
                                  ),
                                  Container(
                                    color: Colors.black12,
                                    child: const Center(child: Icon(
                                        Icons.edit, color: kWhite, size: 28)),
                                  ),
                                ])
                              : _photoPlaceholder(),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Title
                _label('Title *'),
                const SizedBox(height: 6),
                _box(TextField(controller: _titleController,
                    decoration: _deco('Write A Title'))),
                const SizedBox(height: 14),

                // ── Category
                _label('Category *'),
                const SizedBox(height: 6),
                _box(DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  hint: const Text('Select A Category',
                      style: TextStyle(color: kSage, fontSize: 13)),
                  decoration: const InputDecoration(
                    border: InputBorder.none, isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14)),
                  items: _categories.map((c) => DropdownMenuItem(
                      value: c['value'],
                      child: Text(c['label']!))).toList(),
                  onChanged: (v) => setState(() => _selectedCategory = v),
                )),
                const SizedBox(height: 14),

                // ── Quantity + Unit on one row
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Expanded(
                    flex: 3,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('Quantity *'),
                        const SizedBox(height: 6),
                        _box(TextField(
                          controller: _quantityController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: _deco('e.g. 5'),
                        )),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('Unit *'),
                        const SizedBox(height: 6),
                        _box(DropdownButtonFormField<String>(
                          value: _selectedUnit,
                          decoration: const InputDecoration(
                            border: InputBorder.none, isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 10, vertical: 14)),
                          items: _units.map((u) => DropdownMenuItem(
                              value: u, child: Text(u,
                              style: const TextStyle(fontSize: 13)))).toList(),
                          onChanged: (v) {
                            if (v != null) setState(() {
                              _selectedUnit = v;
                              _unitController.text = v;
                            });
                          },
                        )),
                      ],
                    ),
                  ),
                ]),
                const SizedBox(height: 14),

                // ── Expiry date on its own row (no overflow)
                _label('Expiration Date'),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: _pickDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 13),
                    decoration: BoxDecoration(color: kWhite,
                        borderRadius: BorderRadius.circular(10)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_expiresAtDisplay,
                            style: TextStyle(fontSize: 13,
                                color: _expiresAt == null
                                    ? kSage : Colors.black87)),
                        const Icon(Icons.calendar_today_outlined,
                            color: kSage, size: 18),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // ── Urgent toggle
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(color: kWhite,
                      borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('Mark As Urgent', style: TextStyle(fontSize: 13,
                              fontWeight: FontWeight.w600, color: Colors.black87)),
                          SizedBox(height: 2),
                          Text('Donation needed immediately',
                              style: TextStyle(fontSize: 11, color: kSage)),
                        ],
                      ),
                      Switch(value: _isUrgent, activeColor: kTerra,
                          onChanged: (v) => setState(() => _isUrgent = v)),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // ── Pickup address
                _label('Pickup Address *'),
                const SizedBox(height: 6),
                _box(Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        GestureDetector(
                          onTap: _isLocating ? null : _detectLocation,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                                color: _isLocating ? kSage : kTerra,
                                borderRadius: BorderRadius.circular(20)),
                            child: _isLocating
                                ? const SizedBox(width: 14, height: 14,
                                    child: CircularProgressIndicator(
                                        color: kWhite, strokeWidth: 2))
                                : const Text('Locate Me', style: TextStyle(
                                    color: kWhite, fontSize: 12,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: TextField(
                          controller: _addressController,
                          style: const TextStyle(fontSize: 13, color: Colors.black87),
                          decoration: const InputDecoration(
                            hintText: 'Or type your address…',
                            hintStyle: TextStyle(color: kSage, fontSize: 12),
                            border: InputBorder.none, isDense: true,
                            contentPadding: EdgeInsets.zero),
                        )),
                      ]),
                      if (_latitude != null && _longitude != null) ...[
                        const SizedBox(height: 6),
                        Row(children: [
                          const Icon(Icons.location_on, size: 12, color: kTeal),
                          const SizedBox(width: 4),
                          Expanded(child: Text(
                            'lat: ${_latitude!.toStringAsFixed(5)}, '
                            'lng: ${_longitude!.toStringAsFixed(5)}',
                            style: const TextStyle(fontSize: 11, color: kTeal),
                          )),
                        ]),
                      ],
                    ],
                  ),
                )),
                const SizedBox(height: 14),

                // ── Pickup type
                _label('Pickup Type *'),
                const SizedBox(height: 8),
                Row(children: [
                  _pickupToggle('Home'),
                  const SizedBox(width: 24),
                  _pickupToggle('Public Place'),
                ]),
                const SizedBox(height: 14),

                // ── Description
                _label('About Your Donation'),
                const SizedBox(height: 6),
                _box(TextField(controller: _descriptionController, maxLines: 3,
                    decoration: _deco('Describe Your Donation'))),
                const SizedBox(height: 28),

                // ── Save button
                Center(
                  child: SizedBox(
                    width: 200, height: 50,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kTerra,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30)),
                        elevation: 0,
                      ),
                      onPressed: _isLoading ? null : _onSave,
                      icon: _isLoading
                          ? const SizedBox(width: 18, height: 18,
                              child: CircularProgressIndicator(
                                  color: kWhite, strokeWidth: 2))
                          : const Icon(Icons.check, color: kWhite, size: 20),
                      label: const Text('Save Changes', style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold,
                          color: kWhite)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ]),
      bottomNavigationBar: const SharedBottomNav(currentIndex: 4),
    );
  }

  Widget _photoPlaceholder() => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.add_photo_alternate_outlined, color: kTeal, size: 36),
          SizedBox(height: 8),
          Text('Tap to change photo',
              style: TextStyle(fontSize: 12, color: kTeal)),
        ],
      );

  Widget _label(String t) => Text(t, style: const TextStyle(
      fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87));

  Widget _box(Widget child) => Container(
      decoration: BoxDecoration(color: kWhite,
          borderRadius: BorderRadius.circular(10)),
      child: child);

  InputDecoration _deco(String hint) => InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: kSage, fontSize: 13),
      border: InputBorder.none, isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14));

  Widget _pickupToggle(String label) {
    final bool active = _pickupTypeKey == label;
    return GestureDetector(
      onTap: () => setState(() => _pickupTypeKey = label),
      child: Row(children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 36, height: 20,
          decoration: BoxDecoration(
              color: active ? kTeal : const Color(0xFFD0D0D0),
              borderRadius: BorderRadius.circular(10)),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 200),
            alignment: active ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.all(2),
              width: 16, height: 16,
              decoration: const BoxDecoration(
                  color: kWhite, shape: BoxShape.circle),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 13,
            color: active ? kTeal : kSage,
            fontWeight: active ? FontWeight.w600 : FontWeight.normal)),
      ]),
    );
  }
}
// Note: home_screen.dart _showConfirmModal fix is in home_screen patch below