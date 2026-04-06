import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../services/auth_service.dart';
import 'reset_password_screen.dart';
import 'home_screen.dart';

/// [mode] controls what happens when the user taps Verify:
///   - 'verify_email'  → calls POST /auth/verify-email, then goes to HomeScreen
///   - 'reset_password' → goes to ResetPasswordScreen (existing flow)
class OtpScreen extends StatefulWidget {
  final String email;
  final String mode; // 'verify_email' | 'reset_password'

  const OtpScreen({
    super.key,
    required this.email,
    this.mode = 'reset_password',
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes =
      List.generate(6, (_) => FocusNode());

  int  _secondsLeft = 30;
  Timer? _timer;
  bool _canResend = false;
  bool _hasError  = false;
  bool _loading   = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    setState(() { _secondsLeft = 30; _canResend = false; });
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft == 0) {
        t.cancel();
        setState(() => _canResend = true);
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  Future<void> _resend() async {
    for (final c in _controllers) c.clear();
    _focusNodes[0].requestFocus();
    setState(() => _hasError = false);

    try {
      if (widget.mode == 'verify_email') {
        await AuthService().resendVerification(widget.email);
      } else {
        await AuthService().forgotPassword(widget.email);
      }
    } catch (_) {}
    _startTimer();
  }

  @override
  void dispose() {
    for (final c in _controllers) c.dispose();
    for (final f in _focusNodes)   f.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isVerify = widget.mode == 'verify_email';

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom),
        decoration: const BoxDecoration(
          color: kWhite,
          borderRadius: BorderRadius.only(
            topLeft:  Radius.circular(30),
            topRight: Radius.circular(30),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: kSage,
                    borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 20),

              Text(
                isVerify ? 'Email Verification' : 'Code Verification',
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: kTeal),
              ),
              const SizedBox(height: 10),

              Text(
                isVerify
                    ? "We've sent a 6-digit verification code to\n****${_domain(widget.email)}"
                    : "We've Sent A Verification Code To\n****${_domain(widget.email)}",
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 13, color: kSage, height: 1.5),
              ),
              const SizedBox(height: 8),
              const Text('Enter Your Code',
                  style: TextStyle(fontSize: 13, color: kSage)),
              const SizedBox(height: 20),

              // OTP boxes
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children:
                    List.generate(6, (i) => _buildOtpBox(i)),
              ),
              const SizedBox(height: 12),

              // Resend / error
              if (_hasError)
                const Text('Invalid code. Please try again.',
                    style: TextStyle(color: kTerra, fontSize: 13))
              else if (_canResend)
                GestureDetector(
                  onTap: _resend,
                  child: const Text('Resend Code',
                      style: TextStyle(
                          color: kTerra,
                          fontWeight: FontWeight.bold)),
                )
              else
                Text('Resend In $_secondsLeft Seconds',
                    style:
                        const TextStyle(color: kSage, fontSize: 13)),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity, height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kTerra,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)),
                  ),
                  onPressed: _loading ? null : _onVerify,
                  child: _loading
                      ? const SizedBox(
                          width: 24, height: 24,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('Verify',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: kWhite)),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOtpBox(int index) {
    final bool isFilled = _controllers[index].text.isNotEmpty;
    return SizedBox(
      width: 48, height: 56,
      child: TextField(
        controller: _controllers[index],
        focusNode:  _focusNodes[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: kWhite),
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: _hasError
              ? const Color(0xFFC96E4A)
              : isFilled
                  ? const Color(0xFFC96E4A)
                  : const Color(0x85C96E4A),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
                color: isFilled
                    ? const Color(0xFFC96E4A)
                    : const Color(0xFF0F5C5C),
                width: 2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
                color: isFilled
                    ? const Color(0xFFC96E4A)
                    : const Color(0xFF0F5C5C),
                width: 2),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
                color: isFilled
                    ? const Color(0xFFC96E4A)
                    : const Color(0xFF0F5C5C),
                width: 2),
          ),
        ),
        onChanged: (value) {
          setState(() {});
          if (value.isNotEmpty && index < 5) {
            _focusNodes[index + 1].requestFocus();
          }
          if (value.isEmpty && index > 0) {
            _focusNodes[index - 1].requestFocus();
          }
        },
      ),
    );
  }

  Future<void> _onVerify() async {
    final otp = _controllers.map((c) => c.text).join();
    if (otp.length < 6) {
      setState(() => _hasError = true);
      return;
    }

    setState(() { _loading = true; _hasError = false; });

    try {
      if (widget.mode == 'verify_email') {
        // ── Email verification after registration
        await AuthService().verifyEmail(
          email: widget.email,
          otp:   otp,
        );
        if (!mounted) return;
        // Close OTP sheet and go to home
        Navigator.of(context).popUntil((route) => route.isFirst);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      } else {
        // ── Password reset (existing flow)
        Navigator.pop(context);
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => ResetPasswordScreen(
            email: widget.email,
            otp:   otp,
          ),
        );
      }
    } catch (e) {
      setState(() => _hasError = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Verification failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _domain(String email) {
    if (email.contains('@')) return email.substring(email.indexOf('@'));
    return '@mail.com';
  }
}