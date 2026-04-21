import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';
import 'theme/colors.dart';
import 'package:app_links/app_links.dart';
import 'dart:async';
import 'services/app_token.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppToken.init();
  runApp(const MadadApp());
}

class MadadApp extends StatefulWidget {
  const MadadApp({super.key});

  @override
  State<MadadApp> createState() => _MadadAppState();
}

class _MadadAppState extends State<MadadApp> {
  final _appLinks = AppLinks();
  StreamSubscription? _linkSub;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  Future<void> _initDeepLinks() async {
    final initialLink = await _appLinks.getInitialLink();
    if (initialLink != null) _handleLink(initialLink);
    _linkSub = _appLinks.uriLinkStream.listen(_handleLink);
  }

  void _handleLink(Uri uri) => debugPrint('Deep link: $uri');

  @override
  void dispose() {
    _linkSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Madad',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: kTeal,
        scaffoldBackgroundColor: kSand,
        fontFamily: 'Poppins',
      ),
      home: AppToken.isLoggedIn() ? const HomeScreen() : const SplashScreen(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MadadLogo — uses the real asset logo_full.png
//
// Usage:
//   MadadLogo(height: 40)                     → logo image only
//   MadadLogo(height: 40, color: Colors.white) → with white tint overlay
// ─────────────────────────────────────────────────────────────────────────────
class MadadLogo extends StatelessWidget {
  final double height;
  final Color? color;

  const MadadLogo({
    super.key,
    this.height = 40,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Image.asset(
          'assets/images/logo_full.png',
          height: height,
          fit: BoxFit.contain,
          color: color,
          colorBlendMode: color != null ? BlendMode.srcIn : null,
          errorBuilder: (_, __, ___) => _fallbackIcon(),
        ),
        SizedBox(width: height * 0.3),
        Text(
          'Madad',
          style: TextStyle(
            fontSize: height * 0.55,
            fontWeight: FontWeight.w700,
            color: color ?? kTeal,
            letterSpacing: 2,
            fontFamily: 'Poppins',
          ),
        ),
      ],
    );
  }

  // Fallback if asset is missing — renders text-only
  Widget _fallbackIcon() {
    return Text(
      'M',
      style: TextStyle(
        fontSize: height * 0.8,
        fontWeight: FontWeight.w700,
        color: color ?? kTeal,
        fontFamily: 'Poppins',
      ),
    );
  }
}