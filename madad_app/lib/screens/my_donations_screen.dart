import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../theme/colors.dart';
import '../services/app_token.dart';
import '../widgets/shared_bottom_nav.dart';

import 'dart:html' as html;

// ── My Donations List ─────────────────────────────────────────────────────────
class MyDonationsScreen extends StatefulWidget {
  const MyDonationsScreen({super.key});

  @override
  State<MyDonationsScreen> createState() => _MyDonationsScreenState();
}

class _MyDonationsScreenState extends State<MyDonationsScreen> {
  static const String baseUrl =
      'https://gasp-test-production.up.railway.app/api/v1';

  List<Map<String, dynamic>> _donations = [];
  bool    _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Map<String, String> get _headers {
    final token = AppToken.get();
    debugPrint('[MyDonations] token = ${token == null ? "null ❌" : "${token.substring(0, 20)}... ✅"}');
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<void> _fetch() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final res  = await http.get(
          Uri.parse('$baseUrl/donations/my'), headers: _headers);

      debugPrint('[MyDonations] status: ${res.statusCode}');
      debugPrint('[MyDonations] body: ${res.body}');

      final body = jsonDecode(res.body) as Map<String, dynamic>;

      if (res.statusCode != 200) {
        throw Exception(body['message'] ?? 'Error ${res.statusCode}');
      }

      // Handle all possible response shapes
      final data = body['data'];
      List list  = [];

      if (data is List) {
        list = data;
      } else if (data is Map) {
        if (data['donations'] is List) {
          list = data['donations'];
        } else if (data['items'] is List) {
          list = data['items'];
        } else {
          // data itself might be the donation object — wrap it
          list = [data];
        }
      } else if (body['donations'] is List) {
        list = body['donations'];
      }

      debugPrint('[MyDonations] parsed ${list.length} donations');

      setState(() {
        _donations = List<Map<String, dynamic>>.from(list);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('[MyDonations] error: $e');
      setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  Future<void> _delete(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete donation?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    await http.delete(
        Uri.parse('$baseUrl/donations/$id'), headers: _headers);
    _fetch();
  }

  void _openEdit(Map<String, dynamic> donation) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => EditDonationScreen(donation: donation)),
    ).then((updated) { if (updated == true) _fetch(); });
  }

