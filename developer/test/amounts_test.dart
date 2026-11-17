import 'package:flutter_test/flutter_test.dart';
import 'package:fridge_mate/amounts.dart';
import 'package:fridge_mate/scan_service.dart';

void main() {
  test('formatAmount shows whole numbers and decimals cleanly', () {
    expect(formatAmount(2, 'pcs'), '2 pcs');
    expect(formatAmount(2.0, 'kg'), '2 kg');
    expect(formatAmount(1.5, 'kg'), '1.5 kg');
    expect(formatAmount(0.25, 'L'), '0.25 L');
    expect(formatAmount(0.1 + 0.2, 'kg'), '0.3 kg');
  });

  test('parseAmount accepts dots and commas, rejects text', () {
    expect(parseAmount('1.5'), 1.5);
    expect(parseAmount('1,5'), 1.5);
    expect(parseAmount(' 500 '), 500);
    expect(parseAmount(''), isNull);
    expect(parseAmount('abc'), isNull);
  });

  test('steps and quick-use amounts follow the unit', () {
    expect(stepFor('pcs'), 1);
    expect(stepFor('g'), 100);
    expect(stepFor('kg'), 0.5);
    expect(quickUseFor('ml'), [50, 100, 250, 500]);
  });

  test('older documents without a unit read as pcs', () {
    expect(unitOf({'quantity': 3}), 'pcs');
    expect(unitOf({'quantity': 3, 'unit': 'kg'}), 'kg');
    expect(unitOf({'unit': 'bogus'}), 'pcs');
    expect(quantityOf({'quantity': 1.5}), 1.5);
    expect(quantityOf({}), isNull);
  });

  test('scanner keeps weights and units from the model', () {
    final raw = parseDetections('''
      {"items": [
        {"name": "Chicken", "category": "Meat & Chicken", "quantity": 1.25, "unit": "kg", "confidence": 0.9},
        {"name": "Eggs", "category": "Eggs", "quantity": 1, "unit": "pack", "confidence": 0.9},
        {"name": "Apples", "category": "Fruits", "quantity": 4, "unit": "boxes", "confidence": 0.9}
      ]}''');
    final r = crossCheck(raw, const []).detections;
    final chicken = r.firstWhere((d) => d.name == 'Chicken');
    expect(chicken.quantity, 1.25);
    expect(chicken.unit, 'kg');
    expect(r.firstWhere((d) => d.name == 'Eggs').unit, 'pack');
    expect(r.firstWhere((d) => d.name == 'Apples').unit, 'pcs'); // unknown unit
  });
}
