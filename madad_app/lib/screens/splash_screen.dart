import 'package:flutter/material.dart';
import '../theme/colors.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return; // safety check
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSand,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120, height: 120,
              decoration: BoxDecoration(
                color: kTeal,
                borderRadius: BorderRadius.circular(60),
              ),
              child: const Icon(Icons.eco, color: kWhite, size: 60),
            ),
            const SizedBox(height: 24),
            const Text(
              'Madad',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: kTeal,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Start Your Helping Journey',
              style: TextStyle(fontSize: 14, color: kSage),
            ),
          ],
        ),
      ),
    );
  }
}