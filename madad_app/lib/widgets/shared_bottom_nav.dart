import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../screens/home_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/add_donation_screen.dart';
import '../screens/notification_screen.dart';
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
    // Use SafeArea padding so the bar sits above system nav buttons
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    const double barHeight = 52.0;
    const double circleSize = 40.0;
    // How far the circle protrudes above the bar top
    const double circleProtrude = 10.0;
    final double totalHeight = barHeight + circleProtrude + bottomPadding;

    return SizedBox(
      height: totalHeight,
      child: LayoutBuilder(builder: (context, constraints) {
        final double screenWidth = constraints.maxWidth;
        final double itemWidth = screenWidth / 5;

        final double circleX =
            (itemWidth * widget.currentIndex + itemWidth / 2)
                .clamp(circleSize / 2 + 4, screenWidth - circleSize / 2 - 4);

        // Circle center Y from top of the SizedBox
        final double circleCenterY = circleProtrude;
        // Circle top from top of SizedBox
        final double circleTop = circleCenterY - circleSize / 2;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            // ── Gradient bar with notch (sits at the bottom)
            Positioned(
              bottom: bottomPadding,
              left: 0,
              right: 0,
              child: ClipPath(
                clipper: _NavBarClipper(
                  activeIndex: widget.currentIndex,
                  screenWidth: screenWidth,
                  circleRadius: circleSize / 2,
                  circleProtrude: circleProtrude,
                ),
                child: Container(
                  height: barHeight,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [Color(0xFF8FB0A1), Color(0xFF0F5C5C)],
                    ),
                  ),
                ),
              ),
            ),

            // ── Tap zones for inactive items (cover the visible bar area)
            Positioned(
              bottom: bottomPadding,
              left: 0,
              right: 0,
              child: SizedBox(
                height: barHeight,
                child: Row(
                  children: List.generate(5, (i) {
                    final bool active = widget.currentIndex == i;
                    return Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _onTap(context, i),
                        child: Center(
                          child: active
                              ? const SizedBox()
                              : Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: _iconFor(i, false),
                                ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),

            // ── White/sand ring behind the active circle (fills the notch gap)
            Positioned(
              top: circleTop - 3,
              left: circleX - circleSize / 2 - 3,
              child: Container(
                width: circleSize + 6,
                height: circleSize + 6,
                decoration: BoxDecoration(
                  // Match the scaffold/page background color
                  color: kSand,
                  shape: BoxShape.circle,
                ),
              ),
            ),

            // ── Active teal circle (floats above the bar)
            Positioned(
              top: circleTop,
              left: circleX - circleSize / 2,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _onTap(context, widget.currentIndex),
                child: Container(
                  width: circleSize,
                  height: circleSize,
                  decoration: BoxDecoration(
                    color: kTeal,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: kTeal.withOpacity(0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(child: _iconFor(widget.currentIndex, true)),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _iconFor(int index, bool active) {
    const Color c = kWhite;
    const double sz = 22;

    switch (index) {
      case 0:
        return Icon(active ? Icons.home : Icons.home_outlined, color: c, size: sz);
      case 1:
        return Icon(active ? Icons.bookmark : Icons.bookmark_border, color: c, size: sz);
      case 2:
        return Icon(Icons.add_circle_outline, color: c, size: sz + 2);
      case 3:
        return Stack(clipBehavior: Clip.none, children: [
          Icon(
            active ? Icons.notifications : Icons.notifications_outlined,
            color: c,
            size: sz,
          ),
          if (_unread > 0)
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                width: 14,
                height: 14,
                decoration:
                    const BoxDecoration(color: kTerra, shape: BoxShape.circle),
                child: Center(
                  child: Text(
                    _unread > 9 ? '9+' : '$_unread',
                    style: const TextStyle(
                        color: kWhite, fontSize: 7, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
        ]);
      case 4:
        return Icon(active ? Icons.person : Icons.person_outline, color: c, size: sz);
      default:
        return const SizedBox();
    }
  }
}

// ── Clipper: draws the bar shape with a smooth circular notch at the top ──────
class _NavBarClipper extends CustomClipper<ui.Path> {
  final int activeIndex;
  final double screenWidth;
  final double circleRadius;
  final double circleProtrude; // how much the circle sticks above bar top

  const _NavBarClipper({
    required this.activeIndex,
    required this.screenWidth,
    required this.circleRadius,
    required this.circleProtrude,
  });

  @override
  ui.Path getClip(Size size) {
    // Center X of the notch
    final double iw = size.width / 5;
    final double cx = (iw * activeIndex + iw / 2)
        .clamp(circleRadius + 10, size.width - circleRadius - 10);

    // The notch dips DOWN from the top of the bar
    final double notchDepth = circleProtrude + 4; // a bit deeper than protrusion
    final double notchHalf = circleRadius + 6;    // half-width of the gap
    const double shoulder = 16.0;                 // bezier curve width

    final path = ui.Path();

    // Start at top-left
    path.moveTo(0, 0);

    // ── Left side of bar top → left shoulder of notch
    path.lineTo(cx - notchHalf - shoulder, 0);

    // ── Smooth curve DOWN into the notch (left side)
    path.cubicTo(
      cx - notchHalf - shoulder + shoulder * 0.7, 0,   // cp1
      cx - notchHalf, notchDepth,                       // cp2
      cx - notchHalf, notchDepth,                       // end
    );

    // ── Arc across the bottom of the notch
    path.arcToPoint(
      Offset(cx + notchHalf, notchDepth),
      radius: Radius.circular(notchHalf),
      clockwise: false,   // false = arc goes downward (away from bar top)
    );

    // ── Smooth curve back UP to bar top (right side)
    path.cubicTo(
      cx + notchHalf, notchDepth,                         // cp1
      cx + notchHalf + shoulder - shoulder * 0.7, 0,      // cp2
      cx + notchHalf + shoulder, 0,                        // end
    );

    // ── Right side of bar top → top-right corner
    path.lineTo(size.width, 0);

    // ── Down the right side → bottom-right → bottom-left → close
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(_NavBarClipper old) =>
      old.activeIndex != activeIndex || old.screenWidth != screenWidth;
}