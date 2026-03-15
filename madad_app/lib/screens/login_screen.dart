import 'package:flutter/material.dart';
import '../theme/colors.dart';
import 'forgot_password_screen.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController    = TextEditingController();
  final _passwordController = TextEditingController();
  bool _passwordVisible     = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSage,
      body: Column(
        children: [

          // ── TOP SECTION (sage background with title)
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 80, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Welcome Back !',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: kTeal,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── BOTTOM SHEET (white rounded)
          Expanded(
            flex: 6,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
              decoration: const BoxDecoration(
                color: kSand,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // ── EMAIL
                    TextField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'E-Mail Or Phone Number',
                        labelStyle: TextStyle(color: kSage, fontSize: 14),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: kSage),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: kTeal, width: 1.5),
                        ),
                        filled: false,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── PASSWORD
                    TextField(
                      controller: _passwordController,
                      obscureText: !_passwordVisible,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        labelStyle: const TextStyle(
                            color: kSage, fontSize: 14),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _passwordVisible
                                ? Icons.visibility
                                : Icons.lock_outline,
                            color: kSage, size: 20,
                          ),
                          onPressed: () => setState(
                              () => _passwordVisible = !_passwordVisible),
                        ),
                        enabledBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: kSage),
                        ),
                        focusedBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: kTeal, width: 1.5),
                        ),
                        filled: false,
                      ),
                    ),

                    const SizedBox(height: 36),

                    // ── SIGN IN BUTTON
                    Center(
                      child: SizedBox(
                        width: 200, height: 52,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kTeal,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          onPressed: _onSignIn,
                          child: const Text(
                            'Sign In',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: kWhite,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // ── FORGOT PASSWORD
                    Center(
                      child: GestureDetector(
                        onTap: _showForgotPassword,
                        child: const Text(
                          'Forgot Password?',
                          style: TextStyle(
                            color: kTerra,
                            decoration: TextDecoration.underline,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),

                    // ── HAND IMAGE
                    Center(
                      child: Image.asset(
                        'assets/images/logo_hand.png',
                        width: 200,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onSignIn() async {

  final email = _emailController.text.trim();
  final password = _passwordController.text.trim();

  if (email.isEmpty || password.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Please fill all fields")),
    );
    return;
  }

  try {

    final response = await AuthService().login(
      email: email,
      password: password,
    );

    debugPrint(response.toString());

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Login successful")),
    );

  } catch (e) {

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Login failed: $e")),
    );

  }
}

  void _showForgotPassword() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ForgotPasswordScreen(),
    );
  }
}