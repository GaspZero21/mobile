import 'package:flutter/material.dart';
import '../theme/colors.dart';
import 'login_screen.dart'; // we will create this next

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {

  // Controllers read what the user types in each field
  final _fullNameController    = TextEditingController();
  final _phoneController       = TextEditingController();
  final _emailController       = TextEditingController();
  final _passwordController    = TextEditingController();
  final _confirmPassController = TextEditingController();

  bool _passwordVisible        = false; // toggle show/hide password
  bool _confirmPassVisible     = false;
  bool _agreedToTerms          = false; // checkbox

  // Selected role: Donor or Beneficiary
  String _selectedRole = 'Donor';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSand,
      body: SafeArea(
        child: SingleChildScrollView( // allows scrolling when keyboard opens
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              const SizedBox(height: 20),

              // ── TITLE
              const Text(
                'Register Account',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: kTeal,
                ),
              ),

              const SizedBox(height: 28),

              // ── FULL NAME
              _buildTextField(
                controller: _fullNameController,
                label: 'Full Name',
                icon: Icons.person_outline,
              ),

              const SizedBox(height: 16),

              // ── PHONE NUMBER
              _buildTextField(
                controller: _phoneController,
                label: 'Phone Number',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
              ),

              const SizedBox(height: 16),

              // ── EMAIL
              _buildTextField(
                controller: _emailController,
                label: 'E-Mail',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
              ),

              const SizedBox(height: 16),

              // ── PASSWORD
              _buildPasswordField(
                controller: _passwordController,
                label: 'Password',
                isVisible: _passwordVisible,
                onToggle: () => setState(
                  () => _passwordVisible = !_passwordVisible),
              ),

              const SizedBox(height: 16),

              // ── CONFIRM PASSWORD
              _buildPasswordField(
                controller: _confirmPassController,
                label: 'Confirm Your Password',
                isVisible: _confirmPassVisible,
                onToggle: () => setState(
                  () => _confirmPassVisible = !_confirmPassVisible),
              ),

              const SizedBox(height: 20),

              // ── ROLE SELECTOR (Donor / Beneficiary)
              Row(
                children: [
                  _buildRoleButton('Donor'),
                  const SizedBox(width: 12),
                  _buildRoleButton('Beneficiary'),
                ],
              ),

              const SizedBox(height: 20),

              // ── TERMS CHECKBOX
              Row(
                children: [
                  Checkbox(
                    value: _agreedToTerms,
                    activeColor: kTeal,
                    onChanged: (val) =>
                        setState(() => _agreedToTerms = val!),
                  ),
                  const Expanded(
                    child: Text(
                      'I agree to the Terms of Use',
                      style: TextStyle(fontSize: 13, color: kSage),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // ── SIGN UP BUTTON
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

              const SizedBox(height: 20),

              // ── ALREADY HAVE ACCOUNT
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Already have an account? ',
                    style: TextStyle(color: kSage),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const LoginScreen()),
                    ),
                    child: const Text(
                      'Sign In',
                      style: TextStyle(
                        color: kTerra,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ── REUSABLE text field widget
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: kSage),
        prefixIcon: Icon(icon, color: kSage),
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
    );
  }

  // ── REUSABLE password field widget
  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool isVisible,
    required VoidCallback onToggle,
  }) {
    return TextField(
      controller: controller,
      obscureText: !isVisible, // hides the text
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: kSage),
        prefixIcon: const Icon(Icons.lock_outline, color: kSage),
        suffixIcon: IconButton(
          icon: Icon(
            isVisible ? Icons.visibility : Icons.visibility_off,
            color: kSage,
          ),
          onPressed: onToggle,
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
    );
  }

  // ── ROLE selector button
  Widget _buildRoleButton(String role) {
    final bool isSelected = _selectedRole == role;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedRole = role),
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: isSelected ? kTeal : kWhite,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? kTeal : kSage,
            ),
          ),
          child: Center(
            child: Text(
              role,
              style: TextStyle(
                color: isSelected ? kWhite : kSage,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── SIGN UP action
  void _onSignUp() {
  debugPrint('Name: ${_fullNameController.text}');
  debugPrint('Email: ${_emailController.text}');
  debugPrint('Role: $_selectedRole');
}
}