  void _showReservations(Map<String, dynamic> donation) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReservationsSheet(
          donation: donation, headers: _headers, baseUrl: baseUrl),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSand,
      appBar: AppBar(
        backgroundColor: kTeal,
        foregroundColor: kWhite,
        title: const Text('My Donations',
            style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetch),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kTeal))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.wifi_off, color: kSage, size: 36),
                      const SizedBox(height: 8),
                      Text(_error!, style: const TextStyle(color: kSage),
                          textAlign: TextAlign.center),
                      TextButton(
                          onPressed: _fetch,
                          child: const Text('Retry',
                              style: TextStyle(color: kTeal))),
                    ],
                  ))
              : _donations.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inbox_outlined,
                              color: kSage, size: 48),
                          SizedBox(height: 12),
                          Text('You have no donations yet',
                              style: TextStyle(
                                  color: kSage, fontSize: 14)),
                        ],
                      ))
                  : RefreshIndicator(
                      color: kTeal,
                      onRefresh: _fetch,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _donations.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 12),
                        itemBuilder: (_, i) =>
                            _buildCard(_donations[i]),
                      ),
                    ),
      bottomNavigationBar: const SharedBottomNav(currentIndex: 4),
    );
  }

  Widget _buildCard(Map<String, dynamic> d) {
    const base   = 'https://gasp-test-production.up.railway.app/';
    final photo  = d['photoUrl'] as String?;
    final status = d['status'] ?? 'available';
    final urgent = d['isUrgent'] == true;
    final statusColor = status == 'available' ? Colors.green : kTerra;

    return Container(
      decoration: BoxDecoration(
          color: kWhite, borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        // Photo
        ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            bottomLeft: Radius.circular(16),
          ),
          child: SizedBox(
            width: 110, height: 120,
            child: photo != null && photo.isNotEmpty
                ? Image.network(
                    photo.startsWith('http') ? photo : '$base$photo',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: kSage,
                      child: const Icon(Icons.fastfood,
                          color: kWhite, size: 32),
                    ),
                  )
                : Container(
                    color: kSage,
                    child: const Icon(Icons.fastfood,
                        color: kWhite, size: 32)),
          ),
        ),

        // Info + actions
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(d['title'] ?? '',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87)),
                  ),
                  if (urgent)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                          color: kTerra,
                          borderRadius: BorderRadius.circular(6)),
                      child: const Text('URGENT',
                          style: TextStyle(
                              fontSize: 9,
                              color: kWhite,
                              fontWeight: FontWeight.bold)),
                    ),
                ]),
                const SizedBox(height: 4),
                Row(children: [
                  Icon(Icons.circle, size: 7, color: statusColor),
                  const SizedBox(width: 4),
                  Text(status,
                      style: TextStyle(
                          fontSize: 11, color: statusColor)),
                ]),
                const SizedBox(height: 2),
                Text(d['category'] ?? '',
                    style: const TextStyle(
                        fontSize: 11, color: kSage)),
                const SizedBox(height: 10),

                // Actions
                Row(children: [
                  _btn('Reservations', kTeal,
                      () => _showReservations(d)),
                  const SizedBox(width: 6),
                  _btn('Edit', kTerra, () => _openEdit(d),
                      icon: Icons.edit_outlined),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => _delete(d['id']),
                    child: Container(
                      width: 30, height: 30,
                      decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.delete_outline,
                          color: Colors.red, size: 16),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  Widget _btn(String label, Color color, VoidCallback onTap,
      {IconData? icon}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(20)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[
              Icon(icon, color: kWhite, size: 11),
              const SizedBox(width: 3),
            ],
            Text(label,
                style: const TextStyle(
                    color: kWhite,
                    fontSize: 10,
                    fontWeight: FontWeight.w600)),
          ]),
        ),
      );
}

// ── Edit Donation Screen ───────────────────────────────────────────────────────
class EditDonationScreen extends StatefulWidget {
  final Map<String, dynamic> donation;
  const EditDonationScreen({super.key, required this.donation});

  @override
  State<EditDonationScreen> createState() => _EditDonationScreenState();
}

class _EditDonationScreenState extends State<EditDonationScreen> {
  static const String baseUrl =
      'https://gasp-test-production.up.railway.app/api/v1';

  late final TextEditingController _titleController;
  late final TextEditingController _quantityController;
  late final TextEditingController _addressController;
  late final TextEditingController _descriptionController;

  String?   _selectedCategory;
  String    _pickupTypeKey = 'Home';
  bool      _isUrgent   = false;
  DateTime? _expiresAt;
  bool      _isLoading  = false;
  bool      _isLocating = false;
  double?   _latitude;
  double?   _longitude;

  Uint8List? _photoBytes;
  String?    _photoName;
  String?    _existingPhotoUrl;

  static const _pickupTypes = {
    'Home':         'home',
    'Public Place': 'public_place',
  };

  final List<Map<String, String>> _categories = [
    {'value': 'fruits_vegetables', 'label': 'Fruits & Vegetables'},
    {'value': 'dry_goods',         'label': 'Dry Goods'},
    {'value': 'cooked_meal',       'label': 'Cooked Meal'},
    {'value': 'dairy',             'label': 'Dairy'},
    {'value': 'bakery',            'label': 'Bakery'},
    {'value': 'other',             'label': 'Other'},
  ];

