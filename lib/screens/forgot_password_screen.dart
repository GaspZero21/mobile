import 'package:flutter/material.dart';
import '../theme/colors.dart';
import 'reset_password_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSand,
      appBar: AppBar(
        backgroundColor: kSand,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: kTeal),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            const Text(
              'Forgot Password',
              style: TextStyle(
                fontSize: 28, fontWeight: FontWeight.bold, color: kTeal),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please enter your email address to reset your password.',
              style: TextStyle(fontSize: 14, color: kSage, height: 1.5),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Your Email',
                labelStyle: const TextStyle(color: kSage),
                prefixIcon: const Icon(Icons.email_outlined, color: kSage),
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
            const SizedBox(height: 32),
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
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ResetPasswordScreen()),
                ),
                child: const Text(
                  'Continue',
                  style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold, color: kWhite),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}