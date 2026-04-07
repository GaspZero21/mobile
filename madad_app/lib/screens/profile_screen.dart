import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:http_parser/http_parser.dart';

import '../theme/colors.dart';
import '../widgets/shared_bottom_nav.dart';
import '../screens/my_donations_screen.dart';
import '../screens/my_reservations_screen.dart';
import '../services/app_token.dart';
import '../services/auth_service.dart';
import '../screens/donor_auth_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Uint8List? _avatarBytes;   // Temporary preview during edit
  String? _avatarUrl;        // Server avatar URL
  String _displayName = '';
  String _email = '';
  int _donationCount = 0;
  int _reservCount = 0;
  double _rating = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final token = AppToken.get();
      if (token == null) {
        setState(() => _loading = false);
        return;
      }

      final res = await http.get(
        Uri.parse('https://gasp-test-production.up.railway.app/api/v1/users/me'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (res.statusCode == 200 && mounted) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final user = body['data']?['user'] as Map<String, dynamic>? ?? body['data'] as Map<String, dynamic>? ?? {};

        setState(() {
          _displayName = user['name']?.toString() ?? '';
          _email = user['email']?.toString() ?? '';
          _donationCount = (user['donationCount'] as num?)?.toInt() ?? 0;
          _reservCount = (user['reservationCount'] as num?)?.toInt() ?? 0;
          _rating = (user['rating'] as num?)?.toDouble() ?? 0;
          _avatarUrl = user['avatar']?.toString();   // Get avatar URL from backend
          _avatarBytes = null;
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final double avatarSize = (MediaQuery.of(context).size.width * 0.20).clamp(72.0, 110.0);
    final double headerHeight = MediaQuery.of(context).size.height * 0.22;

    final initials = _displayName.isNotEmpty
        ? _displayName.trim().split(' ').take(2).map((w) => w.isNotEmpty ? w[0].toUpperCase() : '').join()
        : '?';

    return Scaffold(
      backgroundColor: kSand,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kTeal))
          : CustomScrollView(
              slivers: [
                // Teal Header
                SliverToBoxAdapter(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        height: headerHeight,
                        width: double.infinity,
                        color: kTeal,
                        child: SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'My Profile',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kWhite),
                            ),
                          ),
                        ),
                      ),
                      // Avatar
                      Positioned(
                        bottom: -(avatarSize / 2),
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            width: avatarSize,
                            height: avatarSize,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: kWhite, width: 3),
                              color: const Color(0xFFD9D9D9),
                            ),
                            child: ClipOval(
                              child: _avatarBytes != null
                                  ? Image.memory(_avatarBytes!, fit: BoxFit.cover)
                                  : _avatarUrl != null && _avatarUrl!.isNotEmpty
                                      ? Image.network(
                                          _avatarUrl!,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) => _buildInitials(avatarSize, initials),
                                        )
                                      : _buildInitials(avatarSize, initials),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Main Content
                SliverToBoxAdapter(
                  child: Container(
                    margin: EdgeInsets.only(top: avatarSize / 2),
                    decoration: const BoxDecoration(
                      color: kSand,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(28),
                        topRight: Radius.circular(28),
                      ),
                    ),
                    child: Column(
                      children: [
                        SizedBox(height: avatarSize / 2 + 12),

                        // Name
                        Text(
                          _displayName.isNotEmpty ? _displayName : 'Your Name',
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: kTeal),
                        ),
                        const SizedBox(height: 4),

                        // Email
                        if (_email.isNotEmpty)
                          Text(_email, style: const TextStyle(fontSize: 12, color: kSage)),

                        const SizedBox(height: 12),

                        // Badges
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _badge('Donor', kTeal),
                            const SizedBox(width: 8),
                            _badge('Beneficiary', kTerra),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Statistics
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Row(
                            children: [
                              _stat('$_donationCount', 'Donations'),
                              _statDivider(),
                              _stat('$_reservCount', 'Reservations'),
                              _statDivider(),
                              _stat(
                                _rating > 0 ? _rating.toStringAsFixed(1) : '—',
                                'Rating',
                                icon: _rating > 0 ? Icons.star : null,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Divider(height: 1, color: Color(0xFFF2F2F2)),

                        // Menu Items
                        _menuItem(
                          icon: Icons.person_outline,
                          label: 'Edit Profile',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => EditProfileScreen(displayName: _displayName)),
                          ).then((_) => _load()),
                        ),
                        _menuItem(
                          icon: Icons.volunteer_activism_outlined,
                          label: 'My Donations',
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyDonationsScreen())).then((_) => _load()),
                        ),
                        _menuItem(
                          icon: Icons.bookmark_outline,
                          label: 'My Reservations',
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyReservationsScreen())).then((_) => _load()),
                        ),
                        _menuItem(
                          icon: Icons.notifications_none_outlined,
                          label: 'Notifications Settings',
                          onTap: () {},
                        ),
                        _menuItem(
                          icon: Icons.logout,
                          label: 'Log Out',
                          onTap: _showLogoutDialog,
                          danger: true,
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ],
            ),
      bottomNavigationBar: const SharedBottomNav(currentIndex: 4),
    );
  }

  Widget _buildInitials(double size, String initials) => Container(
        color: kSage,
        child: Center(
          child: Text(
            initials,
            style: TextStyle(fontSize: size * 0.32, fontWeight: FontWeight.bold, color: kWhite),
          ),
        ),
      );

  // ==================== HELPER WIDGETS ====================

  void _showLogoutDialog() {
    showDialog(
      context: context,
      barrierColor: Colors.black38,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Logout Account ?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kTeal)),
              const SizedBox(height: 20),
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(color: kTeal, shape: BoxShape.circle),
                child: const Icon(Icons.logout, color: kWhite, size: 32),
              ),
              const SizedBox(height: 20),
              const Text(
                'Do You Want Logout Your\nAccount ?',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.black54),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel', style: TextStyle(color: kTerra, fontWeight: FontWeight.w600, fontSize: 15)),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kTerra,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      AuthService.logout();
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => const DonorAuthScreen()),
                        (r) => false,
                      );
                    },
                    child: const Text('Logout', style: TextStyle(color: kWhite, fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
        ),
      );

  Widget _stat(String value, String label, {IconData? icon}) => Expanded(
        child: Column(
          children: [
            if (icon != null)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: Colors.amber, size: 14),
                  const SizedBox(width: 2),
                  Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kTeal)),
                ],
              )
            else
              Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kTeal)),
            const SizedBox(height: 3),
            Text(label, style: const TextStyle(fontSize: 11, color: kSage)),
          ],
        ),
      );

  Widget _statDivider() => Container(
        width: 1,
        height: 36,
        color: const Color(0xFFE8E8E8),
      );

  Widget _menuItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool danger = false,
  }) {
    final color = danger ? kTerra : kTeal;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(danger ? 0.12 : 1.0),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: danger ? kTerra : kWhite, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: danger ? kTerra : Colors.black87,
                ),
              ),
            ),
            Icon(Icons.chevron_right, color: kSage, size: 20),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
