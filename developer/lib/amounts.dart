// Amounts and units shared by the fridge, scanner, grocery list and saved
// lists. Quantities may be decimals (1.5 kg); counts use "pcs" or "pack".

import 'package:flutter/material.dart';

const List<String> units = ['pcs', 'pack', 'g', 'kg', 'ml', 'L'];

/// Unit used when an item has none saved (older items were plain counts).
const String defaultUnit = 'pcs';

/// How much one tap of + or − changes an amount in this unit.
num stepFor(String unit) => switch (unit) {
      'g' || 'ml' => 100,
      'kg' || 'L' => 0.5,
      _ => 1,
    };

/// Quick "use some" amounts offered for a unit, smallest first.
List<num> quickUseFor(String unit) => switch (unit) {
      'g' || 'ml' => [50, 100, 250, 500],
      'kg' || 'L' => [0.25, 0.5, 1],
      _ => [1, 2, 3],
    };

/// Rounds away floating-point noise (0.1 + 0.2) to 2 decimal places.
num roundAmount(num n) {
  final r = (n * 100).round() / 100;
  return r == r.roundToDouble() ? r.toInt() : r;
}

/// 2 → "2", 1.5 → "1.5", 0.25 → "0.25".
String formatNumber(num n) {
  final r = roundAmount(n);
  if (r is int) return '$r';
  return r
      .toStringAsFixed(2)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}

/// 2, "pcs" → "2 pcs"; 500, "g" → "500 g".
String formatAmount(num quantity, String unit) =>
    '${formatNumber(quantity)} $unit';

/// Converts an amount between units of the same kind: g ↔ kg, ml ↔ L, or
/// the same unit. Null when they can't be compared (pcs vs g, pack vs pcs).
num? convertAmount(num amount, String from, String to) {
  if (from == to) return amount;
  const toBase = {'g': 1, 'kg': 1000, 'ml': 1, 'L': 1000};
  const family = {'g': 'mass', 'kg': 'mass', 'ml': 'vol', 'L': 'vol'};
  if (family[from] == null || family[from] != family[to]) return null;
  return roundAmount(amount * toBase[from]! / toBase[to]!);
}

/// Rounds a scaled amount to something you'd actually measure: whole or
/// half items, 5 g/ml under 100 and 10 g/ml above, 0.05 kg/L, and halves
/// of spoons and cloves.
num niceAmount(num amount, String unit) {
  num roundTo(num step) {
    final r = (amount / step).round() * step;
    return roundAmount(r < step ? step : r);
  }

  return switch (unit) {
    'g' || 'ml' => amount >= 100 ? roundTo(10) : roundTo(5),
    'kg' || 'L' => roundTo(0.05),
    'tsp' => roundTo(0.25),
    _ => roundTo(0.5), // pcs, pack, tbsp, cloves...
  };
}

/// [amount] × [factor], rounded with [niceAmount].
num scaleAmount(num amount, String unit, double factor) =>
    factor == 1 ? amount : niceAmount(amount * factor, unit);

/// Reads "1,5" or "1.5". Null if it isn't a number.
num? parseAmount(String text) {
  final t = text.trim().replaceAll(',', '.');
  if (t.isEmpty) return null;
  final n = num.tryParse(t);
  return n == null ? null : roundAmount(n);
}

/// The unit stored on a Firestore document, or [defaultUnit].
String unitOf(Map<String, dynamic> d) {
  final u = d['unit'];
  return units.contains(u) ? u as String : defaultUnit;
}

/// The quantity stored on a Firestore document, or null if none.
num? quantityOf(Map<String, dynamic> d) {
  final q = d['quantity'];
  return q is num ? q : null;
}

/// Amount text box with a unit dropdown beside it.
class AmountField extends StatelessWidget {
  final TextEditingController controller;
  final String unit;
  final ValueChanged<String> onUnitChanged;
  final String label;
  final String? hint;

  const AmountField({
    super.key,
    required this.controller,
    required this.unit,
    required this.onUnitChanged,
    this.label = 'Amount',
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: label,
              hintText: hint,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 104,
          child: DropdownButtonFormField<String>(
            initialValue: unit,
            decoration: const InputDecoration(
              labelText: 'Unit',
            ),
            items: units
                .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                .toList(),
            onChanged: (v) {
              if (v != null) onUnitChanged(v);
            },
          ),
        ),
      ],
    );
  }
}
