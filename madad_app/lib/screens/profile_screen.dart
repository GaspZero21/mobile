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
import '../screens/notification_settings_screen.dart';
import '../screens/leaderboard_screen.dart';
import '../services/app_token.dart';
import '../services/auth_service.dart';
import '../screens/donor_auth_screen.dart';
import '../screens/gamification_screen.dart';
import '../services/user_service.dart';
import '../services/notification_service.dart';
import '../services/category_service.dart';
import 'package:geolocator/geolocator.dart';

// ── Category model (from API) ──────────────────────────────────────────────
class _Cat {
  final String value; // slug
  final String label; // name
  final String emoji;
  const _Cat(this.value, this.label, [this.emoji = '']);
}

// ====================== PROFILE SCREEN ======================

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  static const String _baseUrl =
      'https://gasp-test-production.up.railway.app/api/v1';

  String? _avatarUrl;
  String _displayName = '';
  String _email = '';
  int _donationCount = 0;
  int _reservCount = 0;
  double _rating = 0;
  bool _loading = true;
  bool _isDonor = true;
  bool _isBeneficiary = true;

  // ── Favorite categories ────────────────────────────────────────────────
  Set<String> _favCategories = {};
  Set<String> _favCategoriesOriginal = {};
  bool _savingCats = false;
  bool _catsExpanded = false;
  List<_Cat> _allCats = [];
  bool _catsLoading = false;

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    // Run both in parallel; _loadCategories re-applies _favCategories when done
    _load().then((_) {
      debugPrint('[Profile] favCats after load: $_favCategories');
    });
    _loadCategories();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final token = AppToken.get();
      if (token == null) {
        setState(() => _loading = false);
        return;
      }

      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final results = await Future.wait([
        http.get(Uri.parse('$_baseUrl/users/me'), headers: headers),
        http.get(Uri.parse('$_baseUrl/donations/my'), headers: headers),
        http.get(Uri.parse('$_baseUrl/reservations'), headers: headers),
      ]);

      if (!mounted) return;

      if (results[0].statusCode == 200) {
        final body = jsonDecode(results[0].body) as Map<String, dynamic>;
        final user =
            body['data']?['user'] as Map<String, dynamic>? ??
            body['data'] as Map<String, dynamic>? ??
            {};
        _displayName = user['name']?.toString() ?? '';
        _email = user['email']?.toString() ?? '';
        _rating = (user['rating'] as num?)?.toDouble() ?? 0;
        _avatarUrl = user['avatar']?.toString();

        // ── Load saved favorite categories ─────────────────────────
        // Check every possible nesting the API might use
        final prefs =
            user['preferences'] as Map<String, dynamic>? ??
            user['notificationPreferences'] as Map<String, dynamic>? ??
            {};

        final raw =
            prefs['preferred_categories'] ??
            prefs['preferredCategories'] ??
            user['preferred_categories'] ??
            user['preferredCategories'];

        debugPrint('[Profile] raw preferred_categories: $raw');

        if (raw is List && raw.isNotEmpty) {
          final saved = raw.map((e) => e.toString()).toSet();
          _favCategories = saved;
          _favCategoriesOriginal = Set.from(saved);
          debugPrint('[Profile] Loaded ${saved.length} fav categories: $saved');
        }
      }

      if (results[1].statusCode == 200) {
        final body = jsonDecode(results[1].body) as Map<String, dynamic>;
        final raw =
            body['data']?['donations'] ??
            body['data'] ??
            body['donations'] ??
            [];
        if (raw is List) {
          _donationCount = raw.length;
        } else if (raw is Map) {
          _donationCount = (raw['count'] as num?)?.toInt() ?? 0;
        }
        if (_donationCount == 0) {
          _donationCount =
              (body['count'] as num?)?.toInt() ??
              (body['total'] as num?)?.toInt() ??
              _donationCount;
        }
      }

      if (results[2].statusCode == 200) {
        final body = jsonDecode(results[2].body) as Map<String, dynamic>;
        final raw =
            body['data']?['reservations'] ??
            body['data'] ??
            body['reservations'] ??
            [];
        if (raw is List) {
          _reservCount = raw.length;
        } else if (raw is Map) {
          _reservCount = (raw['count'] as num?)?.toInt() ?? 0;
        }
        if (_reservCount == 0) {
          _reservCount =
              (body['count'] as num?)?.toInt() ??
              (body['total'] as num?)?.toInt() ??
              _reservCount;
        }
      }

      setState(() => _loading = false);
      _animCtrl.forward(from: 0);
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Load categories using CategoryService (same as AddDonationScreen) ──
  Future<void> _loadCategories() async {
    setState(() => _catsLoading = true);
    try {
      final cats = await CategoryService().getCategories(includeAll: false);
      if (mounted) {
        setState(() {
          _allCats = cats
              .map(
                (c) => _Cat(
                  c['value'] ?? c['slug'] ?? '',
                  c['label'] ?? c['name'] ?? '',
                  c['emoji'] ?? '',
                ),
              )
              .where((c) => c.value.isNotEmpty && c.label.isNotEmpty)
              .toList();
        });
      }
    } catch (_) {
      // silently fail — chips just won't appear
    } finally {
      if (mounted) {
        setState(() {
          _catsLoading = false;
          // Re-apply saved selections now that _allCats is populated.
          // This guarantees chips repaint with the correct selected state
          // regardless of which future (_load or _loadCategories) finished first.
          _favCategories = Set.from(_favCategories);
        });
      }
    }
  }

  Future<void> _updateLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enable location services')),
        );
        return;
      }
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final newPerm = await Geolocator.requestPermission();
        if (newPerm == LocationPermission.denied) return;
      }
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      await UserService().updateLocation(
        latitude: position.latitude,
        longitude: position.longitude,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location updated successfully'),
          backgroundColor: kTeal,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update location: $e')));
    }
  }

  // ── Save favorite categories ───────────────────────────────────────────
  Future<void> _saveFavCategories() async {
    setState(() => _savingCats = true);
    try {
      await NotificationService().updatePreferences(
        preferredCategories: _favCategories.toList(),
      );
      if (!mounted) return;
      setState(() {
        _favCategoriesOriginal = Set.from(_favCategories);
        _catsExpanded = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Favorite categories saved ✓'),
          backgroundColor: kTeal,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
    } finally {
      if (mounted) setState(() => _savingCats = false);
    }
  }

  bool get _catsChanged {
    if (_favCategories.length != _favCategoriesOriginal.length) return true;
    return _favCategories.any((c) => !_favCategoriesOriginal.contains(c));
  }

  String get _initials {
    if (_displayName.isEmpty) return '?';
    return _displayName
        .trim()
        .split(' ')
        .take(2)
        .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
        .join();
  }

  PageRoute _slideRoute(Widget page) => PageRouteBuilder(
    pageBuilder: (_, a, __) => page,
    transitionsBuilder: (_, a, __, child) => SlideTransition(
      position: Tween(
        begin: const Offset(1, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
      child: child,
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSand,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kTeal))
          : FadeTransition(
              opacity: _fadeAnim,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _buildHeader(context)),
                  SliverToBoxAdapter(child: _buildBody(context)),
                ],
              ),
            ),
      bottomNavigationBar: const SharedBottomNav(currentIndex: 4),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0A4040), kTeal],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -40,
            right: -40,
            child: _circle(180, Colors.white.withOpacity(0.04)),
          ),
          Positioned(
            bottom: 20,
            left: -30,
            child: _circle(100, Colors.white.withOpacity(0.04)),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                const SizedBox(height: 16),
                const Text(
                  'My Profile',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: kWhite,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 28),
                _buildAvatar(92),
                const SizedBox(height: 14),
                Text(
                  _displayName.isNotEmpty ? _displayName : 'Your Name',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: kWhite,
                    letterSpacing: 0.2,
                  ),
                ),
                if (_email.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    _email,
                    style: TextStyle(
                      fontSize: 13,
                      color: kWhite.withOpacity(0.65),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _roleChip('Donor', kSage),
                    const SizedBox(width: 8),
                    _roleChip('Beneficiary', kTerra),
                  ],
                ),
                const SizedBox(height: 28),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.symmetric(vertical: 22),
                  decoration: BoxDecoration(
                    color: kWhite,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.10),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      _statItem(
                        '$_donationCount',
                        'Donations',
                        Icons.volunteer_activism_outlined,
                        kTeal,
                      ),
                      _vertDivider(),
                      _statItem(
                        '$_reservCount',
                        'Reservations',
                        Icons.bookmark_outline_rounded,
                        kTerra,
                      ),
                      _vertDivider(),
                      _statItem(
                        _rating > 0 ? _rating.toStringAsFixed(1) : '—',
                        'Rating',
                        Icons.star_rounded,
                        const Color(0xFFD4A017),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(double size) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: kWhite, width: 3),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.18),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    child: ClipOval(
      child: _avatarUrl != null && _avatarUrl!.isNotEmpty
          ? Image.network(
              _avatarUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _initialsBox(size),
            )
          : _initialsBox(size),
    ),
  );

  Widget _initialsBox(double size) => Container(
    color: kSage,
    child: Center(
      child: Text(
        _initials,
        style: TextStyle(
          fontSize: size * 0.34,
          fontWeight: FontWeight.bold,
          color: kWhite,
        ),
      ),
    ),
  );

  Widget _buildBody(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: kSand,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),

          // ── Account ────────────────────────────────────────────────
          _sectionLabel('Account'),
          _menuCard([
            _menuItem(
              icon: Icons.person_outline_rounded,
              label: 'Edit Profile',
              subtitle: 'Update your personal info',
              iconColor: kTeal,
              onTap: () => Navigator.push(
                context,
                _slideRoute(
                  EditProfileScreen(
                    displayName: _displayName,
                    avatarUrl: _avatarUrl,
                  ),
                ),
              ).then((_) => _load()),
            ),
            _menuDivider(),
            _menuItem(
              icon: Icons.volunteer_activism_outlined,
              label: 'My Donations',
              subtitle: '$_donationCount items donated',
              iconColor: const Color(0xFF3D8C7A),
              onTap: () => Navigator.push(
                context,
                _slideRoute(const MyDonationsScreen()),
              ).then((_) => _load()),
            ),
            _menuDivider(),
            _menuItem(
              icon: Icons.bookmark_outline_rounded,
              label: 'My Reservations',
              subtitle: '$_reservCount active reservations',
              iconColor: kTerra,
              onTap: () => Navigator.push(
                context,
                _slideRoute(const MyReservationsScreen()),
              ).then((_) => _load()),
            ),
            _menuDivider(),
            _menuItem(
              icon: Icons.emoji_events_rounded,
              label: 'Community & Rewards',
              subtitle: 'Points, badges, leaderboard & Food Saver',
              iconColor: const Color(0xFFD4A017),
              onTap: () => Navigator.push(
                context,
                _slideRoute(const GamificationScreen()),
              ),
            ),
          ]),

          // ── Preferences ────────────────────────────────────────────
          _sectionLabel('Preferences'),
          _menuCard([
            _menuItem(
              icon: Icons.location_on_outlined,
              label: 'Update Location',
              subtitle: 'Improve nearby donation discovery',
              iconColor: kTerra,
              onTap: _updateLocation,
            ),
            _menuDivider(),
            _menuItem(
              icon: Icons.leaderboard_rounded,
              label: 'Leaderboard',
              subtitle: 'Monthly rankings & badges',
              iconColor: const Color(0xFFD4A017),
              onTap: () => Navigator.push(
                context,
                _slideRoute(const LeaderboardScreen()),
              ),
            ),
            _menuDivider(),
            _menuItem(
              icon: Icons.notifications_none_rounded,
              label: 'Notification Settings',
              subtitle: 'Manage what you get notified about',
              iconColor: kSage,
              onTap: () => Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (_, animation, __) =>
                      const NotificationSettingsScreen(),
                  transitionsBuilder: (_, animation, __, child) =>
                      SlideTransition(
                        position:
                            Tween<Offset>(
                              begin: const Offset(1, 0),
                              end: Offset.zero,
                            ).animate(
                              CurvedAnimation(
                                parent: animation,
                                curve: Curves.easeOutCubic,
                              ),
                            ),
                        child: child,
                      ),
                ),
              ),
            ),
            _menuDivider(),

            // ── Favorite Categories inline expandable ─────────────
            _favCategoriesTile(),
          ]),

          // ── Session ────────────────────────────────────────────────
          _sectionLabel('Session'),
          _menuCard([
            _menuItem(
              icon: Icons.logout_rounded,
              label: 'Log Out',
              subtitle: 'Sign out of your account',
              iconColor: const Color(0xFFBF4444),
              danger: true,
              onTap: _showLogoutDialog,
            ),
          ]),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ── Favorite Categories expandable tile ───────────────────────────────
  Widget _favCategoriesTile() {
    final subtitle = _favCategoriesOriginal.isEmpty
        ? 'All categories (tap to filter)'
        : '${_favCategoriesOriginal.length} selected';

    return Column(
      children: [
        InkWell(
          borderRadius: _catsExpanded
              ? BorderRadius.zero
              : const BorderRadius.only(
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
          onTap: () => setState(() => _catsExpanded = !_catsExpanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.pinkAccent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.favorite_border_rounded,
                    color: Colors.pinkAccent,
                    size: 21,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Favorite Categories',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A2E2E),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: kSage.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedRotation(
                  turns: _catsExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: kSage.withOpacity(0.5),
                    size: 22,
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 250),
          crossFadeState: _catsExpanded
              ? CrossFadeState.showFirst
              : CrossFadeState.showSecond,
          firstChild: _buildCatsPanel(),
          secondChild: const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildCatsPanel() {
    return Container(
      decoration: BoxDecoration(
        color: kSand.withOpacity(0.6),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(18),
          bottomRight: Radius.circular(18),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info hint
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              _favCategories.isEmpty
                  ? '💡 No filter — you\'ll be notified for all categories.'
                  : '💡 You\'ll be notified when a donation from a selected category is completed.',
              style: TextStyle(
                fontSize: 11,
                color: kSage.withOpacity(0.8),
                height: 1.4,
              ),
            ),
          ),

          // Select All / Clear row
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              GestureDetector(
                onTap: () => setState(
                  () => _favCategories = _allCats.map((c) => c.value).toSet(),
                ),
                child: Text(
                  'Select All',
                  style: TextStyle(
                    fontSize: 11,
                    color: kTeal,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  '·',
                  style: TextStyle(color: kSage.withOpacity(0.4)),
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _favCategories = {}),
                child: Text(
                  'Clear All',
                  style: TextStyle(
                    fontSize: 11,
                    color: kTerra,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Category chips — loader or chips
          if (_catsLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: kTeal,
                    strokeWidth: 2,
                  ),
                ),
              ),
            )
          else if (_allCats.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No categories available.',
                style: TextStyle(fontSize: 12, color: kSage.withOpacity(0.7)),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _allCats.map((cat) {
                final selected = _favCategories.contains(cat.value);
                return GestureDetector(
                  onTap: () => setState(() {
                    if (selected) {
                      _favCategories.remove(cat.value);
                    } else {
                      _favCategories.add(cat.value);
                    }
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: selected ? kTeal : kWhite,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected ? kTeal : const Color(0xFFDDDDDD),
                      ),
                      boxShadow: selected
                          ? [
                              BoxShadow(
                                color: kTeal.withOpacity(0.25),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : [],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (cat.emoji.isNotEmpty) ...[
                          Text(cat.emoji, style: const TextStyle(fontSize: 13)),
                          const SizedBox(width: 5),
                        ],
                        Text(
                          cat.label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: selected ? kWhite : kSage,
                          ),
                        ),
                        if (selected) ...[
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.check_rounded,
                            size: 13,
                            color: kWhite,
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),

          const SizedBox(height: 14),

          // Save button
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _catsChanged ? kTerra : kSage.withOpacity(0.3),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: (_catsChanged && !_savingCats)
                  ? _saveFavCategories
                  : null,
              child: _savingCats
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: kWhite,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      _catsChanged ? 'Save' : 'No Changes',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _catsChanged ? kWhite : kSage,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 20, 24, 6),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: kSage.withOpacity(0.8),
          letterSpacing: 1.3,
        ),
      ),
    ),
  );

  Widget _menuCard(List<Widget> children) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Container(
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    ),
  );

  Widget _menuDivider() => const Padding(
    padding: EdgeInsets.only(left: 72),
    child: Divider(height: 1, color: Color(0xFFF0EDE6)),
  );

  Widget _menuItem({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color iconColor,
    required VoidCallback onTap,
    bool danger = false,
  }) => InkWell(
    borderRadius: BorderRadius.circular(18),
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 21),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: danger
                        ? const Color(0xFFBF4444)
                        : const Color(0xFF1A2E2E),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: kSage.withOpacity(0.9)),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: kSage.withOpacity(0.5),
            size: 20,
          ),
        ],
      ),
    ),
  );

  Widget _statItem(String value, String label, IconData icon, Color color) =>
      Expanded(
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1A2E2E),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: kSage,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );

  Widget _vertDivider() =>
      Container(width: 1, height: 50, color: const Color(0xFFEDE9E0));

  Widget _roleChip(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
    decoration: BoxDecoration(
      color: color.withOpacity(0.2),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withOpacity(0.45), width: 1),
    ),
    child: Text(
      label,
      style: const TextStyle(
        fontSize: 12,
        color: kWhite,
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  Widget _circle(double size, Color color) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );

  void _showLogoutDialog() {
    showDialog(
      context: context,
      barrierColor: Colors.black45,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        backgroundColor: kWhite,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: const Color(0xFFBF4444).withOpacity(0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.logout_rounded,
                  color: Color(0xFFBF4444),
                  size: 32,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Log Out?',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A2E2E),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Are you sure you want to sign out\nof your account?',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: kSage, height: 1.5),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        side: BorderSide(color: kSage.withOpacity(0.4)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: kSage,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFBF4444),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        AuthService.logout();
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const DonorAuthScreen(),
                          ),
                          (_) => false,
                        );
                      },
                      child: const Text(
                        'Log Out',
                        style: TextStyle(
                          color: kWhite,
                          fontWeight: FontWeight.w700,
                        ),
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
}

