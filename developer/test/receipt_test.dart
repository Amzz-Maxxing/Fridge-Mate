import 'package:flutter_test/flutter_test.dart';
import 'package:fridge_mate/recipes.dart';
import 'package:fridge_mate/scan_service.dart';

void main() {
  final now = DateTime(2026, 11, 16, 15);

  test('parseReceiptDate accepts recent dates and rejects misreads', () {
    expect(parseReceiptDate('2026-11-14', now: now), DateTime(2026, 11, 14));
    expect(parseReceiptDate('2026-11-16', now: now), DateTime(2026, 11, 16));
    expect(parseReceiptDate('2026-11-20', now: now), isNull); // future
    expect(parseReceiptDate('2025-01-01', now: now), isNull); // too old
    expect(parseReceiptDate('14/11/2026', now: now), isNull); // wrong format
    expect(parseReceiptDate(null, now: now), isNull);
  });

  test('parseReceipt reads store, date and items', () {
    final r = parseReceipt('''
      {"store": "Mydin", "date": "2026-11-15", "items": [
        {"name": "Eggs", "category": "Eggs", "quantity": 1, "confidence": 0.95},
        {"name": "Fresh milk", "category": "Dairy", "quantity": 2, "confidence": 0.9}
      ]}''', [PantryItem('Milk', DateTime(2026, 11, 18))], now: now);
    expect(r.store, 'Mydin');
    expect(r.purchaseDate, DateTime(2026, 11, 15));
    expect(r.detections.map((d) => d.name), containsAll(['Eggs', 'Fresh milk']));
    final milk = r.detections.firstWhere((d) => d.name == 'Fresh milk');
    expect(milk.existing?.name, 'Milk');
  });

  test('parseReceipt copes with a missing store and date', () {
    final r = parseReceipt('{"items": []}', const [], now: now);
    expect(r.store, isNull);
    expect(r.purchaseDate, isNull);
    expect(r.detections, isEmpty);
  });

  test('namesMatch links receipt items to grocery list entries', () {
    expect(namesMatch('Fresh milk', ['Milk', 'susu']), isTrue);
    expect(namesMatch('Eggs', ['Eggs', 'telur']), isTrue);
    expect(namesMatch('Chicken', ['Chicken wings']), isTrue);
    expect(namesMatch('Bread', ['Butter']), isFalse);
  });
}
