import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _fullNameController    = TextEditingController();
  final _phoneController       = TextEditingController();
  final _emailController       = TextEditingController();
  final _passwordController    = TextEditingController();
  final _confirmPassController = TextEditingController();

  bool _passwordVisible    = false;
  bool _confirmPassVisible = false;
  bool _agreedToTerms      = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSage,
      body: Column(
        children: [

          Container(
            color: kSage,
            padding: const EdgeInsets.fromLTRB(24, 80, 24, 20),
            child: const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Register Account',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: kTeal,
                ),
              ),
            ),
          ),

          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: kSand,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    _buildUnderlineField(
                      controller: _fullNameController,
                      label: 'Full Name',
                    ),

                    const SizedBox(height: 20),

                    _buildUnderlineField(
                      controller: _phoneController,
                      label: 'Phone Number',
                      keyboardType: TextInputType.phone,
                    ),

                    const SizedBox(height: 20),

                    _buildUnderlineField(
                      controller: _emailController,
                      label: 'E-Mail',
                      keyboardType: TextInputType.emailAddress,
                    ),

                    const SizedBox(height: 20),

                    _buildPasswordUnderlineField(
                      controller: _passwordController,
                      label: 'Password',
                      isVisible: _passwordVisible,
                      onToggle: () => setState(
                          () => _passwordVisible = !_passwordVisible),
                    ),

                    const SizedBox(height: 20),

                    _buildPasswordUnderlineField(
                      controller: _confirmPassController,
                      label: 'Confirm Your Password',
                      isVisible: _confirmPassVisible,
                      onToggle: () => setState(
                          () => _confirmPassVisible = !_confirmPassVisible),
                    ),

                    const SizedBox(height: 20),

                    Row(
                      children: [
                        Checkbox(
                          value: _agreedToTerms,
                          activeColor: kTeal,
                          shape: const CircleBorder(),
                          onChanged: (val) =>
                              setState(() => _agreedToTerms = val!),
                        ),
                        const Text(
                          'I Agree To The ',
                          style: TextStyle(fontSize: 13, color: kSage),
                        ),
                        const Text(
                          'Terms & Conditions.',
                          style: TextStyle(
                            fontSize: 13,
                            color: kTerra,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    Center(
                      child: SizedBox(
                        width: 200,
                        height: 52,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kTeal,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          onPressed: _agreedToTerms ? _onSignUp : null,
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
                    ),

                    const SizedBox(height: 30),

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

  Widget _buildUnderlineField({
    required TextEditingController controller,
    required String label,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: kSage, fontSize: 14),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: kSage),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: kTeal, width: 1.5),
        ),
        filled: false,
      ),
    );
  }

  Widget _buildPasswordUnderlineField({
    required TextEditingController controller,
    required String label,
    required bool isVisible,
    required VoidCallback onToggle,
  }) {
    return TextField(
      controller: controller,
      obscureText: !isVisible,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: kSage, fontSize: 14),
        suffixIcon: IconButton(
          icon: Icon(
            isVisible ? Icons.visibility : Icons.lock_outline,
            color: kSage, size: 20,
          ),
          onPressed: onToggle,
        ),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: kSage),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: kTeal, width: 1.5),
        ),
        filled: false,
      ),
    );
  }

 void _onSignUp() async {

  final name = _fullNameController.text.trim();
  final phone = _phoneController.text.trim();
  final email = _emailController.text.trim();
  final password = _passwordController.text.trim();
  final confirm = _confirmPassController.text.trim();

  if (name.isEmpty || email.isEmpty || password.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Please fill required fields")),
    );
    return;
  }

  if (password != confirm) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Passwords do not match")),
    );
    return;
  }

  try {

    final response = await AuthService().register(
      name: name,
      email: email,
      password: password,
      phoneNumber: phone,
    );

    debugPrint(response.toString());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _buildSuccessSheet(
        message: 'Your Account Has Been Created\nSuccessfully!',
        onDone: () {
          Navigator.popUntil(context, (route) => route.isFirst);
        },
      ),
    );

  } catch (e) {

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Registration failed: $e")),
    );

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
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: kSage,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            const SizedBox(height: 30),

            Container(
              width: 80, height: 80,
              decoration: const BoxDecoration(
                color: Color(0xFF2AE523),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check,
                color: kWhite,
                size: 45,
              ),
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