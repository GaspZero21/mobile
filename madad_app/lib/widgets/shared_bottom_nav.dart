import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../screens/home_screen.dart';
import '../screens/profile_screen.dart';

/// Shared bottom navigation bar used across all screens.
/// Pass [currentIndex] to highlight the active tab.
/// 0 = Home, 1 = Search, 2 = Add, 3 = Chat, 4 = Profile
class SharedBottomNav extends StatelessWidget {
  final int currentIndex;

  const SharedBottomNav({super.key, required this.currentIndex});

  static const List<Map<String, dynamic>> _navItems = [
    {'icon': Icons.home,  'asset': null},
    {'icon': null, 'asset': 'assets/images/nav_search.png'},
    {'icon': null, 'asset': 'assets/images/nav_add.png'},
    {'icon': null, 'asset': 'assets/images/nav_chat.png'},
    {'icon': Icons.person, 'asset': null},
  ];

  void _onTap(BuildContext context, int index) {
    if (index == currentIndex) return;
    switch (index) {
      case 0:
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
        break;
      case 4:
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const ProfileScreen()),
          (route) => false,
        );
        break;
      // Add cases for Search (1), Add (2), Chat (3) when those screens exist
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    const double circleRadius = 36.0;
    const double notchMargin  = 16.0;

    return SizedBox(
      height: 100,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double screenWidth = constraints.maxWidth;
          final double itemWidth   = screenWidth / 5;
          final double rawCircleX  = itemWidth * currentIndex + itemWidth / 2;
          final double circleX     = rawCircleX.clamp(
            circleRadius + notchMargin + 4,
            screenWidth - circleRadius - notchMargin - 4,
          );

          return Stack(
            clipBehavior: Clip.none,
            children: [

              // ── GRADIENT BAR ──────────────────────────────────────────
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: ClipPath(
                  clipper: _NavBarClipper(activeIndex: currentIndex),
                  child: Container(
                    height: 73,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Color(0xFF8FB0A1),
                          Color(0xFF0F5C5C),
                        ],
                        stops: [0.025, 0.661],
                      ),
                    ),
                    child: Row(
                      children: List.generate(5, (i) {
                        final bool active = currentIndex == i;
                        return SizedBox(
                          width: itemWidth,
                          height: 73,
                          child: active
                              ? const SizedBox()
                              : GestureDetector(
                                  onTap: () => _onTap(context, i),
                                  child: Center(
                                    child: _navItems[i]['icon'] != null
                                        ? Icon(
                                            _navItems[i]['icon'] as IconData,
                                            color: kWhite,
                                            size: 26,
                                          )
                                        : Image.asset(
                                            _navItems[i]['asset'] as String,
                                            width: 26,
                                            height: 26,
                                            color: kWhite,
                                          ),
                                  ),
                                ),
                        );
                      }),
                    ),
                  ),
                ),
              ),

              // ── WHITE NOTCH ───────────────────────────────────────────
              Positioned(
                bottom: 0,
                left: circleX - 40,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: const BoxDecoration(
                    color: kSand,
                    shape: BoxShape.circle,
                  ),
                ),
              ),

              // ── TEAL ACTIVE CIRCLE ────────────────────────────────────
              Positioned(
                bottom: 8,
                left: circleX - 32,
                child: GestureDetector(
                  onTap: () => _onTap(context, currentIndex),
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(
                      color: kTeal,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: _navItems[currentIndex]['icon'] != null
                          ? Icon(
                              _navItems[currentIndex]['icon'] as IconData,
                              color: kWhite,
                              size: 30,
                            )
                          : Image.asset(
                              _navItems[currentIndex]['asset'] as String,
                              width: 30,
                              height: 30,
                              color: kWhite,
                            ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── CLIPPER ──────────────────────────────────────────────────────────────────
class _NavBarClipper extends CustomClipper<ui.Path> {
  final int activeIndex;
  const _NavBarClipper({required this.activeIndex});

  @override
  ui.Path getClip(Size size) {
    final path         = ui.Path();
    const double circleRadius = 36.0;
    const double notchMargin  = 16.0;
    final double itemWidth    = size.width / 5;
    final double rawCircleX   = itemWidth * activeIndex + itemWidth / 2;
    final double circleX      = rawCircleX.clamp(
      circleRadius + notchMargin + 4,
      size.width - circleRadius - notchMargin - 4,
    );

    path.moveTo(0, size.height);
    path.lineTo(size.width, size.height);
    path.lineTo(size.width, 0);

    path.lineTo(circleX + circleRadius + notchMargin, 0);
    path.cubicTo(
      circleX + circleRadius + notchMargin, 0,
      circleX + circleRadius, 0,
      circleX + circleRadius, circleRadius,
    );
    path.arcToPoint(
      Offset(circleX - circleRadius, circleRadius),
      radius: const Radius.circular(circleRadius),
      clockwise: false,
    );
    path.cubicTo(
      circleX - circleRadius, 0,
      circleX - circleRadius - notchMargin, 0,
      circleX - circleRadius - notchMargin, 0,
    );

    path.lineTo(0, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(_NavBarClipper old) => old.activeIndex != activeIndex;
}
