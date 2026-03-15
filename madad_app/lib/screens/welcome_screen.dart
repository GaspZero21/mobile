import 'package:flutter/material.dart';
import '../theme/colors.dart';
import 'register_screen.dart';
import 'login_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: kSand,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 60),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Welcome To Madad !',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: kTeal,
              ),
            ),
          ),

          const SizedBox(height: 6),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Start Your Helping Journey',
              style: TextStyle(
                fontSize: 15,
                color: kTerra,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          const Spacer(),

          SizedBox(
            height: size.height * 0.65,
            child: Stack(
              children: [
                // ── 1. ILLUSTRATION (bottom layer)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  bottom: size.height * 0.18,
                  child: Image.asset(
                    'assets/images/welcome_illustration.png',
                    fit: BoxFit.contain,
                    alignment: Alignment.bottomCenter,
                    color: kSand,
                    colorBlendMode: BlendMode.multiply,
                  ),
                ),

                // ── 2. DIAGONAL TEAL SHAPE
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  height: size.height * 0.30,
                  child: ClipPath(
                    clipper: _DiagonalClipper(),
                    child: Container(color: kTeal),
                  ),
                ),

                // ── 3. BOTTOM SHEET
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 36),
                    decoration: const BoxDecoration(
                      color: kSand,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(30),
                        topRight: Radius.circular(30),
                      ),
                    ),
                    child: _buildRoleButtons(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RegisterScreen()),
            ),
            child: const Center(
              child: Text(
                'Donor / Beneficiary',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: kTeal,
                ),
              ),
            ),
          ),
        ),
        Container(width: 1, height: 30, color: kSage),
        Expanded(
          child: GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
            ),
            child: const Center(
              child: Text(
                'Asossiation',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: kTeal,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DiagonalClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width, size.height * 0.20);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(_DiagonalClipper oldClipper) => false;
}
