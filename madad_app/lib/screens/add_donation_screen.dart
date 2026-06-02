import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:geocoding/geocoding.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../theme/colors.dart';
import '../services/donation_service.dart';
import '../services/category_service.dart';
import '../widgets/shared_bottom_nav.dart';
import 'package:image_picker/image_picker.dart';

class AddDonationScreen extends StatefulWidget {
  const AddDonationScreen({super.key});

  @override
  State<AddDonationScreen> createState() => _AddDonationScreenState();
}

class _AddDonationScreenState extends State<AddDonationScreen> {
  final _titleController = TextEditingController();
  final _addressController = TextEditingController();
  final _quantityController = TextEditingController();
  final _descriptionController = TextEditingController();

  Uint8List? _photoBytes;
  File? _photoFile;
  String? _photoName;

  String? _selectedCategory;
  DateTime? _expiresAt;
  bool _isUrgent = false;
  double? _latitude;
  double? _longitude;

  bool _isLoading = false;
  bool _isLocating = false;
  bool _isGeocoding = false;

  Timer? _debounce;
  static const _debounceDuration = Duration(milliseconds: 700);

  List<Map<String, String>> _categories = [];
  bool _categoriesLoading = true;

  static const _units = ['kg', 'g', 'L', 'mL', 'pieces', 'portions', 'bags', 'boxes'];
  String _selectedUnit = 'kg';

  static const _pickupTypes = {
    'Home': 'home',
    'Public Place': 'public_place',
  };
  String _pickupTypeKey = 'Home';