  @override
  void initState() {
    super.initState();
    final d = widget.donation;
    _titleController       = TextEditingController(text: d['title'] ?? '');
    _quantityController    = TextEditingController(
        text: d['quantity']?.toString() ?? '');
    _addressController     = TextEditingController(
        text: d['pickupAddress'] ?? '');
    _descriptionController = TextEditingController(
        text: d['description'] ?? '');
    _selectedCategory      = d['category'] as String?;
    _isUrgent              = d['isUrgent'] == true;
    _existingPhotoUrl      = d['photoUrl'] as String?;
    _latitude  = double.tryParse(d['latitude']?.toString() ?? '');
    _longitude = double.tryParse(d['longitude']?.toString() ?? '');

    final apiType = d['pickupType'] as String? ?? 'home';
    _pickupTypeKey = _pickupTypes.entries
        .firstWhere((e) => e.value == apiType,
            orElse: () => const MapEntry('Home', 'home'))
        .key;

    final exp = d['expiresAt'] as String?;
    if (exp != null) _expiresAt = DateTime.tryParse(exp);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _quantityController.dispose();
    _addressController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    if (kIsWeb) {
      final input = html.FileUploadInputElement()
        ..accept = 'image/*'
        ..click();
      await input.onChange.first;
      if (input.files == null || input.files!.isEmpty) return;
      final file   = input.files!.first;
      final reader = html.FileReader();
      reader.readAsArrayBuffer(file);
      await reader.onLoad.first;
      setState(() {
        _photoBytes = Uint8List.fromList(reader.result as List<int>);
        _photoName  = file.name;
      });
    }
  }

