import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../theme/colors.dart';
import '../widgets/shared_bottom_nav.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSand,
      body: SingleChildScrollView(
        child: Column(
          children: [

            // ── HEADER
            Container(
              width: double.infinity,
              color: kTeal,
              padding: const EdgeInsets.fromLTRB(20, 55, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(
                    child: Text(
                      'Sidi Belabbas, Algeria',
                      style: TextStyle(fontSize: 13, color: kWhite),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Welcome Mohamed !',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: kWhite,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: kWhite,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 16),
                        const Expanded(
                          child: TextField(
                            decoration: InputDecoration(
                              hintText: 'Search For Food',
                              hintStyle: TextStyle(color: kSage, fontSize: 14),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(vertical: 8),
                            ),
                          ),
                        ),
                        Container(
                          width: 50,
                          height: 50,
                          decoration: const BoxDecoration(
                            color: kTerra,
                            borderRadius: BorderRadius.only(
                              topRight: Radius.circular(30),
                              bottomRight: Radius.circular(30),
                            ),
                          ),
                          child: const Icon(Icons.search, color: kWhite, size: 22),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── BODY
            Container(
              color: kSand,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // Live Map
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    decoration: BoxDecoration(
                      color: kWhite,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.fromLTRB(16, 14, 16, 8),
                          child: Text(
                            'Live Map',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: kTeal,
                            ),
                          ),
                        ),
                        ClipRRect(
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(16),
                            bottomRight: Radius.circular(16),
                          ),
                          child: SizedBox(
                            height: 165,
                            child: FlutterMap(
                              options: const MapOptions(
                                initialCenter: LatLng(35.1897, 0.6456),
                                initialZoom: 14,
                              ),
                              children: [
                                TileLayer(
                                  urlTemplate:
                                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                  userAgentPackageName: 'com.madad.app',
                                ),
                                const MarkerLayer(
                                  markers: [
                                    Marker(
                                      point: LatLng(35.1897, 0.6456),
                                      width: 40,
                                      height: 40,
                                      child: Icon(Icons.location_on,
                                          color: kTerra, size: 36),
                                    ),
                                    Marker(
                                      point: LatLng(35.1920, 0.6480),
                                      width: 40,
                                      height: 40,
                                      child: Icon(Icons.location_on,
                                          color: Colors.green, size: 36),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Nearby Donations
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 18, 16, 10),
                    child: Text(
                      'Nearby Donations',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: kTeal,
                      ),
                    ),
                  ),

                  SizedBox(
                    height: 230,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        _buildDonationCard(
                          name: 'Tomatos',
                          distance: '500m',
                          time: '2h Ago',
                          status: 'Available',
                          statusColor: Colors.green,
                        ),
                        const SizedBox(width: 12),
                        _buildDonationCard(
                          name: 'Variety',
                          distance: '1.2km',
                          time: '30min',
                          status: 'Reserved',
                          statusColor: kTerra,
                        ),
                        const SizedBox(width: 12),
                        _buildDonationCard(
                          name: 'Carrot',
                          distance: '800m',
                          time: '1h Ago',
                          status: 'Available',
                          statusColor: Colors.green,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Post button
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kTerra,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () {},
                        icon: const Icon(Icons.add_circle_outline,
                            color: kWhite, size: 22),
                        label: const Text(
                          'Post A New Donation',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: kWhite,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Stats
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: kWhite,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Your Activities Statistics',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: kTeal,
                            ),
                          ),
                          const SizedBox(height: 18),
                          _buildStat('Donations', 583, kTeal, 0.9),
                          const SizedBox(height: 14),
                          _buildStat('Requests', 43, kTerra, 0.2),
                          const SizedBox(height: 14),
                          _buildStat('Food Saved', 312, kTerra, 0.55, suffix: ' Kg'),
                          const SizedBox(height: 14),
                          _buildReputation(),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),

      // ── SHARED BOTTOM NAV (index 0 = Home)
      bottomNavigationBar: const SharedBottomNav(currentIndex: 0),
    );
  }

  Widget _buildDonationCard({
    required String name,
    required String distance,
    required String time,
    required String status,
    required Color statusColor,
  }) {
    return Container(
      width: 125,
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(14),
              topRight: Radius.circular(14),
            ),
            child: Container(
              height: 95,
              width: 125,
              color: kSage,
              child: const Icon(Icons.fastfood, color: kWhite, size: 32),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.circle, size: 6, color: kSage),
                    const SizedBox(width: 4),
                    Text(name,
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87)),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(Icons.circle, size: 6, color: kSage),
                    const SizedBox(width: 4),
                    Text('$distance | $time',
                        style: const TextStyle(fontSize: 10, color: kSage)),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(Icons.circle, size: 6, color: statusColor),
                    const SizedBox(width: 4),
                    Text(status,
                        style: TextStyle(fontSize: 10, color: statusColor)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 28,
                        decoration: BoxDecoration(
                          color: kTerra,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Center(
                          child: Text('Reserve',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: kWhite,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: kTerra,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(Icons.delete_outline,
                          color: kWhite, size: 14),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String label, int value, Color color, double ratio,
      {String suffix = ''}) {
    return Row(
      children: [
        SizedBox(
          width: 85,
          child: Text(label,
              style: const TextStyle(fontSize: 13, color: Colors.black87)),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: ratio,
              backgroundColor: const Color(0xFFE0E0E0),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 9,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text('$value$suffix',
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.black87)),
      ],
    );
  }

  Widget _buildReputation() {
    return Row(
      children: [
        const SizedBox(
          width: 85,
          child: Text('Reputtion',
              style: TextStyle(fontSize: 13, color: Colors.black87)),
        ),
        Row(
          children: List.generate(
            4,
            (index) => const Icon(Icons.star, color: Colors.amber, size: 20),
          ),
        ),
      ],
    );
  }
}