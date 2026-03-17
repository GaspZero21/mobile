import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';
import 'theme/colors.dart';

void main() {
  runApp(const MadadApp());
}

class MadadApp extends StatelessWidget {
  const MadadApp({super.key});

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