  @override
  void initState() {
    super.initState();
    _fetchCategories();
    _addressController.addListener(_onAddressChanged);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _addressController.removeListener(_onAddressChanged);
    _addressController.dispose();
    _quantityController.dispose();
    _descriptionController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _fetchCategories() async {
    try {
      final cats = await CategoryService().getCategories(includeAll: false);
      if (mounted) {
        setState(() {
          _categories = cats;
          _categoriesLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _categoriesLoading = false);
    }
  }

  // ── Address Auto Geocoding
  void _onAddressChanged() {
    _debounce?.cancel();
    final address = _addressController.text.trim();
    if (address.length < 5) {
      setState(() => _isGeocoding = false);
      return;
    }

    _debounce = Timer(_debounceDuration, () async {
      if (!mounted) return;
      setState(() => _isGeocoding = true);

      bool success = false;
      try {
        final locations = await locationFromAddress(address);
        if (locations.isNotEmpty) {
          final loc = locations.first;
          _updateLocation(loc.latitude, loc.longitude);
          success = true;
        }
      } catch (e) {
        debugPrint('Geocoding pkg failed: $e');
      }

      if (!success) {
        await _geocodeWithNominatim(address);
      }

      if (mounted) setState(() => _isGeocoding = false);
    });
  }

  void _updateLocation(double lat, double lon) {
    setState(() {
      _latitude = lat;
      _longitude = lon;
    });
  }

  Future<void> _geocodeWithNominatim(String address) async {
    final queries = ['$address, Oran, Algeria', '$address, Algeria', address];
    for (final query in queries) {
      try {
        final uri = Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=1&countrycodes=dz',
        );
        final response = await http.get(uri, headers: {'User-Agent': 'MadadApp/1.0'});
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as List<dynamic>;
          if (data.isNotEmpty) {
            final lat = double.tryParse(data[0]['lat'].toString());
            final lon = double.tryParse(data[0]['lon'].toString());
            if (lat != null && lon != null) {
              _updateLocation(lat, lon);
              return;
            }
          }
        }
      } catch (e) {
        debugPrint('Nominatim failed: $query');
      }
    }
  }

  // ── NEW: Pick Location on Map
  Future<void> _pickLocationOnMap() async {
    final selectedPoint = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(
        builder: (_) => const LocationPickerScreen(),
      ),
    );

    if (selectedPoint != null) {
      _updateLocation(selectedPoint.latitude, selectedPoint.longitude);
      
      // Reverse geocode to fill address
      setState(() => _isGeocoding = true);
      try {
        final uri = Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?lat=${selectedPoint.latitude}&lon=${selectedPoint.longitude}&format=json',
        );
        final response = await http.get(uri, headers: {'User-Agent': 'MadadApp/1.0'});
        
        if (response.statusCode == 200) {
          final json = jsonDecode(response.body) as Map<String, dynamic>;
          final displayName = json['display_name'] as String?;
          if (displayName != null) {
            _addressController.text = displayName;
          }
        }
      } catch (e) {
        debugPrint('Reverse geocoding failed: $e');
      } finally {
        if (mounted) setState(() => _isGeocoding = false);
      }
    }
  }

  // ── Photo
  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() {
      _photoBytes = bytes;
      _photoName = picked.name;
      _photoFile = null;
    });
  }

  bool get _hasPhoto => _photoBytes != null || _photoFile != null;

  // ── Date, Detect Location, Submit, etc. (unchanged)
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiresAt ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(data: Theme.of(ctx).copyWith(colorScheme: const ColorScheme.light(primary: kTeal)), child: child!),
    );
    if (picked != null) setState(() => _expiresAt = picked);
  }

  String get _expiresAtDisplay {
    if (_expiresAt == null) return 'Select Date';
    return '${_expiresAt!.year}-${_expiresAt!.month.toString().padLeft(2, '0')}-${_expiresAt!.day.toString().padLeft(2, '0')}';
  }

  String? get _expiresAtIso {
    if (_expiresAt == null) return null;
    final d = _expiresAt!;
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}T23:59:59.000Z';
  }

  Future<void> _detectLocation() async {
    setState(() => _isLocating = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        _snack('Location permission denied');
        return;
      }

      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium);
      final uri = Uri.parse('https://nominatim.openstreetmap.org/reverse?lat=${position.latitude}&lon=${position.longitude}&format=json');
      final response = await http.get(uri, headers: {'User-Agent': 'MadadApp/1.0'});

      String address = '${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}';
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final displayName = json['display_name'] as String?;
        if (displayName != null && displayName.isNotEmpty) address = displayName;
      }

      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _addressController.text = address;
      });
    } catch (e) {
      _snack('Location failed: $e');
    } finally {
      setState(() => _isLocating = false);
    }
  }

  Future<void> _onPost() async {
    if (!_hasPhoto) { _snack('Please add a photo'); return; }
    if (_titleController.text.trim().isEmpty) { _snack('Please enter a title'); return; }
    if (_selectedCategory == null) { _snack('Please select a category'); return; }
    if (_addressController.text.trim().isEmpty) { _snack('Please enter a pickup address'); return; }

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
        title: _titleController.text.trim(),
        category: _selectedCategory!,
        totalQuantity: totalQuantity,
        quantityUnit: _selectedUnit,
        pickupAddress: _addressController.text.trim(),
        pickupType: _pickupTypes[_pickupTypeKey]!,
        photoFile: _photoFile,
        photoBytes: _photoBytes,
        photoName: _photoName ?? 'photo.jpg',
        description: _descriptionController.text.trim(),
        isUrgent: _isUrgent,
        expiresAt: _expiresAtIso,
        latitude: _latitude,
        longitude: _longitude,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      _snack('Failed to post: ${e.toString().replaceFirst('Exception: ', '')}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  // ── BUILD
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSand,
      body: Column(
        children: [
          Container(
            color: kSand,
            padding: const EdgeInsets.fromLTRB(16, 56, 16, 12),
            child: const Center(child: Text('Post A New Donation', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kTeal))),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Photo, Title, Category, Quantity, Expiration, Urgent (unchanged)...

                  GestureDetector(
                    onTap: _pickPhoto,
                    child: Container(
                      width: double.infinity, height: 130,
                      decoration: BoxDecoration(
                        border: Border.all(color: _hasPhoto ? Colors.transparent : kTeal, width: 1.5),
                        borderRadius: BorderRadius.circular(12),
                        color: kWhite,
                      ),
                      child: _hasPhoto
                          ? ClipRRect(borderRadius: BorderRadius.circular(10), child: _photoBytes != null ? Image.memory(_photoBytes!, fit: BoxFit.cover) : Image.file(_photoFile!, fit: BoxFit.cover))
                          : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Container(width: 48, height: 48, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: kTeal, width: 1.5)), child: const Icon(Icons.add, color: kTeal, size: 28)),
                              const SizedBox(height: 8),
                              const Text('Add A Picture', style: TextStyle(fontSize: 13, color: kTeal, fontWeight: FontWeight.w500)),
                              const Text('* Required', style: TextStyle(fontSize: 11, color: kTerra)),
                            ]),
                    ),
                  ),

                  const SizedBox(height: 16),
                  _label('Title *'),
                  const SizedBox(height: 6),
                  _box(TextField(controller: _titleController, decoration: _deco('Write A Title'))),

                  const SizedBox(height: 14),
                  _label('Category *'),
                  const SizedBox(height: 6),
                  _box(_categoriesLoading ? const Padding(padding: EdgeInsets.all(14), child: Row(children: [SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: kTeal)), SizedBox(width: 10), Text('Loading categories…', style: TextStyle(color: kSage, fontSize: 13))])) : DropdownButtonFormField<String>(value: _selectedCategory, hint: const Text('Select A Category', style: TextStyle(color: kSage, fontSize: 13)), decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14)), items: _categories.map((c) => DropdownMenuItem(value: c['value'], child: Text('${c['emoji'] ?? ''} ${c['label'] ?? ''}'))).toList(), onChanged: (v) => setState(() => _selectedCategory = v))),

                  const SizedBox(height: 14),
                  _label('Quantity *'),
                  const SizedBox(height: 6),
                  Row(children: [
                    Expanded(flex: 3, child: _box(TextField(controller: _quantityController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: _deco('e.g. 5')))),
                    const SizedBox(width: 10),
                    Expanded(flex: 2, child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2), decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(10), border: Border.all(color: kTeal.withOpacity(0.4), width: 1.2)), child: DropdownButtonHideUnderline(child: DropdownButton<String>(value: _selectedUnit, isDense: true, items: _units.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(), onChanged: (v) => setState(() => _selectedUnit = v!))))),
                  ]),

                  const SizedBox(height: 14),
                  _label('Expiration Date'),
                  const SizedBox(height: 6),
                  GestureDetector(onTap: _pickDate, child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13), decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(10)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Expanded(child: Text(_expiresAtDisplay, style: TextStyle(color: _expiresAt == null ? kSage : Colors.black87))), const Icon(Icons.calendar_today_outlined, color: kSage, size: 18)]))),

                  const SizedBox(height: 14),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(10)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [Text('Mark As Urgent', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87)), Text('Donation needed immediately', style: TextStyle(fontSize: 11, color: kSage))]), Switch(value: _isUrgent, activeColor: kTerra, onChanged: (v) => setState(() => _isUrgent = v))])),

                  const SizedBox(height: 14),

                  // ── Pickup Address with Map Picker
                  _label('Pickup Address *'),
                  const SizedBox(height: 6),
                  _box(Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          GestureDetector(
                            onTap: _isLocating ? null : _detectLocation,
                            child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), decoration: BoxDecoration(color: _isLocating ? kSage : kTerra, borderRadius: BorderRadius.circular(20)), child: _isLocating ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: kWhite, strokeWidth: 2)) : const Text('Locate Me', style: TextStyle(color: kWhite, fontSize: 12, fontWeight: FontWeight.w600))),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: _pickLocationOnMap,
                            child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), decoration: BoxDecoration(color: kTeal, borderRadius: BorderRadius.circular(20)), child: const Text('Pick on Map', style: TextStyle(color: kWhite, fontSize: 12, fontWeight: FontWeight.w600))),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: TextField(controller: _addressController, style: const TextStyle(fontSize: 13, color: Colors.black87), decoration: const InputDecoration(hintText: 'Or type your address…', hintStyle: TextStyle(color: kSage, fontSize: 12), border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero))),
                        ]),
                        if (_isGeocoding) const Padding(padding: EdgeInsets.only(top: 8), child: Text('🔍 Finding location...', style: TextStyle(fontSize: 12, color: kTeal))),
                        if (_latitude != null && _longitude != null) ...[
                          const SizedBox(height: 6),
                          Row(children: [const Icon(Icons.location_on, size: 12, color: kTeal), const SizedBox(width: 4), Text('lat: ${_latitude!.toStringAsFixed(5)}, lng: ${_longitude!.toStringAsFixed(5)}', style: const TextStyle(fontSize: 11, color: kTeal))]),
                        ],
                      ],
                    ),
                  )),

                  const SizedBox(height: 14),
                  _label('Pickup Type *'),
                  const SizedBox(height: 8),
                  Row(children: [_pickupToggle('Home'), const SizedBox(width: 24), _pickupToggle('Public Place')]),

                  const SizedBox(height: 14),
                  _label('About Your Donation'),
                  const SizedBox(height: 6),
                  _box(TextField(controller: _descriptionController, maxLines: 3, decoration: _deco('Describe Your Donation'))),

                  const SizedBox(height: 28),
                  Center(
                    child: SizedBox(
                      width: 180,
                      height: 50,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: kTerra, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)), elevation: 0),
                        onPressed: _isLoading ? null : _onPost,
                        icon: _isLoading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: kWhite, strokeWidth: 2)) : const Icon(Icons.chevron_right, color: kWhite, size: 22),
                        label: const Text('Post', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kWhite)),
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

  Widget _label(String t) => Text(t, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87));
  Widget _box(Widget child) => Container(decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(10)), child: child);
  InputDecoration _deco(String hint) => InputDecoration(hintText: hint, hintStyle: const TextStyle(color: kSage, fontSize: 13), border: InputBorder.none, isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14));

  Widget _pickupToggle(String label) {
    final bool active = _pickupTypeKey == label;
    return GestureDetector(
      onTap: () => setState(() => _pickupTypeKey = label),
      child: Row(children: [
        AnimatedContainer(duration: const Duration(milliseconds: 200), width: 36, height: 20, decoration: BoxDecoration(color: active ? kTeal : const Color(0xFFD0D0D0), borderRadius: BorderRadius.circular(10)), child: AnimatedAlign(duration: const Duration(milliseconds: 200), alignment: active ? Alignment.centerRight : Alignment.centerLeft, child: Container(margin: const EdgeInsets.all(2), width: 16, height: 16, decoration: const BoxDecoration(color: kWhite, shape: BoxShape.circle)))),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 13, color: active ? kTeal : kSage, fontWeight: active ? FontWeight.w600 : FontWeight.normal)),
      ]),
    );
  }
}

// ── Map Picker Screen
class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({super.key});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final MapController _mapController = MapController();
  LatLng? _selectedPoint;
  static const _oranCenter = LatLng(35.6969, -0.6331);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pick Donation Location'),
        backgroundColor: kTeal,
        actions: [
          if (_selectedPoint != null)
            TextButton.icon(
              onPressed: () => Navigator.pop(context, _selectedPoint),
              icon: const Icon(Icons.check, color: Colors.white),
              label: const Text('Confirm', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: _oranCenter,
          initialZoom: 13,
          onTap: (tapPosition, point) {
            setState(() => _selectedPoint = point);
          },
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.madad.app',
          ),
          if (_selectedPoint != null)
            MarkerLayer(
              markers: [
                Marker(
                  point: _selectedPoint!,
                  width: 40,
                  height: 40,
                  child: const Icon(Icons.location_pin, size: 40, color: Colors.red),
                ),
              ],
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium);
          _mapController.move(LatLng(position.latitude, position.longitude), 15);
        },
        child: const Icon(Icons.my_location),
      ),
    );
  }
}