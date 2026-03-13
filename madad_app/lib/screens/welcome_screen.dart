import 'package:flutter/material.dart';
import '../theme/colors.dart';
import 'register_screen.dart';
import 'login_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _showSignUp = false;

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

                // ── 2. DIAGONAL TEAL SHAPE (on top of illustration)
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

                // ── 3. BOTTOM SHEET (on top of teal)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 36),
                    decoration: BoxDecoration(
                      color: _showSignUp ? kTeal : kSand,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(30),
                        topRight: Radius.circular(30),
                      ),
                    ),
                    child: _showSignUp
                        ? _buildSignUpButtons()
                        : _buildRoleButtons(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleButtons() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _showSignUp = true),
            child: const Center(
              child: Text(
                'Donor',
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
            onTap: () => setState(() => _showSignUp = true),
            child: const Center(
              child: Text(
                'Beneficiary',
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

  Widget _buildSignUpButtons() {
    return Column(
      children: [

        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kTerra,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RegisterScreen()),
            ),
            child: const Text(
              'Sign Up',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: kWhite,
              ),
            ),
          ),
        ),

        const SizedBox(height: 14),

        Wrap(
          alignment: WrapAlignment.center,
          children: [
            const Text(
              'Did You Have Already An Account ? ',
              style: TextStyle(fontSize: 13, color: kWhite),
            ),
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              ),
              child: const Text(
                'Sign In',
                style: TextStyle(
                  fontSize: 13,
                  color: kWhite,
                  decoration: TextDecoration.underline,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Text(
              ' Now',
              style: TextStyle(fontSize: 13, color: kWhite),
            ),
          ],
        ),

        const SizedBox(height: 8),
        const Text('Or', style: TextStyle(color: kWhite, fontSize: 13)),
        const SizedBox(height: 8),

        GestureDetector(
          onTap: () {},
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Continue As A Guest ',
                style: TextStyle(
                  color: kTerra,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              Icon(Icons.chevron_right, color: kTerra, size: 18),
            ],
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