  bool get _hasNewPhoto => _photoBytes != null;
  bool get _hasPhoto =>
      _photoBytes != null ||
      (_existingPhotoUrl != null && _existingPhotoUrl!.isNotEmpty);

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiresAt ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(primary: kTeal)),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _expiresAt = picked);
  }

  String get _expiresAtDisplay {
    if (_expiresAt == null) return 'Select Date';
    return '${_expiresAt!.year}-'
        '${_expiresAt!.month.toString().padLeft(2, '0')}-'
        '${_expiresAt!.day.toString().padLeft(2, '0')}';
  }

  Future<void> _detectLocation() async {
    setState(() => _isLocating = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _snack('Location permission denied');
        return;
      }
      final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium);
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?lat=${position.latitude}&lon=${position.longitude}&format=json',
      );
      final response =
          await http.get(uri, headers: {'User-Agent': 'MadadApp/1.0'});
      String address =
          '${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}';
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final dn   = json['display_name'] as String?;
        if (dn != null && dn.isNotEmpty) address = dn;
      }
      setState(() {
        _latitude  = position.latitude;
        _longitude = position.longitude;
        _addressController.text = address;
      });
    } catch (e) {
      _snack('Location failed: $e');
    } finally {
      setState(() => _isLocating = false);
    }
  }

  Future<void> _onSave() async {
    if (_titleController.text.trim().isEmpty) {
      _snack('Please enter a title'); return;
    }
    if (_selectedCategory == null) {
      _snack('Please select a category'); return;
    }
    if (_addressController.text.trim().isEmpty) {
      _snack('Please enter a pickup address'); return;
    }

    setState(() => _isLoading = true);
    try {
      final id      = widget.donation['id'] as String;
      final uri     = Uri.parse('$baseUrl/donations/$id');
      final request = http.MultipartRequest('PUT', uri);
      final token   = AppToken.get();
      if (token != null) request.headers['Authorization'] = 'Bearer $token';

      request.fields['title']         = _titleController.text.trim();
      request.fields['category']      = _selectedCategory!;
      request.fields['quantity']      = _quantityController.text.trim();
      request.fields['pickupAddress'] = _addressController.text.trim();
      request.fields['pickupType']    = _pickupTypes[_pickupTypeKey]!;
      request.fields['isUrgent']      = _isUrgent.toString();
      if (_descriptionController.text.trim().isNotEmpty) {
        request.fields['description'] = _descriptionController.text.trim();
      }
      if (_expiresAt != null) {
        request.fields['expiresAt'] = _expiresAtDisplay;
      }
      if (_latitude  != null) request.fields['latitude']  = _latitude.toString();
      if (_longitude != null) request.fields['longitude'] = _longitude.toString();
      if (_photoBytes != null) {
        request.files.add(http.MultipartFile.fromBytes(
            'photo', _photoBytes!, filename: _photoName ?? 'photo.jpg'));
      }

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);
      debugPrint('[Edit] ${response.statusCode} ${response.body}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (!mounted) return;
        Navigator.pop(context, true);
      } else {
        final b = jsonDecode(response.body);
        _snack(b['message'] ?? 'Update failed');
      }
    } catch (e) {
      _snack('Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _snack(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    const base = 'https://gasp-test-production.up.railway.app/';

    return Scaffold(
      backgroundColor: kSand,
      body: Column(children: [
        // Header
        Container(
          color: kSand,
          padding: const EdgeInsets.fromLTRB(16, 56, 16, 12),
          child: Stack(
            alignment: Alignment.center,
            children: [
              const Text('Edit Donation',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: kTeal)),
              Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.arrow_back_ios,
                      color: kTeal, size: 20),
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // Photo
                GestureDetector(
                  onTap: _pickPhoto,
                  child: Container(
                    width: double.infinity, height: 130,
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: _hasPhoto
                              ? Colors.transparent
                              : kTeal,
                          width: 1.5),
                      borderRadius: BorderRadius.circular(12),
                      color: kWhite,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: _hasNewPhoto
                          ? Image.memory(_photoBytes!,
                              fit: BoxFit.cover, width: double.infinity)
                          : (_existingPhotoUrl != null &&
                                  _existingPhotoUrl!.isNotEmpty)
                              ? Stack(fit: StackFit.expand, children: [
                                  Image.network(
                                    _existingPhotoUrl!.startsWith('http')
                                        ? _existingPhotoUrl!
                                        : '$base$_existingPhotoUrl',
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        _photoPlaceholder(),
                                  ),
                                  Container(
                                    color: Colors.black12,
                                    child: const Center(
                                      child: Icon(Icons.edit,
                                          color: kWhite, size: 28),
                                    ),
                                  ),
                                ])
                              : _photoPlaceholder(),
                    ),
                  ),
                ),

                const SizedBox(height: 16),
                _label('Title *'),
                const SizedBox(height: 6),
                _box(TextField(controller: _titleController,
                    decoration: _deco('Write A Title'))),

                const SizedBox(height: 14),
                _label('Category *'),
                const SizedBox(height: 6),
                _box(DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  hint: const Text('Select A Category',
                      style: TextStyle(color: kSage, fontSize: 13)),
                  decoration: const InputDecoration(
                    border: InputBorder.none, isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                  ),
                  items: _categories.map((c) => DropdownMenuItem(
                      value: c['value'],
                      child: Text(c['label']!))).toList(),
                  onChanged: (v) => setState(() => _selectedCategory = v),
                )),

                const SizedBox(height: 14),
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('Quantity *'),
                      const SizedBox(height: 6),
                      _box(TextField(controller: _quantityController,
                          decoration: _deco('e.g. 5 kg'))),
                    ],
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('Expiration Date'),
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: _pickDate,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 13),
                          decoration: BoxDecoration(color: kWhite,
                              borderRadius: BorderRadius.circular(10)),
                          child: Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(child: Text(_expiresAtDisplay,
                                  style: TextStyle(fontSize: 12,
                                      color: _expiresAt == null
                                          ? kSage : Colors.black87),
                                  overflow: TextOverflow.ellipsis)),
                              const Icon(Icons.keyboard_arrow_down,
                                  color: kSage, size: 20),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )),
                ]),

                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(color: kWhite,
                      borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('Mark As Urgent', style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600,
                              color: Colors.black87)),
                          SizedBox(height: 2),
                          Text('Donation needed immediately',
                              style: TextStyle(fontSize: 11, color: kSage)),
                        ],
                      ),
                      Switch(value: _isUrgent, activeColor: kTerra,
                          onChanged: (v) => setState(() => _isUrgent = v)),
                    ],
                  ),
                ),

                const SizedBox(height: 14),
                _label('Pickup Address *'),
                const SizedBox(height: 6),
                _box(Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        GestureDetector(
                          onTap: _isLocating ? null : _detectLocation,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                                color: _isLocating ? kSage : kTerra,
                                borderRadius: BorderRadius.circular(20)),
                            child: _isLocating
                                ? const SizedBox(width: 14, height: 14,
                                    child: CircularProgressIndicator(
                                        color: kWhite, strokeWidth: 2))
                                : const Text('Locate Me', style: TextStyle(
                                    color: kWhite, fontSize: 12,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: TextField(
                          controller: _addressController,
                          style: const TextStyle(
                              fontSize: 13, color: Colors.black87),
                          decoration: const InputDecoration(
                            hintText: 'Or type your address…',
                            hintStyle: TextStyle(color: kSage, fontSize: 12),
                            border: InputBorder.none, isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        )),
                      ]),
                      if (_latitude != null && _longitude != null) ...[
                        const SizedBox(height: 6),
                        Row(children: [
                          const Icon(Icons.location_on,
                              size: 12, color: kTeal),
                          const SizedBox(width: 4),
                          Text(
                            'lat: ${_latitude!.toStringAsFixed(5)}, '
                            'lng: ${_longitude!.toStringAsFixed(5)}',
                            style: const TextStyle(
                                fontSize: 11, color: kTeal),
                          ),
                        ]),
                      ],
                    ],
                  ),
                )),

                const SizedBox(height: 14),
                _label('Pickup Type *'),
                const SizedBox(height: 8),
                Row(children: [
                  _pickupToggle('Home'),
                  const SizedBox(width: 24),
                  _pickupToggle('Public Place'),
                ]),

                const SizedBox(height: 14),
                _label('About Your Donation'),
                const SizedBox(height: 6),
                _box(TextField(
                  controller: _descriptionController,
                  maxLines: 3,
                  decoration: _deco('Describe Your Donation'),
                )),

                const SizedBox(height: 28),

                Center(
                  child: SizedBox(
                    width: 200, height: 50,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kTerra,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30)),
                        elevation: 0,
                      ),
                      onPressed: _isLoading ? null : _onSave,
                      icon: _isLoading
                          ? const SizedBox(width: 18, height: 18,
                              child: CircularProgressIndicator(
                                  color: kWhite, strokeWidth: 2))
                          : const Icon(Icons.check, color: kWhite, size: 20),
                      label: const Text('Save Changes',
                          style: TextStyle(fontSize: 15,
                              fontWeight: FontWeight.bold, color: kWhite)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ]),
      bottomNavigationBar: const SharedBottomNav(currentIndex: 4),
    );
  }

  Widget _photoPlaceholder() => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.add_photo_alternate_outlined, color: kTeal, size: 36),
          SizedBox(height: 8),
          Text('Tap to change photo',
              style: TextStyle(fontSize: 12, color: kTeal)),
        ],
      );

  Widget _label(String t) => Text(t,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
          color: Colors.black87));

  Widget _box(Widget child) => Container(
      decoration: BoxDecoration(color: kWhite,
          borderRadius: BorderRadius.circular(10)),
      child: child);

  InputDecoration _deco(String hint) => InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: kSage, fontSize: 13),
      border: InputBorder.none, isDense: true,
      contentPadding: const EdgeInsets.symmetric(
          horizontal: 14, vertical: 14));

  Widget _pickupToggle(String label) {
    final bool active = _pickupTypeKey == label;
    return GestureDetector(
      onTap: () => setState(() => _pickupTypeKey = label),
      child: Row(children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 36, height: 20,
          decoration: BoxDecoration(
              color: active ? kTeal : const Color(0xFFD0D0D0),
              borderRadius: BorderRadius.circular(10)),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 200),
            alignment: active
                ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.all(2),
              width: 16, height: 16,
              decoration: const BoxDecoration(
                  color: kWhite, shape: BoxShape.circle),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 13,
            color: active ? kTeal : kSage,
            fontWeight: active
                ? FontWeight.w600 : FontWeight.normal)),
      ]),
    );
  }
}

