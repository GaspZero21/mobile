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
      debugShowCheckedModeBanner: false,  // removes debug banner
      theme: ThemeData(
        primaryColor: kTeal,
        scaffoldBackgroundColor: kSand,
        fontFamily: 'Poppins',           // we will add this font later
      ),
      home: const SplashScreen(),        // first screen to show
    );
  }
}