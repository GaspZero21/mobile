import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../services/user_service.dart';

/// Shows a bottom sheet to report a user.
/// Usage:
///   await showReportUserSheet(context, userId: '...', userName: '...');
Future<void> showReportUserSheet(
  BuildContext context, {
  required String userId,
  required String userName,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ReportSheet(userId: userId, userName: userName),
  );
}

class _ReportSheet extends StatefulWidget {
  final String userId;
  final String userName;
  const _ReportSheet({required this.userId, required this.userName});

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  static const _reasons = [
    'inappropriate_behavior',
    'fraud',
    'spam',
    'fake_donation',
    'harassment',
    'other',
  ];

  static const _reasonLabels = {
    'inappropriate_behavior': 'Inappropriate Behavior',
    'fraud':                  'Fraud',
    'spam':                   'Spam',
    'fake_donation':          'Fake Donation',
    'harassment':             'Harassment',
    'other':                  'Other',
  };

  String _selectedReason = 'inappropriate_behavior';
  final _detailsCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _detailsCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      await UserService().reportUser(
        userId: widget.userId,
        reason: _selectedReason,
        details: _detailsCtrl.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Report submitted. Thank you for helping keep the community safe.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $msg'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return SafeArea(
      top: false,
      child: Container(
      decoration: const BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(16, 16, 16, 
    16 + MediaQuery.of(context).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: kSage.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Title
          Center(
            child: Text(
              'Report "${widget.userName}"',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: kTeal,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 4),
          const Center(
            child: Text(
              'Help us keep the community safe.',
              style: TextStyle(fontSize: 12, color: kSage),
            ),
          ),
          const SizedBox(height: 20),

          // Warning notice
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.red.shade400, size: 16),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'False reports may result in action against your account.',
                    style: TextStyle(fontSize: 11, color: Colors.red),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Reason dropdown
          const Text(
            'Reason *',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F7F5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: kTeal.withOpacity(0.3)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedReason,
                isExpanded: true,
                style: const TextStyle(fontSize: 13, color: Colors.black87),
                icon: const Icon(Icons.keyboard_arrow_down, color: kSage),
                items: _reasons.map((r) {
                  return DropdownMenuItem(
                    value: r,
                    child: Text(_reasonLabels[r] ?? r),
                  );
                }).toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _selectedReason = v);
                },
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Details
          const Text(
            'Details (optional)',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF7F7F5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: kTeal.withOpacity(0.3)),
            ),
            child: TextField(
              controller: _detailsCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Describe the issue in more detail…',
                hintStyle: TextStyle(color: kSage, fontSize: 13),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.all(12),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Submit button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
              onPressed: _loading ? null : _submit,
              icon: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: kWhite,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.flag, color: kWhite, size: 18),
              label: const Text(
                'Submit Report',
                style: TextStyle(
                  color: kWhite,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    ), // Container
    ); // SafeArea
  }
}