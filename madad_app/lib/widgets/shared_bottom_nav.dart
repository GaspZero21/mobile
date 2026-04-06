import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../screens/home_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/add_donation_screen.dart';
import '../screens/notification_screen.dart';
import '../screens/chat_screen.dart';
import '../screens/my_reservations_screen.dart';
import '../services/notification_service.dart';
import '../services/app_token.dart';
 
/// 0=Home  1=Reservations  2=Add  3=Notifications  4=Profile
class SharedBottomNav extends StatefulWidget {
  final int currentIndex;
  const SharedBottomNav({super.key, required this.currentIndex});
 
  @override
  State<SharedBottomNav> createState() => _SharedBottomNavState();
}
 
class _SharedBottomNavState extends State<SharedBottomNav> {
  int _unread = 0;
 
  @override
  void initState() {
    super.initState();
    _loadUnread();
  }
 
  Future<void> _loadUnread() async {
    if (AppToken.get() == null) return;
    try {
      final res = await NotificationService().getNotifications(limit: 1);
      final data = res['data'] as Map<String, dynamic>?;
      final count = (data?['unreadCount'] as num?)?.toInt() ?? 0;
      if (mounted) setState(() => _unread = count);
    } catch (_) {}
  }
 
  void _onTap(BuildContext context, int index) {
    if (index == widget.currentIndex) return;
    switch (index) {
      case 0:
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (r) => false,
        );
        break;
      case 1:
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const MyReservationsScreen()),
          (r) => false,
        );
        break;
      case 2:
        Navigator.push<bool>(
          context,
          MaterialPageRoute(builder: (_) => const AddDonationScreen()),
        ).then((posted) {
          if (posted == true && context.mounted) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const HomeScreen()),
              (r) => false,
            );
          }
        });
        break;
      case 3:
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const NotificationScreen()),
          (r) => false,
        );
        break;
      case 4:
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const ProfileScreen()),
          (r) => false,
        );
        break;
    }
  }
 
  @override
  Widget build(BuildContext context) {
    const double circleRadius = 36.0;
    const double notchMargin = 16.0;
 
    return SizedBox(
      height: 100,
      child: LayoutBuilder(builder: (context, constraints) {
        final double screenWidth = constraints.maxWidth;
        final double itemWidth = screenWidth / 5;
        final double rawCircleX =
            itemWidth * widget.currentIndex + itemWidth / 2;
        final double circleX = rawCircleX.clamp(
          circleRadius + notchMargin + 4,
          screenWidth - circleRadius - notchMargin - 4,
        );
 
        return Stack(clipBehavior: Clip.none, children: [
          // ── Gradient bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: ClipPath(
              clipper: _NavBarClipper(activeIndex: widget.currentIndex),
              child: Container(
                height: 73,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [Color(0xFF8FB0A1), Color(0xFF0F5C5C)],
                    stops: [0.025, 0.661],
                  ),
                ),
                child: Row(
                  children: List.generate(5, (i) {
                    final bool active = widget.currentIndex == i;
                    return SizedBox(
                      width: itemWidth,
                      height: 73,
                      child: active
                          ? const SizedBox()
                          : GestureDetector(
                              onTap: () => _onTap(context, i),
                              child: Center(child: _iconFor(i, false)),
                            ),
                    );
                  }),
                ),
              ),
            ),
          ),
 
          // ── Notch background
          Positioned(
            bottom: 0,
            left: circleX - 40,
            child: Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(color: kSand, shape: BoxShape.circle),
            ),
          ),
 
          // ── Active circle
          Positioned(
            bottom: 8,
            left: circleX - 32,
            child: GestureDetector(
              onTap: () => _onTap(context, widget.currentIndex),
              child: Container(
                width: 64,
                height: 64,
                decoration:
                    const BoxDecoration(color: kTeal, shape: BoxShape.circle),
                child: Center(child: _iconFor(widget.currentIndex, true)),
              ),
            ),
          ),
        ]);
      }),
    );
  }
 
  Widget _iconFor(int index, bool active) {
    const Color c = kWhite;
    const double sz = 26;
 
    Widget icon;
    switch (index) {
      case 0:
        icon = const Icon(Icons.home, color: c, size: sz);
        break;
      case 1:
        // Reservations bookmark icon
        icon = const Icon(Icons.bookmark_outline, color: c, size: sz);
        break;
      case 2:
        icon = Icon(active ? Icons.add : Icons.add, color: c, size: sz + 4);
        break;
      case 3:
        // Notification bell with badge
        icon = Stack(clipBehavior: Clip.none, children: [
          const Icon(Icons.notifications_outlined, color: c, size: sz),
          if (_unread > 0)
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                width: 16,
                height: 16,
                decoration: const BoxDecoration(
                    color: kTerra, shape: BoxShape.circle),
                child: Center(
                  child: Text(
                    _unread > 9 ? '9+' : '$_unread',
                    style: const TextStyle(
                        color: kWhite,
                        fontSize: 8,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
        ]);
        break;
      case 4:
        icon = const Icon(Icons.person, color: c, size: sz);
        break;
      default:
        icon = const SizedBox();
    }
    return icon;
  }
}
 
class _NavBarClipper extends CustomClipper<ui.Path> {
  final int activeIndex;
  const _NavBarClipper({required this.activeIndex});
 
  @override
  ui.Path getClip(Size size) {
    final path = ui.Path();
    const double cr = 36.0;
    const double nm = 16.0;
    final double iw = size.width / 5;
    final double rcx = iw * activeIndex + iw / 2;
    final double cx = rcx.clamp(cr + nm + 4, size.width - cr - nm - 4);
 
    path.moveTo(0, size.height);
    path.lineTo(size.width, size.height);
    path.lineTo(size.width, 0);
    path.lineTo(cx + cr + nm, 0);
    path.cubicTo(cx + cr + nm, 0, cx + cr, 0, cx + cr, cr);
    path.arcToPoint(Offset(cx - cr, cr),
        radius: const Radius.circular(36), clockwise: false);
    path.cubicTo(cx - cr, 0, cx - cr - nm, 0, cx - cr - nm, 0);
    path.lineTo(0, 0);
    path.close();
    return path;
  }
 
  @override
  bool shouldReclip(_NavBarClipper old) => old.activeIndex != activeIndex;
}