// ── Reservations bottom sheet ──────────────────────────────────────────────────
class _ReservationsSheet extends StatefulWidget {
  final Map<String, dynamic> donation;
  final Map<String, String>  headers;
  final String               baseUrl;
  const _ReservationsSheet({
    required this.donation,
    required this.headers,
    required this.baseUrl,
  });

  @override
  State<_ReservationsSheet> createState() => _ReservationsSheetState();
}

class _ReservationsSheetState extends State<_ReservationsSheet> {
  List<Map<String, dynamic>> _reservations = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final id  = widget.donation['id'];
      final res = await http.get(
        Uri.parse('${widget.baseUrl}/donations/$id/reservations'),
        headers: widget.headers,
      );
      debugPrint('[Reservations] ${res.statusCode} ${res.body}');
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final data = body['data'];
      List list  = [];
      if (data is List) list = data;
      if (data is Map && data['reservations'] is List) {
        list = data['reservations'];
      }
      setState(() {
        _reservations = List<Map<String, dynamic>>.from(list);
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _accept(String id) async {
    await http.patch(
        Uri.parse('${widget.baseUrl}/reservations/$id/accept'),
        headers: widget.headers);
    _fetch();
  }

  Future<void> _decline(String id) async {
    await http.patch(
        Uri.parse('${widget.baseUrl}/reservations/$id/decline'),
        headers: widget.headers);
    _fetch();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4,
            decoration: BoxDecoration(color: kSage,
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),
        Text('Reservations for "${widget.donation['title']}"',
            style: const TextStyle(fontSize: 15,
                fontWeight: FontWeight.bold, color: kTeal)),
        const SizedBox(height: 16),
        if (_loading)
          const Padding(padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(color: kTeal))
        else if (_reservations.isEmpty)
          const Padding(padding: EdgeInsets.all(24),
              child: Text('No reservations yet',
                  style: TextStyle(color: kSage)))
        else
          ConstrainedBox(
            constraints: BoxConstraints(
                maxHeight:
                    MediaQuery.of(context).size.height * 0.5),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _reservations.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: Color(0xFFEEEEEE)),
              itemBuilder: (_, i) => _tile(_reservations[i]),
            ),
          ),
      ]),
    );
  }

  Widget _tile(Map<String, dynamic> r) {
    final requester = r['requester'] ?? r['user'] ?? {};
    final name      = requester['name'] ?? 'Unknown';
    final status    = r['status'] ?? 'pending';
    final isPending = status == 'pending';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: kSage.withOpacity(0.3),
          child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(
                  color: kTeal, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: const TextStyle(fontSize: 13,
                fontWeight: FontWeight.w600, color: Colors.black87)),
            Text(status, style: TextStyle(fontSize: 11,
                color: isPending ? kTerra : Colors.green)),
          ],
        )),
        if (isPending) ...[
          GestureDetector(
            onTap: () => _accept(r['id']),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: Colors.green,
                  borderRadius: BorderRadius.circular(20)),
              child: const Text('Accept', style: TextStyle(
                  color: kWhite, fontSize: 11,
                  fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _decline(r['id']),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: kTerra,
                  borderRadius: BorderRadius.circular(20)),
              child: const Text('Decline', style: TextStyle(
                  color: kWhite, fontSize: 11,
                  fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ]),
    );
  }
}