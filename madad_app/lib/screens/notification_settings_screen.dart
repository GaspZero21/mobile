import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/colors.dart';
import '../services/push_notification_service.dart';
import '../services/notification_service.dart'; // ← THIS was missing

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  bool _reservationRequested = true;
  bool _reservationAccepted  = true;
  bool _reservationCancelled = true;
  bool _donationCompleted    = true;
  bool _newMessages          = true;
  bool _pushEnabled          = true;
  bool _loading = true;

  static const _kReservationRequested = 'notif_reservation_requested';
  static const _kReservationAccepted  = 'notif_reservation_accepted';
  static const _kReservationCancelled = 'notif_reservation_cancelled';
  static const _kDonationCompleted    = 'notif_donation_completed';
  static const _kNewMessages          = 'notif_new_messages';
  static const _kPushEnabled          = 'notif_push_enabled';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _reservationRequested = prefs.getBool(_kReservationRequested) ?? true;
      _reservationAccepted  = prefs.getBool(_kReservationAccepted)  ?? true;
      _reservationCancelled = prefs.getBool(_kReservationCancelled) ?? true;
      _donationCompleted    = prefs.getBool(_kDonationCompleted)    ?? true;
      _newMessages          = prefs.getBool(_kNewMessages)          ?? true;
      _pushEnabled          = prefs.getBool(_kPushEnabled)          ?? true;
      _loading = false;
    });
  }

  Future<void> _saveSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);

    try {
      await NotificationService().updatePreferences(
        reservationRequested: _reservationRequested,
        reservationAccepted:  _reservationAccepted,
        reservationCancelled: _reservationCancelled,
        donationCompleted:    _donationCompleted,
        newMessages:          _newMessages,
      );
    } catch (e) {
      debugPrint('[Notif] Failed to sync preferences: $e');
    }
  }

  Future<void> _togglePush(bool value) async {
    setState(() => _pushEnabled = value);
    await _saveSetting(_kPushEnabled, value);
    if (value) {
      await PushNotificationService.init();
    } else {
      await PushNotificationService.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSand,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kTeal))
          : CustomScrollView(
              slivers: [
                _buildAppBar(),
                SliverToBoxAdapter(child: _buildBody()),
              ],
            ),
    );
  }

  SliverAppBar _buildAppBar() {
    return SliverAppBar(
      pinned: true,
      expandedHeight: 120,
      backgroundColor: kTeal,
      iconTheme: const IconThemeData(color: kWhite),
      flexibleSpace: FlexibleSpaceBar(
        title: const Text(
          'Notification Settings',
          style: TextStyle(
            color: kWhite,
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0A4040), kTeal],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMasterSwitch(),
          const SizedBox(height: 20),
          AnimatedOpacity(
            opacity: _pushEnabled ? 1.0 : 0.4,
            duration: const Duration(milliseconds: 250),
            child: AbsorbPointer(
              absorbing: !_pushEnabled,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionLabel('RESERVATIONS'),
                  _buildCard([
                    _buildTile(
                      icon: Icons.bookmark_add_outlined,
                      iconColor: kTerra,
                      title: 'New reservation request',
                      subtitle: 'When someone reserves your donation',
                      value: _reservationRequested,
                      onChanged: (v) {
                        setState(() => _reservationRequested = v);
                        _saveSetting(_kReservationRequested, v);
                      },
                    ),
                    _divider(),
                    _buildTile(
                      icon: Icons.check_circle_outline,
                      iconColor: Colors.green,
                      title: 'Reservation accepted',
                      subtitle: 'When a donor confirms your reservation',
                      value: _reservationAccepted,
                      onChanged: (v) {
                        setState(() => _reservationAccepted = v);
                        _saveSetting(_kReservationAccepted, v);
                      },
                    ),
                    _divider(),
                    _buildTile(
                      icon: Icons.cancel_outlined,
                      iconColor: Colors.red,
                      title: 'Reservation cancelled',
                      subtitle: 'When a reservation is cancelled',
                      value: _reservationCancelled,
                      onChanged: (v) {
                        setState(() => _reservationCancelled = v);
                        _saveSetting(_kReservationCancelled, v);
                      },
                    ),
                  ]),
                  const SizedBox(height: 20),
                  _sectionLabel('DONATIONS'),
                  _buildCard([
                    _buildTile(
                      icon: Icons.volunteer_activism_outlined,
                      iconColor: kTeal,
                      title: 'Donation completed',
                      subtitle: 'When a donation is marked as completed',
                      value: _donationCompleted,
                      onChanged: (v) {
                        setState(() => _donationCompleted = v);
                        _saveSetting(_kDonationCompleted, v);
                      },
                    ),
                  ]),
                  const SizedBox(height: 20),
                  _sectionLabel('MESSAGES'),
                  _buildCard([
                    _buildTile(
                      icon: Icons.chat_bubble_outline,
                      iconColor: kSage,
                      title: 'New messages',
                      subtitle: 'When you receive a chat message',
                      value: _newMessages,
                      onChanged: (v) {
                        setState(() => _newMessages = v);
                        _saveSetting(_kNewMessages, v);
                      },
                    ),
                  ]),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildMasterSwitch() {
    return Container(
      decoration: BoxDecoration(
        color: kTeal,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Row(
        children: [
          const Icon(Icons.notifications_outlined, color: kWhite, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Push Notifications',
                  style: TextStyle(
                    color: kWhite,
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Enable or disable all notifications',
                  style: TextStyle(
                    color: Color(0xAAFFFFFF),
                    fontFamily: 'Poppins',
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _pushEnabled,
            onChanged: _togglePush,
            activeColor: kWhite,
            activeTrackColor: const Color(0x66FFFFFF),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    color: kSage,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: kTeal,
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: kSage,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _divider() =>
      const Divider(height: 1, indent: 70, color: Color(0xFFEEEEEE));
}



