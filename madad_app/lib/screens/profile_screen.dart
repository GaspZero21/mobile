import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import '../theme/colors.dart';
import '../widgets/shared_bottom_nav.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _fullNameController = TextEditingController(text: 'Full Name');
  final _phoneController    = TextEditingController();
  final _emailController    = TextEditingController();
  final _bioController      = TextEditingController();
  final _addressController  = TextEditingController();

  bool _isEditing = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _bioController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    const double avatarSize   = 100.0;
    const double overlapAmount = 30.0; // how much avatar overlaps white card

    return Scaffold(
      backgroundColor: kSage,
      body: Stack(
        children: [

          Column(
            children: [

              // ── GRADIENT SECTION
              Container(
                width: double.infinity,
                height: size.height * 0.25,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [kSand, kSage],
                  ),
                ),
                child: SafeArea(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: const Text(
                        'My Profile',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: kTeal,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // ── WHITE CARD with shallow notch
              Expanded(
                child: ClipPath(
                  clipper: _TopNotchClipper(notchDepth: overlapAmount),
                  child: Container(
                    width: double.infinity,
                    color: kWhite,
                    child: Column(
                      children: [

                        // space for avatar overlap
                        SizedBox(height: avatarSize - overlapAmount + 16),

                        // name
                        const Text(
                          'Z.Mohammed',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: kTeal,
                          ),
                        ),

                        const SizedBox(height: 28),

                        // fields
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Column(
                              children: [
                                _buildField(
                                  label: 'Full Name',
                                  controller: _fullNameController,
                                ),
                                const SizedBox(height: 16),
                                _buildField(
                                  label: 'Phone Number',
                                  controller: _phoneController,
                                  keyboardType: TextInputType.phone,
                                ),
                                const SizedBox(height: 16),
                                _buildField(
                                  label: 'E-Mail',
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                ),
                                const SizedBox(height: 16),
                                _buildField(
                                  label: 'Bio',
                                  controller: _bioController,
                                ),
                                const SizedBox(height: 16),
                                _buildField(
                                  label: 'Adress',
                                  controller: _addressController,
                                ),
                                const Spacer(),
                                if (_isEditing)
                                  SizedBox(
                                    width: 200,
                                    height: 48,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: kTerra,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(30),
                                        ),
                                      ),
                                      onPressed: _onSave,
                                      child: const Text(
                                        'Save Changes',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: kWhite,
                                        ),
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 12),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          // ── AVATAR on top of everything
          Positioned(
            top: size.height * 0.25 - (avatarSize - overlapAmount),
            left: 0,
            right: 0,
            child: Center(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // gradient ring + avatar
                  Container(
                    width: avatarSize,
                    height: avatarSize,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xA10F5C5C),
                          Color(0x94C96E4A),
                        ],
                        stops: [0.32, 1.0],
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(5),
                      child: ClipOval(
                        child: Container(
                          color: const Color(0xFFD9D9D9),
                          child: const Icon(
                            Icons.person,
                            size: 52,
                            color: Color(0xFFAAAAAA),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // edit button
                  Positioned(
                    bottom: 2,
                    right: 2,
                    child: GestureDetector(
                      onTap: () {},
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: kWhite,
                          shape: BoxShape.circle,
                          border: Border.all(color: kSage, width: 1),
                        ),
                        child: const Icon(
                          Icons.edit,
                          color: kTeal,
                          size: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),

      bottomNavigationBar: const SharedBottomNav(currentIndex: 4),
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: kSage,
            fontWeight: FontWeight.w500,
          ),
        ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                keyboardType: keyboardType,
                enabled: _isEditing,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 6),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: kSage),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: kTeal, width: 1.5),
                  ),
                  disabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: kSage),
                  ),
                  filled: false,
                ),
              ),
            ),
            GestureDetector(
              onTap: () => setState(() => _isEditing = true),
              child: const Padding(
                padding: EdgeInsets.only(left: 8, bottom: 2),
                child: Icon(Icons.edit, size: 14, color: kTeal),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _onSave() {
    setState(() => _isEditing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile saved successfully')),
    );
  }
}

// ── CLIPPER: shallow notch at top center
class _TopNotchClipper extends CustomClipper<ui.Path> {
  final double notchDepth;
  const _TopNotchClipper({required this.notchDepth});

  @override
  ui.Path getClip(Size size) {
    final path = ui.Path();
    const double cornerRadius = 30.0;
    const double notchWidth   = 80.0;
    final double cx = size.width / 2;

    path.moveTo(0, size.height);
    path.lineTo(size.width, size.height);
    path.lineTo(size.width, cornerRadius);
    path.quadraticBezierTo(size.width, 0, size.width - cornerRadius, 0);

    // right to notch
    path.lineTo(cx + notchWidth, 0);

    // notch dip
    path.quadraticBezierTo(
      cx + notchWidth * 0.6, 0,
      cx + notchWidth * 0.4, notchDepth,
    );
    path.quadraticBezierTo(
      cx, notchDepth * 1.3,
      cx - notchWidth * 0.4, notchDepth,
    );
    path.quadraticBezierTo(
      cx - notchWidth * 0.6, 0,
      cx - notchWidth, 0,
    );

    // left corner
    path.lineTo(cornerRadius, 0);
    path.quadraticBezierTo(0, 0, 0, cornerRadius);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(_TopNotchClipper old) => old.notchDepth != notchDepth;
}