//                    EDIT PROFILE SCREEN
// ──────────────────────────────────────────────────────────────

class EditProfileScreen extends StatefulWidget {
  final String displayName;
  const EditProfileScreen({super.key, this.displayName = ''});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  static const String _baseUrl = 'https://gasp-test-production.up.railway.app/api/v1';

  Uint8List? _avatarBytes;
  String? _avatarMime;
  bool _isSaving = false;
  bool _hasChanges = false;

  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _bioCtrl;
  late final TextEditingController _cityCtrl;

  String _origName = '';
  String _origPhone = '';
  String _origEmail = '';
  String _origBio = '';
  String _origCity = '';

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();
    _emailCtrl = TextEditingController();
    _bioCtrl = TextEditingController();
    _cityCtrl = TextEditingController();

    for (final c in [_nameCtrl, _phoneCtrl, _emailCtrl, _bioCtrl, _cityCtrl]) {
      c.addListener(_onChanged);
    }
    _fetchProfile();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _bioCtrl.dispose();
    _cityCtrl.dispose();
    super.dispose();
  }

  void _onChanged() {
    final changed = _nameCtrl.text != _origName ||
        _phoneCtrl.text != _origPhone ||
        _emailCtrl.text != _origEmail ||
        _bioCtrl.text != _origBio ||
        _cityCtrl.text != _origCity ||
        _avatarBytes != null;
    if (changed != _hasChanges) setState(() => _hasChanges = changed);
  }

  Future<void> _fetchProfile() async {
    try {
      final token = AppToken.get();
      if (token == null) return;

      final res = await http.get(
        Uri.parse('$_baseUrl/users/me'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      );

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final user = body['data']?['user'] as Map<String, dynamic>? ?? body['data'] as Map<String, dynamic>? ?? {};

        _origName = user['name']?.toString() ?? widget.displayName;
        _origPhone = user['phoneNumber']?.toString() ?? '';
        _origEmail = user['email']?.toString() ?? '';
        _origBio = user['bio']?.toString() ?? '';
        _origCity = user['city']?.toString() ?? '';

        if (mounted) {
          setState(() {
            _nameCtrl.text = _origName;
            _phoneCtrl.text = _origPhone;
            _emailCtrl.text = _origEmail;
            _bioCtrl.text = _origBio;
            _cityCtrl.text = _origCity;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final token = AppToken.get();
      if (token == null) throw Exception('Not logged in');

      // Upload Avatar - using correct field name "avatar"
      if (_avatarBytes != null) {
        final mime = _avatarMime ?? 'image/jpeg';
        final ext = mime.split('/').last;

        final request = http.MultipartRequest(
          'PATCH',
          Uri.parse('$_baseUrl/users/me/avatar'),
        )
          ..headers['Authorization'] = 'Bearer $token'
          ..files.add(
            http.MultipartFile.fromBytes(
              'avatar',                    // Must match API requirement
              _avatarBytes!,
              filename: 'avatar.$ext',
              contentType: MediaType('image', ext),
            ),
          );

        final streamed = await request.send();
        final avatarRes = await http.Response.fromStream(streamed);

        if (avatarRes.statusCode != 200) {
          final b = jsonDecode(avatarRes.body) as Map<String, dynamic>?;
          throw Exception(b?['message'] ?? 'Avatar upload failed');
        }
      }

      // Update text fields
      final res = await http.patch(
        Uri.parse('$_baseUrl/users/me'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'name': _nameCtrl.text.trim(),
          'phoneNumber': _phoneCtrl.text.trim(),
          'bio': _bioCtrl.text.trim(),
          'city': _cityCtrl.text.trim(),
        }),
      );

      if (!mounted) return;

      if (res.statusCode >= 200 && res.statusCode < 300) {
        setState(() {
          _hasChanges = false;
          _avatarBytes = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully'), backgroundColor: Colors.green),
        );

        Navigator.pop(context); // Go back to ProfileScreen to refresh avatar
      } else {
        final b = jsonDecode(res.body) as Map<String, dynamic>;
        throw Exception(b['message'] ?? 'Update failed');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    final ext = picked.name.split('.').last.toLowerCase();
    final mime = ext == 'png' ? 'image/png' : ext == 'webp' ? 'image/webp' : 'image/jpeg';

    setState(() {
      _avatarBytes = bytes;
      _avatarMime = mime;
      _hasChanges = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final double avatarSize = (MediaQuery.of(context).size.width * 0.20).clamp(72.0, 110.0);

    final initials = _nameCtrl.text.isNotEmpty
        ? _nameCtrl.text.trim().split(' ').take(2).map((w) => w.isNotEmpty ? w[0].toUpperCase() : '').join()
        : widget.displayName.isNotEmpty
            ? widget.displayName.trim()[0].toUpperCase()
            : '?';

    return Scaffold(
      backgroundColor: kSand,
      body: CustomScrollView(
        slivers: [
          // Header
          SliverToBoxAdapter(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  height: MediaQuery.of(context).size.height * 0.22,
                  width: double.infinity,
                  color: kTeal,
                  child: SafeArea(
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios, color: kWhite, size: 20),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const Expanded(
                          child: Text(
                            'Edit Profile',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kWhite),
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                  ),
                ),
                // Avatar with edit icon
                Positioned(
                  bottom: -(avatarSize / 2),
                  left: 0,
                  right: 0,
                  child: Center(
                    child: GestureDetector(
                      onTap: _pickAvatar,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: avatarSize,
                            height: avatarSize,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: kWhite, width: 3),
                              color: const Color(0xFFD9D9D9),
                            ),
                            child: ClipOval(
                              child: _avatarBytes != null
                                  ? Image.memory(_avatarBytes!, fit: BoxFit.cover)
                                  : Container(
                                      color: kSage,
                                      child: Center(
                                        child: Text(
                                          initials,
                                          style: TextStyle(
                                            fontSize: avatarSize * 0.32,
                                            fontWeight: FontWeight.bold,
                                            color: kWhite,
                                          ),
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                          Positioned(
                            bottom: 2,
                            right: 2,
                            child: Container(
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                color: kWhite,
                                shape: BoxShape.circle,
                                border: Border.all(color: kSage, width: 1),
                              ),
                              child: const Icon(Icons.edit, color: kTeal, size: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Form
          SliverToBoxAdapter(
            child: Container(
              margin: EdgeInsets.only(top: avatarSize / 2),
              decoration: const BoxDecoration(
                color: kWhite,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
              child: Column(
                children: [
                  Text(
                    _nameCtrl.text.isEmpty ? widget.displayName : _nameCtrl.text,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kTeal),
                  ),
                  const SizedBox(height: 28),
                  _field('Full Name', _nameCtrl),
                  const SizedBox(height: 18),
                  _field('Phone Number', _phoneCtrl, type: TextInputType.phone),
                  const SizedBox(height: 18),
                  _field('E-Mail', _emailCtrl, type: TextInputType.emailAddress, readOnly: true),
                  const SizedBox(height: 18),
                  _field('Bio', _bioCtrl),
                  const SizedBox(height: 18),
                  _field('City', _cityCtrl),
                  const SizedBox(height: 36),
                  if (_hasChanges)
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kTerra,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: _isSaving ? null : _save,
                        child: _isSaving
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: kWhite, strokeWidth: 2))
                            : const Text('Save Changes', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: kWhite)),
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

  Widget _field(String label, TextEditingController ctrl, {TextInputType type = TextInputType.text, bool readOnly = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: kTeal, fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: ctrl,
                keyboardType: type,
                readOnly: readOnly,
                style: TextStyle(fontSize: 14, color: readOnly ? Colors.black38 : Colors.black87),
                decoration: const InputDecoration(
                  border: UnderlineInputBorder(borderSide: BorderSide(color: kSage, width: 1)),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: kSage, width: 1)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: kTeal, width: 1.5)),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.edit, color: readOnly ? Colors.black12 : kSage, size: 16),
          ],
        ),
      ],
    );
  }
}