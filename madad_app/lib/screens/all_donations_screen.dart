import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../services/donation_service.dart';
import '../widgets/shared_bottom_nav.dart';

class AllDonationsScreen extends StatefulWidget {
  const AllDonationsScreen({super.key});

  @override
  State<AllDonationsScreen> createState() => _AllDonationsScreenState();
}

class _AllDonationsScreenState extends State<AllDonationsScreen> {
  static const String base = 'https://gasp-test-production.up.railway.app/';

  List<Map<String, dynamic>> _all = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _isLoading = true;
  String? _error;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetch();
    _searchCtrl.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await DonationService().getDonations();
      if (!mounted) return;
      setState(() {
        _all = data;
        _filtered = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _onSearch() {
    final q = _searchCtrl.text.toLowerCase().trim();
    setState(() {
      _filtered = q.isEmpty
          ? _all
          : _all.where((d) {
              final title = (d['title'] ?? '').toLowerCase();
              final category = (d['category'] ?? '').toLowerCase();
              final address = (d['pickupAddress'] ?? '').toLowerCase();
              return title.contains(q) ||
                  category.contains(q) ||
                  address.contains(q);
            }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSand,
      appBar: AppBar(
        backgroundColor: kTeal,
        foregroundColor: kWhite,
        title: const Text(
          'All Donations',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: kWhite,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 14),
                  const Icon(Icons.search, color: kSage, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Search by title, category…',
                        hintStyle: TextStyle(color: kSage, fontSize: 13),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
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
                  Text(_error!, style: const TextStyle(color: kSage)),
                  TextButton(
                    onPressed: _fetch,
                    child: const Text('Retry', style: TextStyle(color: kTeal)),
                  ),
                ],
              ),
            )
          : _filtered.isEmpty
          ? const Center(
              child: Text(
                'No donations found',
                style: TextStyle(color: kSage, fontSize: 14),
              ),
            )
          : RefreshIndicator(
              color: kTeal,
              onRefresh: _fetch,
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, i) => _buildCard(_filtered[i]),
              ),
            ),
      bottomNavigationBar: const SharedBottomNav(currentIndex: 0),
    );
  }

  Widget _buildCard(Map<String, dynamic> d) {
    final photo = d['photoUrl'] as String?;
    final title = d['title'] ?? 'Donation';
    final category = d['category'] ?? '';
    final status = d['status'] ?? 'available';
    final urgent = d['isUrgent'] == true;
    final address = d['pickupAddress'] ?? '';
    final donor = d['donor']?['name'] ?? '';
    final statusColor = status == 'available' ? Colors.green : kTerra;

    return Container(
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          // Photo
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              bottomLeft: Radius.circular(16),
            ),
            child: SizedBox(
              width: 100,
              height: 110,
              child: photo != null && photo.isNotEmpty
                  ? Image.network(
                      photo.startsWith('http') ? photo : '$base$photo',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: kSage,
                        child: const Icon(
                          Icons.fastfood,
                          color: kWhite,
                          size: 28,
                        ),
                      ),
                    )
                  : Container(
                      color: kSage,
                      child: const Icon(
                        Icons.fastfood,
                        color: kWhite,
                        size: 28,
                      ),
                    ),
            ),
          ),

          // Info
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title + urgent
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      if (urgent)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: kTerra,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'URGENT',
                            style: TextStyle(
                              fontSize: 9,
                              color: kWhite,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),

                  // Category
                  Text(
                    category,
                    style: const TextStyle(fontSize: 11, color: kSage),
                  ),
                  const SizedBox(height: 3),

                  // Address
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 11,
                        color: kSage,
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          address,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, color: kSage),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),

                  // Donor name
                  if (donor.isNotEmpty)
                    Row(
                      children: [
                        const Icon(
                          Icons.person_outline,
                          size: 11,
                          color: kSage,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          donor,
                          style: const TextStyle(fontSize: 11, color: kSage),
                        ),
                      ],
                    ),
                  const SizedBox(height: 8),

                  // Status + Reserve
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.circle, size: 7, color: statusColor),
                          const SizedBox(width: 4),
                          Text(
                            status,
                            style: TextStyle(fontSize: 11, color: statusColor),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: kTerra,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Reserve',
                          style: TextStyle(
                            color: kWhite,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
