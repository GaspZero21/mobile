import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:app_links/app_links.dart';
import 'dart:async';

import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/my_reservations_screen.dart';
import 'screens/notification_screen.dart';
import 'theme/colors.dart';
import 'services/app_token.dart';
import 'services/push_notification_service.dart';
import 'firebase_options.dart';

// ── Background handler — MUST be a top-level function ─────────────────────
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  debugPrint('[Push] Background: ${message.notification?.title}');
}

// ── Global navigator key ───────────────────────────────────────────────────
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// ───────────────────────────────────────────────────────────────────────────
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppToken.init();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  runApp(const MadadApp());
}

// ───────────────────────────────────────────────────────────────────────────
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

    if (AppToken.isLoggedIn()) {
      if (!kIsWeb) {
        PushNotificationService.init();

        // Backup foreground listener
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          debugPrint('[Push] Foreground: ${message.notification?.title}');
        });
      }
      _setupNotificationTapHandling();
    }
  }

  // ── Notification tap routing ──────────────────────────────────────────────
  void _setupNotificationTapHandling() {
    // App killed + tapped notification
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) _routeFromNotification(message.data);
    });

    // App in background + tapped notification
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _routeFromNotification(message.data);
    });
  }

  void _routeFromNotification(Map<String, dynamic> data) {
    final type = data['type']?.toString() ?? '';
    final nav = navigatorKey.currentState;
    if (nav == null) return;

    // === Improved Metadata Handling ===
    final metadata = data['metadata'] is Map<String, dynamic>
        ? data['metadata'] as Map<String, dynamic>
        : <String, dynamic>{};

    final donationId = data['donationId'] ?? metadata['donationId'];
    final reservationId = data['reservationId'] ?? metadata['reservationId'];

    debugPrint('[Push] Routing - Type: $type | DonationID: $donationId | ReservationID: $reservationId');

    switch (type) {
      // Donation related → Home Screen
      case 'NEARBY_DONATION':
      case 'MATCHING_DONATION':
      case 'URGENT_DONATION':
      case 'COMMUNITY_ALERT':
      case 'INACTIVE_REMINDER':
      case 'DONATION_EXPIRED':
        nav.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (r) => false,
        );
        break;

      // Reservation related → My Reservations
      case 'NEW_MESSAGE':
      case 'RESERVATION_REQUESTED':
      case 'RESERVATION_CONFIRMED':
      case 'RESERVATION_CANCELLED':
      case 'RESERVATION_COMPLETED':
      case 'RESERVATION_EXPIRED':
        nav.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MyReservationsScreen()),
          (r) => false,
        );
        break;

      // Default → Notifications Screen
      default:
        nav.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const NotificationScreen()),
          (r) => false,
        );
    }
  }

  // ── Deep links ────────────────────────────────────────────────────────────
  Future<void> _initDeepLinks() async {
    try {
      final initialLink = await _appLinks.getInitialLink();
      if (initialLink != null) _handleLink(initialLink);

      _linkSub = _appLinks.uriLinkStream.listen(_handleLink);
    } catch (e) {
      debugPrint('[DeepLink] Error: $e');
    }
  }

  void _handleLink(Uri uri) => debugPrint('[DeepLink] $uri');

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
      navigatorKey: navigatorKey,
      theme: ThemeData(
        primaryColor: kTeal,
        scaffoldBackgroundColor: kSand,
        fontFamily: 'Poppins',
      ),
      routes: {
        '/home': (_) => const HomeScreen(),
        '/reservations': (_) => const MyReservationsScreen(),
        '/notifications': (_) => const NotificationScreen(),
      },
      home: AppToken.isLoggedIn()
          ? const HomeScreen()
          : const SplashScreen(),
    );
  }
}

// ── Madad Logo Widget ──────────────────────────────────────────────────────
class MadadLogo extends StatelessWidget {
  final double height;
  final Color color;

  const MadadLogo({super.key, required this.height, required this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      'Madad',
      style: TextStyle(
        fontSize: height * 0.45,
        fontWeight: FontWeight.bold,
        color: color,
        fontFamily: 'Poppins',
        letterSpacing: 1.2,
      ),
    );
  }
}