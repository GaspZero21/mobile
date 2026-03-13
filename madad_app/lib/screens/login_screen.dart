import 'package:flutter/material.dart';
import '../theme/colors.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart'; // we will create this next

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
      backgroundColor: kSand,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              const SizedBox(height: 40),

              // ── LOGO
              Center(
                child: Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    color: kTeal,
                    borderRadius: BorderRadius.circular(40),
                  ),
                  child: const Icon(Icons.eco, color: kWhite, size: 40),
                ),
              ),

              const SizedBox(height: 32),

              // ── TITLE
              const Text(
                'Welcome Back !',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: kTeal,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'Sign in to continue',
                style: TextStyle(fontSize: 14, color: kSage),
              ),

              const SizedBox(height: 32),

              // ── EMAIL / PHONE
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'E-Mail Or Phone Number',
                  labelStyle: const TextStyle(color: kSage),
                  prefixIcon: const Icon(Icons.person_outline, color: kSage),
                  filled: true,
                  fillColor: kWhite,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: kTeal, width: 1.5),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ── PASSWORD
              TextField(
                controller: _passwordController,
                obscureText: !_passwordVisible,
                decoration: InputDecoration(
                  labelText: 'Password',
                  labelStyle: const TextStyle(color: kSage),
                  prefixIcon: const Icon(Icons.lock_outline, color: kSage),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _passwordVisible
                          ? Icons.visibility
                          : Icons.visibility_off,
                      color: kSage,
                    ),
                    onPressed: () => setState(
                        () => _passwordVisible = !_passwordVisible),
                  ),
                  filled: true,
                  fillColor: kWhite,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: kTeal, width: 1.5),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ── FORGOT PASSWORD
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ForgotPasswordScreen()),
                  ),
                  child: const Text(
                    'Forgot Password ?',
                    style: TextStyle(
                      color: kTerra,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // ── SIGN IN BUTTON
              SizedBox(
                width: double.infinity,
                height: 52,
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

              const SizedBox(height: 24),

              // ── DON'T HAVE ACCOUNT
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Don't have an account? ",
                    style: TextStyle(color: kSage),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const RegisterScreen()),
                    ),
                    child: const Text(
                      'Sign Up',
                      style: TextStyle(
                        color: kTerra,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

void _onSignIn() {
  debugPrint('Email: ${_emailController.text}');
  debugPrint('Password: ${_passwordController.text}');
}}