// ====================== EDIT PROFILE SCREEN ======================

class EditProfileScreen extends StatefulWidget {
  final String displayName;
  final String? avatarUrl;
  const EditProfileScreen({super.key, this.displayName = '', this.avatarUrl});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  static const String _baseUrl =
      'https://gasp-test-production.up.railway.app/api/v1';

  Uint8List? _avatarBytes;
  String? _avatarMime;
  String? _avatarUrl;
  bool _isSaving = false;
  bool _hasChanges = false;

  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _bioCtrl;
  late final TextEditingController _cityCtrl;

  String _origName = '',
      _origPhone = '',
      _origEmail = '',
      _origBio = '',
      _origCity = '';

  @override
  void initState() {
    super.initState();
    _avatarUrl = widget.avatarUrl;
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
    final changed =
        _nameCtrl.text != _origName ||
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
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final user =
            body['data']?['user'] as Map<String, dynamic>? ??
            body['data'] as Map<String, dynamic>? ??
            {};
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
            _avatarUrl = user['avatar']?.toString() ?? _avatarUrl;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    final ext = picked.name.split('.').last.toLowerCase();
    final mime = ext == 'png'
        ? 'image/png'
        : ext == 'webp'
        ? 'image/webp'
        : 'image/jpeg';
    setState(() {
      _avatarBytes = bytes;
      _avatarMime = mime;
      _hasChanges = true;
    });
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final token = AppToken.get();
      if (token == null) throw Exception('Not logged in');

      if (_avatarBytes != null) {
        final mime = _avatarMime ?? 'image/jpeg';
        final ext = mime.split('/').last;
        final req =
            http.MultipartRequest(
                'PATCH',
                Uri.parse('$_baseUrl/users/me/avatar'),
              )
              ..headers['Authorization'] = 'Bearer $token'
              ..files.add(
                http.MultipartFile.fromBytes(
                  'avatar',
                  _avatarBytes!,
                  filename: 'avatar.$ext',
                  contentType: MediaType('image', ext),
                ),
              );
        final streamed = await req.send();
        final avatarRes = await http.Response.fromStream(streamed);
        if (avatarRes.statusCode != 200) {
          final b = jsonDecode(avatarRes.body) as Map<String, dynamic>?;
          throw Exception(b?['message'] ?? 'Failed to upload avatar');
        }
      }

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
          const SnackBar(
            content: Text('Profile updated ✓'),
            backgroundColor: kTeal,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      } else {
        final b = jsonDecode(res.body) as Map<String, dynamic>;
        throw Exception(b['message'] ?? 'Update failed');
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: const Color(0xFFBF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String get _initials {
    final name = _nameCtrl.text.isNotEmpty
        ? _nameCtrl.text
        : widget.displayName;
    if (name.isEmpty) return '?';
    return name
        .trim()
        .split(' ')
        .take(2)
        .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
        .join();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSand,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHeader(context)),
          SliverToBoxAdapter(child: _buildForm()),
        ],
      ),
      bottomNavigationBar: const SharedBottomNav(currentIndex: 4),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final avatarSize = (MediaQuery.of(context).size.width * 0.22).clamp(
      80.0,
      110.0,
    );
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0A4040), kTeal],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -20,
            right: -20,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                shape: BoxShape.circle,
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: kWhite,
                          size: 20,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Expanded(
                        child: Text(
                          'Edit Profile',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: kWhite,
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: _pickAvatar,
                  child: Stack(
                    children: [
                      Container(
                        width: avatarSize,
                        height: avatarSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: kWhite, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.18),
                              blurRadius: 14,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: _avatarBytes != null
                              ? Image.memory(_avatarBytes!, fit: BoxFit.cover)
                              : (_avatarUrl != null && _avatarUrl!.isNotEmpty)
                              ? Image.network(
                                  _avatarUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      _initialsBox(avatarSize),
                                )
                              : _initialsBox(avatarSize),
                        ),
                      ),
                      Positioned(
                        bottom: 2,
                        right: 2,
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: kTerra,
                            shape: BoxShape.circle,
                            border: Border.all(color: kWhite, width: 2),
                          ),
                          child: const Icon(
                            Icons.camera_alt_rounded,
                            color: kWhite,
                            size: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _nameCtrl.text.isNotEmpty
                      ? _nameCtrl.text
                      : widget.displayName,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: kWhite,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tap photo to change',
                  style: TextStyle(
                    fontSize: 12,
                    color: kWhite.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 28),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _initialsBox(double size) => Container(
    color: kSage,
    child: Center(
      child: Text(
        _initials,
        style: TextStyle(
          fontSize: size * 0.34,
          fontWeight: FontWeight.bold,
          color: kWhite,
        ),
      ),
    ),
  );

  Widget _buildForm() {
    return Container(
      decoration: const BoxDecoration(
        color: kSand,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 40),
      child: Column(
        children: [
          _formCard([
            _field('Full Name', _nameCtrl, Icons.person_outline_rounded),
            _divider(),
            _field(
              'Phone Number',
              _phoneCtrl,
              Icons.phone_outlined,
              type: TextInputType.phone,
            ),
            _divider(),
            _field(
              'E-Mail',
              _emailCtrl,
              Icons.mail_outline_rounded,
              type: TextInputType.emailAddress,
              readOnly: true,
            ),
          ]),
          const SizedBox(height: 16),
          _formCard([
            _field('Bio', _bioCtrl, Icons.info_outline_rounded, maxLines: 3),
            _divider(),
            _field('City', _cityCtrl, Icons.location_on_outlined),
          ]),
          const SizedBox(height: 32),
          AnimatedSlide(
            offset: _hasChanges ? Offset.zero : const Offset(0, 0.15),
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOut,
            child: AnimatedOpacity(
              opacity: _hasChanges ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 220),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kTerra,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: kWhite,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text(
                          'Save Changes',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: kWhite,
                            letterSpacing: 0.3,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _formCard(List<Widget> children) => Container(
    decoration: BoxDecoration(
      color: kWhite,
      borderRadius: BorderRadius.circular(18),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
    child: Column(children: children),
  );

  Widget _divider() => const Padding(
    padding: EdgeInsets.only(left: 36),
    child: Divider(height: 1, color: Color(0xFFF0EDE6)),
  );

  Widget _field(
    String label,
    TextEditingController ctrl,
    IconData icon, {
    TextInputType type = TextInputType.text,
    bool readOnly = false,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              icon,
              color: readOnly ? kSage.withOpacity(0.4) : kTeal,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: kSage,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 3),
                TextField(
                  controller: ctrl,
                  keyboardType: type,
                  readOnly: readOnly,
                  maxLines: maxLines,
                  style: TextStyle(
                    fontSize: 14,
                    color: readOnly
                        ? kSage.withOpacity(0.5)
                        : const Color(0xFF1A2E2E),
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ),
          if (!readOnly)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                Icons.edit_outlined,
                color: kSage.withOpacity(0.5),
                size: 16,
              ),
            ),
        ],
      ),
    );
  }
}