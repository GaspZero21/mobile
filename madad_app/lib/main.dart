import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';
import 'theme/colors.dart';
import 'package:app_links/app_links.dart';
import 'dart:async';

void main() {
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
    // App opened from a deep link (cold start)
    final initialLink = await _appLinks.getInitialLink();
    if (initialLink != null) {
      _handleLink(initialLink);
    }

    // App already running, new deep link received
    _linkSub = _appLinks.uriLinkStream.listen((uri) {
      _handleLink(uri);
    });
  }

  void _handleLink(Uri uri) {
    // Example: gaspzero://reset-password?token=abc123
    debugPrint('Deep link: $uri');

    // Add your navigation logic here
    // if (uri.host == 'reset-password') { ... }
  }

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
      home: const SplashScreen(),
    );
  }
}