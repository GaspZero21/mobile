import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../theme/colors.dart';
import '../services/donation_service.dart';
import '../widgets/shared_bottom_nav.dart';
import '../services/image_picker_util.dart';

import 'dart:html' as html;

class AddDonationScreen extends StatefulWidget {
  const AddDonationScreen({super.key});

  @override
  State<AddDonationScreen> createState() => _AddDonationScreenState();
}

class _AddDonationScreenState extends State<AddDonationScreen> {
  final _titleController       = TextEditingController();
  final _addressController     = TextEditingController();
  final _quantityController    = TextEditingController();
  final _descriptionController = TextEditingController();

  Uint8List? _photoBytes;
  File?      _photoFile;
  String?    _photoName;

  String?   _selectedCategory;
  DateTime? _expiresAt;
  bool      _isUrgent   = false;
  double?   _latitude;
  double?   _longitude;
  bool      _isLoading  = false;
  bool      _isLocating = false;

  static const _units = [
    'kg', 'g', 'L', 'mL', 'pieces', 'portions', 'bags', 'boxes'
  ];
  String _selectedUnit = 'kg';

  static const _pickupTypes = {
    'Home':         'home',
    'Public Place': 'public_place',
  };
  String _pickupTypeKey = 'Home';

  final List<Map<String, String>> _categories = [
    {'value': 'fruits_vegetables', 'label': 'Fruits & Vegetables'},
    {'value': 'dry_goods',         'label': 'Dry Goods'},
    {'value': 'cooked_meal',       'label': 'Cooked Meal'},
    {'value': 'dairy',             'label': 'Dairy'},
    {'value': 'bakery',            'label': 'Bakery'},
    {'value': 'other',             'label': 'Other'},
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _addressController.dispose();
    _quantityController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // ── Photo ────────────────────────────────────────────────────────────────
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
        _photoFile  = null;
      });
    }
  }

  bool get _hasPhoto => _photoBytes != null || _photoFile != null;

  // ── Date ─────────────────────────────────────────────────────────────────
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

  // Full ISO-8601 timestamp required by the API
  String? get _expiresAtIso {
    if (_expiresAt == null) return null;
    final d = _expiresAt!;
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}'
        'T23:59:59.000Z';
  }

  // ── Locate Me ────────────────────────────────────────────────────────────
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
        final json        = jsonDecode(response.body) as Map<String, dynamic>;
        final displayName = json['display_name'] as String?;
        if (displayName != null && displayName.isNotEmpty) {
          address = displayName;
        }
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

  // ── Submit ───────────────────────────────────────────────────────────────
  Future<void> _onPost() async {
    if (!_hasPhoto)                              { _snack('Please add a photo'); return; }
    if (_titleController.text.trim().isEmpty)    { _snack('Please enter a title'); return; }
    if (_selectedCategory == null)               { _snack('Please select a category'); return; }
    if (_addressController.text.trim().isEmpty)  { _snack('Please enter a pickup address'); return; }

    // Validate quantity is a valid positive number
    final qtyText = _quantityController.text.trim();
    if (qtyText.isEmpty) { _snack('Please enter quantity'); return; }
    final totalQuantity = double.tryParse(qtyText);
    if (totalQuantity == null || totalQuantity <= 0) {
      _snack('Quantity must be a positive number');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await DonationService().createDonation(
        title:         _titleController.text.trim(),
        category:      _selectedCategory!,
        totalQuantity: totalQuantity,        // ← number
        quantityUnit:  _selectedUnit,        // ← unit
        pickupAddress: _addressController.text.trim(),
        pickupType:    _pickupTypes[_pickupTypeKey]!,
        photoFile:     _photoFile,
        photoBytes:    _photoBytes,
        photoName:     _photoName ?? 'photo.jpg',
        description:   _descriptionController.text.trim(),
        isUrgent:      _isUrgent,
        expiresAt:     _expiresAtIso,
        latitude:      _latitude,
        longitude:     _longitude,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      _snack('Failed to post: $msg');
      debugPrint('[AddDonation] ERROR: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  // ── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSand,
      body: Column(
        children: [
          Container(
            color: kSand,
            padding: const EdgeInsets.fromLTRB(16, 56, 16, 12),
            child: const Center(
              child: Text('Post A New Donation',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: kTeal)),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── Photo
                  GestureDetector(
                    onTap: _pickPhoto,
                    child: Container(
                      width: double.infinity, height: 130,
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: _hasPhoto ? Colors.transparent : kTeal,
                            width: 1.5),
                        borderRadius: BorderRadius.circular(12),
                        color: kWhite,
                      ),
                      child: _hasPhoto
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: _photoBytes != null
                                  ? Image.memory(_photoBytes!,
                                      fit: BoxFit.cover,
                                      width: double.infinity)
                                  : Image.file(_photoFile!,
                                      fit: BoxFit.cover,
                                      width: double.infinity),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 48, height: 48,
                                  decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: kTeal, width: 1.5)),
                                  child: const Icon(Icons.add,
                                      color: kTeal, size: 28),
                                ),
                                const SizedBox(height: 8),
                                const Text('Add A Picture',
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: kTeal,
                                        fontWeight: FontWeight.w500)),
                                const SizedBox(height: 4),
                                const Text('* Required',
                                    style: TextStyle(
                                        fontSize: 11, color: kTerra)),
                              ],
                            ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Title
                  _label('Title *'),
                  const SizedBox(height: 6),
                  _box(TextField(
                      controller: _titleController,
                      decoration: _deco('Write A Title'))),

                  const SizedBox(height: 14),

                  // ── Category
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
                    items: _categories
                        .map((c) => DropdownMenuItem(
                            value: c['value'],
                            child: Text(c['label']!)))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedCategory = v),
                  )),

                  const SizedBox(height: 14),

                  // ── Quantity + Unit
                  _label('Quantity *'),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        flex: 3,
                        child: _box(TextField(
                          controller: _quantityController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: _deco('e.g. 5'),
                          onChanged: (_) => setState(() {}),
                        )),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 2),
                          decoration: BoxDecoration(
                              color: kWhite,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: kTeal.withOpacity(0.4),
                                  width: 1.2)),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedUnit,
                              isDense: true,
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w600),
                              icon: const Icon(Icons.keyboard_arrow_down,
                                  color: kSage, size: 20),
                              items: _units
                                  .map((u) => DropdownMenuItem(
                                      value: u, child: Text(u)))
                                  .toList(),
                              onChanged: (v) {
                                if (v != null) {
                                  setState(() => _selectedUnit = v);
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_quantityController.text.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, left: 4),
                      child: Row(children: [
                        const Icon(Icons.info_outline,
                            size: 12, color: kTeal),
                        const SizedBox(width: 4),
                        Text(
                          'totalQuantity: ${_quantityController.text.trim()}, '
                          'quantityUnit: $_selectedUnit',
                          style:
                              const TextStyle(fontSize: 10, color: kTeal),
                        ),
                      ]),
                    ),

                  const SizedBox(height: 14),

                  // ── Expiry date
                  _label('Expiration Date'),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: _pickDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 13),
                      decoration: BoxDecoration(
                          color: kWhite,
                          borderRadius: BorderRadius.circular(10)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(_expiresAtDisplay,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: _expiresAt == null
                                        ? kSage
                                        : Colors.black87),
                                overflow: TextOverflow.ellipsis),
                          ),
                          const Icon(Icons.keyboard_arrow_down,
                              color: kSage, size: 20),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ── isUrgent
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                        color: kWhite,
                        borderRadius: BorderRadius.circular(10)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text('Mark As Urgent',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87)),
                            SizedBox(height: 2),
                            Text('Donation needed immediately',
                                style:
                                    TextStyle(fontSize: 11, color: kSage)),
                          ],
                        ),
                        Switch(
                          value: _isUrgent,
                          activeColor: kTerra,
                          onChanged: (v) => setState(() => _isUrgent = v),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ── Pickup Address
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
                                  borderRadius:
                                      BorderRadius.circular(20)),
                              child: _isLocating
                                  ? const SizedBox(
                                      width: 14, height: 14,
                                      child: CircularProgressIndicator(
                                          color: kWhite, strokeWidth: 2))
                                  : const Text('Locate Me',
                                      style: TextStyle(
                                          color: kWhite,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _addressController,
                              style: const TextStyle(
                                  fontSize: 13, color: Colors.black87),
                              decoration: const InputDecoration(
                                hintText: 'Or type your address…',
                                hintStyle: TextStyle(
                                    color: kSage, fontSize: 12),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
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

                  // ── Pickup Type
                  _label('Pickup Type *'),
                  const SizedBox(height: 8),
                  Row(children: [
                    _pickupToggle('Home'),
                    const SizedBox(width: 24),
                    _pickupToggle('Public Place'),
                  ]),

                  const SizedBox(height: 14),

                  // ── Description
                  _label('About Your Donation'),
                  const SizedBox(height: 6),
                  _box(TextField(
                    controller: _descriptionController,
                    maxLines: 3,
                    decoration: _deco('Describe Your Donation'),
                  )),

                  const SizedBox(height: 28),

                  // ── Post button
                  Center(
                    child: SizedBox(
                      width: 180, height: 50,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kTerra,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30)),
                          elevation: 0,
                        ),
                        onPressed: _isLoading ? null : _onPost,
                        icon: _isLoading
                            ? const SizedBox(
                                width: 18, height: 18,
                                child: CircularProgressIndicator(
                                    color: kWhite, strokeWidth: 2))
                            : const Icon(Icons.chevron_right,
                                color: kWhite, size: 22),
                        label: const Text('Post',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: kWhite)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: const SharedBottomNav(currentIndex: 2),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  Widget _label(String t) => Text(t,
      style: const TextStyle(
          fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87));

  Widget _box(Widget child) => Container(
      decoration: BoxDecoration(
          color: kWhite, borderRadius: BorderRadius.circular(10)),
      child: child);

  InputDecoration _deco(String hint) => InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: kSage, fontSize: 13),
      border: InputBorder.none,
      isDense: true,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14));

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
            alignment:
                active ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.all(2),
              width: 16, height: 16,
              decoration: const BoxDecoration(
                  color: kWhite, shape: BoxShape.circle),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                fontSize: 13,
                color: active ? kTeal : kSage,
                fontWeight:
                    active ? FontWeight.w600 : FontWeight.normal)),
      ]),
    );
  }
}