import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:image_picker/image_picker.dart';
import '../theme/colors.dart';
import '../widgets/shared_bottom_nav.dart';
import '../screens/my_donations_screen.dart';
import '../screens/my_reservations_screen.dart';
import '../services/auth_service.dart';
import '../screens/donor_auth_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Uint8List? _avatarBytes;

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() => _avatarBytes = bytes);
  }

  void _logout() {
    AuthService.logout();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const DonorAuthScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    const double avatarSize    = 100.0;
    const double overlapAmount = 30.0;

    return Scaffold(
      backgroundColor: kSage,
      body: Stack(
        children: [
          Column(
            children: [
              // ── Gradient header
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
                      child: const Text('My Profile',
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: kTeal)),
                    ),
                  ),
                ),
              ),

              // ── White card
              Expanded(
                child: ClipPath(
                  clipper: _TopNotchClipper(notchDepth: overlapAmount),
                  child: Container(
                    width: double.infinity,
                    color: kWhite,
                    child: Column(
                      children: [
                        SizedBox(height: avatarSize - overlapAmount + 16),

                        const Text('Z.Mohammed',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: kTeal)),

                        const SizedBox(height: 28),

                        Expanded(
                          child: ListView(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 24),
                            children: [
                              _menuItem(
                                icon: Icons.person_outline,
                                label: 'Edit Profile',
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          const EditProfileScreen()),
                                ),
                              ),
                              _divider(),
                              _menuItem(
                                icon: Icons.inventory_2_outlined,
                                label: 'My Own Donations',
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          const MyDonationsScreen()),
                                ),
                              ),
                              _divider(),
                              _menuItem(
                                icon: Icons.bookmark_outline,
                                label: 'My Reservations',
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          const MyReservationsScreen()),
                                ),
                              ),
                              _divider(),
                              _menuItem(
                                icon: Icons.logout,
                                label: 'Log Out',
                                onTap: _logout,
                                color: kTerra,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          // ── Avatar
          Positioned(
            top: size.height * 0.25 - (avatarSize - overlapAmount),
            left: 0, right: 0,
            child: Center(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  GestureDetector(
                    onTap: _pickAvatar,
                    child: Container(
                      width: avatarSize, height: avatarSize,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0xA10F5C5C),
                            Color(0x94C96E4A)
                          ],
                          stops: [0.32, 1.0],
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(5),
                        child: ClipOval(
                          child: _avatarBytes != null
                              ? Image.memory(_avatarBytes!,
                                  fit: BoxFit.cover)
                              : Container(
                                  color: const Color(0xFFD9D9D9),
                                  child: const Icon(Icons.person,
                                      size: 52,
                                      color: Color(0xFFAAAAAA))),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 2, right: 2,
                    child: GestureDetector(
                      onTap: _pickAvatar,
                      child: Container(
                        width: 26, height: 26,
                        decoration: BoxDecoration(
                            color: kWhite,
                            shape: BoxShape.circle,
                            border: Border.all(color: kSage, width: 1)),
                        child: const Icon(Icons.edit,
                            color: kTeal, size: 13),
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

  Widget _menuItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color color = kTeal,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12), // ← fixed
            shape: BoxShape.circle),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(label,
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: color == kTerra ? kTerra : Colors.black87)),
      trailing: Icon(Icons.chevron_right, color: kSage, size: 20),
    );
  }

  Widget _divider() =>
      const Divider(height: 1, color: Color(0xFFF0F0F0));
}

// ── Edit Profile Screen ───────────────────────────────────────────────────────
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _fullNameController = TextEditingController(text: 'Z.Mohammed');
  final _phoneController    = TextEditingController();
  final _emailController    = TextEditingController();
  final _bioController      = TextEditingController();
  final _addressController  = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _bioController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() => _isSaving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile saved successfully')));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSand,
      appBar: AppBar(
        backgroundColor: kTeal,
        foregroundColor: kWhite,
        title: const Text('Edit Profile',
            style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _field('Full Name',    _fullNameController),
            const SizedBox(height: 20),
            _field('Phone Number', _phoneController,
                type: TextInputType.phone),
            const SizedBox(height: 20),
            _field('E-Mail',       _emailController,
                type: TextInputType.emailAddress),
            const SizedBox(height: 20),
            _field('Bio',          _bioController, maxLines: 3),
            const SizedBox(height: 20),
            _field('Address',      _addressController),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity, height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kTeal,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                  elevation: 0,
                ),
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                            color: kWhite, strokeWidth: 2))
                    : const Text('Save Changes',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: kWhite)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl,
      {TextInputType type = TextInputType.text, int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12,
                color: kSage,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
              color: kWhite,
              borderRadius: BorderRadius.circular(10)),
          child: TextField(
            controller: ctrl,
            keyboardType: type,
            maxLines: maxLines,
            decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Notch clipper ─────────────────────────────────────────────────────────────
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
    path.lineTo(cx + notchWidth, 0);
    path.quadraticBezierTo(
        cx + notchWidth * 0.6, 0, cx + notchWidth * 0.4, notchDepth);
    path.quadraticBezierTo(
        cx, notchDepth * 1.3, cx - notchWidth * 0.4, notchDepth);
    path.quadraticBezierTo(
        cx - notchWidth * 0.6, 0, cx - notchWidth, 0);
    path.lineTo(cornerRadius, 0);
    path.quadraticBezierTo(0, 0, 0, cornerRadius);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(_TopNotchClipper old) => old.notchDepth != notchDepth;
}