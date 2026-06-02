import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../services/cotisation_service.dart';
import '../widgets/shared_bottom_nav.dart';

class CotisationsScreen extends StatefulWidget {
  const CotisationsScreen({super.key});

  @override
  State<CotisationsScreen> createState() => _CotisationsScreenState();
}

class _CotisationsScreenState extends State<CotisationsScreen> {
  List<Map<String, dynamic>> _cotisations = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchCotisations();
  }

  Future<void> _fetchCotisations() async {
    setState(() => _isLoading = true);
    try {
      final data = await CotisationService().getCotisations();
      if (mounted) {
        setState(() {
          _cotisations = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _contribute(String cotisationId, double amount, String? note) async {
    try {
      await CotisationService().contribute(
        id: cotisationId,      // ← Fixed: named parameter
        quantity: amount,      // ← Fixed: named parameter
        note: note,            // ← Fixed: named parameter
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Contribution recorded successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        _fetchCotisations(); // Refresh list
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSand,
      appBar: AppBar(
        title: const Text('Cotisations & Events'),
        backgroundColor: kTeal,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kTeal))
          : _error != null
              ? Center(child: Text('Error: $_error'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _cotisations.length,
                  itemBuilder: (context, index) {
                    final c = _cotisations[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c['title'] ?? 'Untitled Event',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              c['description'] ?? '',
                              style: TextStyle(color: kSage),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Target: ${c['targetQuantity'] ?? ''} ${c['quantityUnit'] ?? 'kg'}'),
                                Text(
                                  'Collected: ${c['collectedQuantity'] ?? '0'}',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: () => _showContributeDialog(c['id'] ?? ''),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                              child: const Text('Participate / Contribute'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      bottomNavigationBar: const SharedBottomNav(currentIndex: 2),
    );
  }

  void _showContributeDialog(String cotisationId) {
    final qtyController = TextEditingController();
    final noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Contribute'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: qtyController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Quantity (e.g. 5)'),
            ),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(labelText: 'Note (optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final qty = double.tryParse(qtyController.text);
              if (qty != null && qty > 0) {
                Navigator.pop(ctx);
                _contribute(cotisationId, qty, noteController.text);
              }
            },
            child: const Text('Contribute'),
          ),
        ],
      ),
    );
  }
}