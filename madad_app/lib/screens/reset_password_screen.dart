import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../services/auth_service.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String token; // token passed from email or OTP

  const ResetPasswordScreen({super.key, required this.token});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _passwordController = TextEditingController();
  final _confirmPassController = TextEditingController();
  bool _passwordVisible = false;
  bool _confirmPassVisible = false;
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        decoration: const BoxDecoration(
          color: kWhite,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // drag handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: kSage,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              const SizedBox(height: 20),

              const Text(
                'Reset Password',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: kTeal,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'Set The New Password For Your Account',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: kSage),
              ),

              const SizedBox(height: 24),

              // Password field
              TextField(
                controller: _passwordController,
                obscureText: !_passwordVisible,
                decoration: InputDecoration(
                  labelText: 'Password',
                  labelStyle: const TextStyle(color: kSage, fontSize: 14),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _passwordVisible ? Icons.visibility : Icons.lock_outline,
                      color: kSage,
                      size: 20,
                    ),
                    onPressed: () =>
                        setState(() => _passwordVisible = !_passwordVisible),
                  ),
                  enabledBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: kSage),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: kTeal, width: 1.5),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Confirm password field
              TextField(
                controller: _confirmPassController,
                obscureText: !_confirmPassVisible,
                decoration: InputDecoration(
                  labelText: 'Confirm Your Password',
                  labelStyle: const TextStyle(color: kSage, fontSize: 14),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _confirmPassVisible
                          ? Icons.visibility
                          : Icons.lock_outline,
                      color: kSage,
                      size: 20,
                    ),
                    onPressed: () => setState(
                      () => _confirmPassVisible = !_confirmPassVisible,
                    ),
                  ),
                  enabledBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: kSage),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: kTeal, width: 1.5),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // Continue button
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
                  onPressed: _loading ? null : _onContinue,
                  child: _loading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Continue',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: kWhite,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onContinue() async {
    final password = _passwordController.text.trim();
    final confirm = _confirmPassController.text.trim();

    if (password.isEmpty || confirm.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill in all fields")),
      );
      return;
    }

    if (password != confirm) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Passwords do not match")));
      return;
    }

    setState(() => _loading = true);

    try {
      final response = await AuthService().resetPassword(
        token: widget.token,
        password: password,
      );

      debugPrint(response.toString());

      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _buildSuccessSheet(
          message: 'Your Password Has Been Reset\nSuccessfully!',
          onDone: () {
            Navigator.popUntil(context, (route) => route.isFirst);
          },
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Reset failed: $e")));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildSuccessSheet({
    required String message,
    required VoidCallback onDone,
  }) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        decoration: const BoxDecoration(
          color: kWhite,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: kSage,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 30),
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: Color(0xFF2AE523),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, color: kWhite, size: 45),
            ),
            const SizedBox(height: 24),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: kTeal,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
