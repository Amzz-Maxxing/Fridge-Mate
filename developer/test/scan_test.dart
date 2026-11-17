import 'package:flutter_test/flutter_test.dart';
import 'package:fridge_mate/recipes.dart';
import 'package:fridge_mate/scan_service.dart';

void main() {
  final soon = DateTime.now().add(const Duration(days: 3));
  final past = DateTime.now().subtract(const Duration(days: 3));

  test('parseDetections reads the model JSON and skips bad rows', () {
    final r = parseDetections('''
      {"items": [
        {"name": "Eggs", "category": "Eggs", "quantity": 10, "confidence": 0.9},
        {"name": "", "category": "Other"},
        {"name": "Kangkung", "confidence": 0.4}
      ]}''');
    expect(r.map((e) => e.name), ['Eggs', 'Kangkung']);
    expect(r[1].category, 'Other');
    expect(r[1].quantity, 1);
  });

  test('mergeDuplicates combines the same item from two photos', () {
    final merged = mergeDuplicates(const [
      RawDetection('Eggs', 'Eggs', 6, 0.7),
      RawDetection('egg', 'Eggs', 4, 0.9),
      RawDetection('Tomatoes', 'Vegetables', 3, 0.8),
      RawDetection('Tomato', 'Vegetables', 2, 0.6),
      RawDetection('Milk', 'Dairy', 1, 0.8),
    ]);
    expect(merged.map((d) => d.name), ['Eggs', 'Tomatoes', 'Milk']);
    expect(merged[0].quantity, 6); // higher count, not 6 + 4
    expect(merged[0].confidence, 0.9);
  });

  test('mimeTypeFor accepts common photo types and rejects others', () {
    expect(mimeTypeFor('fridge.JPG'), 'image/jpeg');
    expect(mimeTypeFor('shelf.png'), 'image/png');
    expect(mimeTypeFor('holland.avif'), isNull);
  });

  test('crossCheck boosts expected items and lists unseen ones', () {
    final pantry = [
      PantryItem('Milk', soon),
      PantryItem('Butter', soon),
      PantryItem('Old bread', past),
    ];
    final result = crossCheck([
      const RawDetection('Fresh milk', 'Dairy', 1, 0.5),
      const RawDetection('Apples', 'Fruits', 4, 0.8),
      const RawDetection('Mystery jar', 'Nonsense', 0, 0.3),
    ], pantry);

    final milk = result.detections.firstWhere((d) => d.name == 'Fresh milk');
    expect(milk.existing?.name, 'Milk');
    expect(milk.confidence, closeTo(0.65, 1e-9));
    expect(milk.lowConfidence, isFalse);

    final jar = result.detections.firstWhere((d) => d.name == 'Mystery jar');
    expect(jar.category, 'Other');
    expect(jar.quantity, 1);
    expect(jar.lowConfidence, isTrue);

    // Butter wasn't seen; expired bread isn't worth flagging.
    expect(result.notSeen.map((p) => p.name), ['Butter']);
    // Highest confidence first.
    expect(result.detections.first.name, 'Apples');
  });
}

