import 'package:flutter/material.dart';
import '../theme/colors.dart';
import 'register_screen.dart';
import 'login_screen.dart';

class DonorAuthScreen extends StatelessWidget {
  const DonorAuthScreen({super.key});

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
            height: size.height * 0.68,
            child: Stack(
              children: [

                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  bottom: size.height * 0.25,
                  child: Image.asset(
                    'assets/images/welcome_illustration.png',
                    fit: BoxFit.contain,
                    alignment: Alignment.bottomCenter,
                    color: kSand,
                    colorBlendMode: BlendMode.multiply,
                  ),
                ),

                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  height: size.height * 0.35,
                  child: ClipPath(
                    clipper: _DiagonalClipper(),
                    child: Container(color: kTeal),
                  ),
                ),

                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
                    decoration: const BoxDecoration(
                      color: kTeal,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
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
                              MaterialPageRoute(
                                  builder: (_) => const RegisterScreen()),
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

                        const SizedBox(height: 16),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'Did You Have Already An Account ? ',
                              style: TextStyle(fontSize: 13, color: kWhite),
                            ),
                            GestureDetector(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const LoginScreen()),
                              ),
                              child: const Text(
                                'Sign In',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: kTerra,
                                  decoration: TextDecoration.underline,
                                  decorationColor: kTerra,
                                ),
                              ),
                            ),
                            const Text(
                              ' Now',
                              style: TextStyle(fontSize: 13, color: kWhite),
                            ),
                          ],
                        ),

                        const SizedBox(height: 10),

                        const Text(
                          'Or',
                          style: TextStyle(fontSize: 13, color: kWhite),
                        ),

                        const SizedBox(height: 10),

                        GestureDetector(
                          onTap: () {
                            // navigate to guest/home screen later
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Text(
                                'Continue As A Guest',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: kTerra,
                                ),
                              ),
                              SizedBox(width: 4),
                              Icon(
                                Icons.chevron_right,
                                color: kTerra,
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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