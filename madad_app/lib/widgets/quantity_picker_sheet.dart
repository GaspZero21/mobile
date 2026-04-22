import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/colors.dart';

/// Shows a bottom sheet that lets the user pick how much to reserve.
///
/// [totalQuantity]  – raw string from the donation, e.g. "5 kg"
/// [remainingQty]   – how much is still available
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
  State<_QuantityPickerSheet> createState() =>
      _QuantityPickerSheetState();
}

class _QuantityPickerSheetState
    extends State<_QuantityPickerSheet> {
  late double _value;
  late double _max;
  late final TextEditingController _ctrl;
  final _formKey = GlobalKey<FormState>();

  // Extract unit label from "5 kg" → "kg"
  String get _unit {
    final parts =
        widget.totalQuantity.trim().split(RegExp(r'\s+'));
    return parts.length >= 2 ? parts.sublist(1).join(' ') : '';
  }

  double _parseNum(String raw) {
    final m = RegExp(r'[\d.]+').firstMatch(raw);
    return m != null
        ? double.tryParse(m.group(0)!) ?? 1.0
        : 1.0;
  }

  String _fmt(double v) => v == v.roundToDouble()
      ? v.toInt().toString()
      : v.toStringAsFixed(1);

  @override
  void initState() {
    super.initState();
    _max = widget.remainingQty ??
        _parseNum(widget.totalQuantity);
    if (_max <= 0) _max = 1.0;
    _value = 1.0.clamp(0.01, _max);
    _ctrl = TextEditingController(text: _fmt(_value));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _setQty(double v) {
    final clamped = v.clamp(0.01, _max);
    setState(() {
      _value = clamped;
      _ctrl.text = _fmt(clamped);
      _ctrl.selection =
          TextSelection.collapsed(offset: _ctrl.text.length);
    });
  }

  void _increment() => _setQty(_value + 1);
  void _decrement() => _setQty(_value - 1);

  @override
  Widget build(BuildContext context) {
    final pct = (_value / _max).clamp(0.0, 1.0);
    Color barColor = kTeal;
    if (pct > 0.9) barColor = Colors.red;
    else if (pct > 0.6) barColor = Colors.orange;

    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding:
            const EdgeInsets.fromLTRB(24, 14, 24, 28),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Drag handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: const Color(0xFFDDDDDD),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),

              // ── Title
              const Text(
                'How much do you want to reserve?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),

              // ── Info row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Total: ${_fmt(_parseNum(widget.totalQuantity))}${_unit.isNotEmpty ? ' $_unit' : ''}',
                    style: const TextStyle(
                        fontSize: 12, color: kSage),
                  ),
                  if (widget.remainingQty != null) ...[
                    const Text('  •  ',
                        style: TextStyle(color: kSage)),
                    Text(
                      'Available: ${_fmt(widget.remainingQty!)}${_unit.isNotEmpty ? ' $_unit' : ''}',
                      style: const TextStyle(
                          fontSize: 12,
                          color: Colors.green,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 20),

              // ── Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: pct,
                  minHeight: 8,
                  backgroundColor: const Color(0xFFE8E3DA),
                  valueColor:
                      AlwaysStoppedAnimation<Color>(barColor),
                ),
              ),
              const SizedBox(height: 20),

              // ── Stepper row  (−  |  text field  |  +)
              Row(
                children: [
                  _stepBtn(
                    icon: Icons.remove,
                    onTap: _value > 1 ? _decrement : null,
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12),
                      child: TextFormField(
                        controller: _ctrl,
                        keyboardType:
                            const TextInputType.numberWithOptions(
                                decimal: true),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'[\d.]')),
                        ],
                        decoration: InputDecoration(
                          suffixText: _unit.isNotEmpty
                              ? _unit
                              : null,
                          suffixStyle: const TextStyle(
                              fontSize: 14, color: kSage),
                          contentPadding:
                              const EdgeInsets.symmetric(
                                  vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(14),
                            borderSide: const BorderSide(
                                color: kSage),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(14),
                            borderSide: const BorderSide(
                                color: kTeal, width: 2),
                          ),
                          filled: true,
                          fillColor:
                              const Color(0xFFF7F7F5),
                        ),
                        validator: (v) {
                          final parsed = double.tryParse(
                              v?.trim() ?? '');
                          if (parsed == null || parsed <= 0) {
                            return 'Enter a valid number';
                          }
                          if (parsed > _max) {
                            return 'Max is ${_fmt(_max)}';
                          }
                          return null;
                        },
                        onChanged: (v) {
                          final parsed =
                              double.tryParse(v.trim());
                          if (parsed != null &&
                              parsed > 0 &&
                              parsed <= _max) {
                            setState(() => _value = parsed);
                          }
                        },
                      ),
                    ),
                  ),
                  _stepBtn(
                    icon: Icons.add,
                    onTap:
                        _value < _max ? _increment : null,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Quick-pick chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final frac in [0.25, 0.5, 0.75, 1.0])
                      Padding(
                        padding:
                            const EdgeInsets.only(right: 8),
                        child: _quickChip(frac),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── Confirm button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kTerra,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(20)),
                  ),
                  onPressed: () {
                    if (!_formKey.currentState!.validate()) {
                      return;
                    }
                    final val =
                        double.tryParse(_ctrl.text.trim()) ??
                            _value;
                    Navigator.pop(
                        context, val.clamp(0.01, _max));
                  },
                  child: Text(
                    'Reserve ${_fmt(_value)}${_unit.isNotEmpty ? ' $_unit' : ' unit${_value == 1 ? '' : 's'}'}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepBtn(
      {required IconData icon, VoidCallback? onTap}) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: enabled ? kTeal : const Color(0xFFE8E3DA),
          shape: BoxShape.circle,
        ),
        child: Icon(icon,
            color: enabled ? Colors.white : kSage,
            size: 22),
      ),
    );
  }

  Widget _quickChip(double fraction) {
    final val = (_max * fraction).clamp(0.01, _max);
    final label = fraction == 1.0
        ? 'All'
        : '${(fraction * 100).toInt()}%';
    final isActive = (_value - val).abs() < 0.01;

    return GestureDetector(
      onTap: () => _setQty(val),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isActive
              ? kTeal
              : kTeal.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isActive
                  ? kTeal
                  : kTeal.withOpacity(0.3)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isActive ? Colors.white : kTeal,
          ),
        ),
      ),
    );
  }
}