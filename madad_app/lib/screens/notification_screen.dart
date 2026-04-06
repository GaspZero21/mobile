import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../services/notification_service.dart';
import '../widgets/shared_bottom_nav.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  List<Map<String, dynamic>> _notifications = [];
  int  _unreadCount = 0;
  bool _isLoading   = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final res  = await NotificationService().getNotifications();
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

  IconData _iconFor(String? type) {
    switch (type) {
      case 'RESERVATION_REQUESTED': return Icons.bookmark_add_outlined;
      case 'RESERVATION_ACCEPTED':  return Icons.check_circle_outline;
      case 'RESERVATION_CANCELLED': return Icons.cancel_outlined;
      case 'DONATION_COMPLETED':    return Icons.volunteer_activism;
      case 'NEW_MESSAGE':           return Icons.chat_bubble_outline;
      default:                      return Icons.notifications_outlined;
    }
  }

  Color _colorFor(String? type) {
    switch (type) {
      case 'RESERVATION_REQUESTED': return kTerra;
      case 'RESERVATION_ACCEPTED':  return Colors.green;
      case 'RESERVATION_CANCELLED': return Colors.redAccent;
      case 'DONATION_COMPLETED':    return kTeal;
      default:                      return kSage;
    }
  }

  String _timeAgo(String? iso) {
    if (iso == null) return '';
    final dt   = DateTime.tryParse(iso);
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1)  return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours   < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSand,
      body: Column(
        children: [
          // ── Header
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

          // ── Body
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: kTeal))
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.wifi_off, color: kSage, size: 36),
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
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
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
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              itemCount: _notifications.length,
                              separatorBuilder: (_, __) => const Divider(
                                  height: 1, indent: 72, color: Color(0xFFE0E0E0)),
                              itemBuilder: (_, i) =>
                                  _buildItem(_notifications[i]),
                            ),
                          ),
          ),
        ],
      ),
      bottomNavigationBar: const SharedBottomNav(currentIndex: 1),
    );
  }

  Widget _buildItem(Map<String, dynamic> n) {
    final bool   isRead = n['isRead'] == true;
    final String? type  = n['type'] as String?;

    return InkWell(
      onTap: () => _markRead(n),
      child: Container(
        color: isRead ? Colors.transparent : kTeal.withOpacity(0.05),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon bubble
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: _colorFor(type).withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(_iconFor(type), color: _colorFor(type), size: 22),
            ),
            const SizedBox(width: 12),

            // Text
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