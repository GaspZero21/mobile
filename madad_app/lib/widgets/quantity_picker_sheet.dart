import 'package:flutter/material.dart';
import '../theme/colors.dart';

/// Shows a bottom sheet that lets the user pick how much to reserve.
///
/// [totalQuantity]  – raw string from the donation, e.g. "5 kg"
/// [remainingQty]   – how much is still available (shown as info, not as max)
///
/// Returns the chosen [double] or null if the user cancelled.
Future<double?> showQuantityPickerSheet(
  BuildContext context, {
  required String totalQuantity,
  required double? remainingQty,
}) {
  return showModalBottomSheet<double>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _QuantityPickerSheet(
      totalQuantity: totalQuantity,
      remainingQty: remainingQty,
    ),
  );
}

class _QuantityPickerSheet extends StatefulWidget {
  final String totalQuantity;
  final double? remainingQty;

  const _QuantityPickerSheet({
    required this.totalQuantity,
    required this.remainingQty,
  });

  @override
  State<_QuantityPickerSheet> createState() => _QuantityPickerSheetState();
}

class _QuantityPickerSheetState extends State<_QuantityPickerSheet> {
  late double _value;
  late double _max; // ← always based on TOTAL, not remaining

  // Extract unit label from "5 kg" → "kg"
  String get _unit {
    final parts = widget.totalQuantity.trim().split(RegExp(r'\s+'));
    return parts.length >= 2 ? parts.sublist(1).join(' ') : '';
  }

  double _parseNum(String raw) {
    final m = RegExp(r'[\d.]+').firstMatch(raw);
    return m != null ? double.tryParse(m.group(0)!) ?? 1.0 : 1.0;
  }

  @override
  void initState() {
    super.initState();
    // ── FIXED: max = total quantity, not remaining ─────────────────────
    _max = _parseNum(widget.totalQuantity);
    if (_max <= 0) _max = 1.0;
    // Start at 1 step (never 0)
    _value = _max >= 1.0 ? 1.0 : _max;
  }

  bool get _useDecimals => _max <= 10;
  double get _step => _useDecimals ? 0.5 : 1.0;
  int get _divisions => ((_max / _step).round()).clamp(1, 200);

  String _fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final remaining = widget.remainingQty;
    final pct = _max > 0 ? (_value / _max) : 1.0;
    final Color sliderColor = pct > 0.7
        ? Colors.green
        : pct > 0.3
            ? kTeal
            : Colors.orange;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFDDDDDD),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          const Text(
            'How much do you want to reserve?',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold,
                color: Colors.black87),
          ),
          const SizedBox(height: 6),

          // Total + remaining info
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Total: ${_fmt(_max)}${_unit.isNotEmpty ? ' $_unit' : ''}',
                style: const TextStyle(fontSize: 12, color: kSage),
              ),
              if (remaining != null) ...[
                const Text('  •  ', style: TextStyle(color: kSage)),
                Text(
                  'Still available: ${_fmt(remaining)}${_unit.isNotEmpty ? ' $_unit' : ''}',
                  style: const TextStyle(fontSize: 12, color: Colors.green,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ],
          ),

          const SizedBox(height: 24),

          // Big quantity display
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              color: kTeal.withOpacity(0.06),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Text(
                  _fmt(_value),
                  style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold,
                      color: sliderColor),
                ),
                if (_unit.isNotEmpty)
                  Text(_unit,
                      style: const TextStyle(fontSize: 18, color: kSage,
                          fontWeight: FontWeight.w500)),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Slider — min is one step, max is TOTAL quantity
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: sliderColor,
              thumbColor: sliderColor,
              inactiveTrackColor: const Color(0xFFDDDDDD),
              overlayColor: sliderColor.withOpacity(0.15),
              trackHeight: 6,
            ),
            child: Slider(
              value: _value,
              min: _step,
              max: _max,
              divisions: _divisions,
              onChanged: (v) => setState(() => _value = v),
            ),
          ),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${_fmt(_step)}${_unit.isNotEmpty ? ' $_unit' : ''}',
                  style: const TextStyle(fontSize: 11, color: kSage)),
              Text('${_fmt(_max)}${_unit.isNotEmpty ? ' $_unit' : ''} (all)',
                  style: const TextStyle(fontSize: 11, color: kSage)),
            ],
          ),

          const SizedBox(height: 20),

          // Quick-select buttons
          if (_max >= 2) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final frac in [0.25, 0.5, 0.75, 1.0])
                  _quickBtn(frac),
              ],
            ),
            const SizedBox(height: 20),
          ],

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: kTerra),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel',
                      style: TextStyle(color: kTerra,
                          fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kTerra, elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                  ),
                  onPressed: () {
                    final qty = _value > 0 ? _value : _step;
                    Navigator.pop(context, qty);
                  },
                  child: Text(
                    'Reserve ${_fmt(_value)}${_unit.isNotEmpty ? ' $_unit' : ''}',
                    style: const TextStyle(color: Colors.white,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _quickBtn(double fraction) {
    final raw     = _max * fraction;
    final snapped = ((raw / _step).round() * _step).clamp(_step, _max);
    final label   = fraction == 1.0 ? 'All' : '${(fraction * 100).toInt()}%';
    final isActive = (_value - snapped).abs() < 0.001;

    return GestureDetector(
      onTap: () => setState(() => _value = snapped),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isActive ? kTeal : kTeal.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isActive ? kTeal : kTeal.withOpacity(0.3)),
        ),
        child: Text(label,
            style: TextStyle(fontSize: 12,
                color: isActive ? Colors.white : kTeal,
                fontWeight: FontWeight.w600)),
      ),
    );
  }
}