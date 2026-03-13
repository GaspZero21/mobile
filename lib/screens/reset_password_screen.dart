import 'package:flutter/material.dart';
import '../theme/colors.dart';
import 'login_screen.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _passwordController    = TextEditingController();
  final _confirmPassController = TextEditingController();
  bool _passwordVisible        = false;
  bool _confirmPassVisible     = false;

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
              'Reset Password',
              style: TextStyle(
                fontSize: 28, fontWeight: FontWeight.bold, color: kTeal),
            ),
            const SizedBox(height: 8),
            const Text(
              'Set the new password for your account.',
              style: TextStyle(fontSize: 14, color: kSage),
            ),
            const SizedBox(height: 32),

            // ── NEW PASSWORD
            TextField(
              controller: _passwordController,
              obscureText: !_passwordVisible,
              decoration: InputDecoration(
                labelText: 'Password',
                labelStyle: const TextStyle(color: kSage),
                prefixIcon: const Icon(Icons.lock_outline, color: kSage),
                suffixIcon: IconButton(
                  icon: Icon(
                    _passwordVisible ? Icons.visibility : Icons.visibility_off,
                    color: kSage,
                  ),
                  onPressed: () =>
                      setState(() => _passwordVisible = !_passwordVisible),
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

            const SizedBox(height: 16),

            // ── CONFIRM PASSWORD
            TextField(
              controller: _confirmPassController,
              obscureText: !_confirmPassVisible,
              decoration: InputDecoration(
                labelText: 'Confirm Your Password',
                labelStyle: const TextStyle(color: kSage),
                prefixIcon: const Icon(Icons.lock_outline, color: kSage),
                suffixIcon: IconButton(
                  icon: Icon(
                    _confirmPassVisible
                        ? Icons.visibility
                        : Icons.visibility_off,
                    color: kSage,
                  ),
                  onPressed: () => setState(
                      () => _confirmPassVisible = !_confirmPassVisible),
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

            const SizedBox(height: 32),

            // ── CONTINUE BUTTON
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
                onPressed: _onReset,
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

  void _onReset() {
    // Show success dialog
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: kTeal, size: 64),
            const SizedBox(height: 16),
            const Text(
              'Your Password Has Been Reset Successfully!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: kTeal),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: kTeal),
              onPressed: () => Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false, // clears all previous screens
              ),
              child: const Text('Back to Login',
                  style: TextStyle(color: kWhite)),
            ),
          ],
        ),
      ),
    );
  }
}