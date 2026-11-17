import 'package:flutter_test/flutter_test.dart';
import 'package:fridge_mate/amounts.dart';
import 'package:fridge_mate/recipes.dart';

void main() {
  final now = DateTime(2026, 11, 16, 12);
  DateTime inDays(int d) => DateTime(2026, 11, 16 + d);

  test('convertAmount handles g/kg and ml/L, refuses mixed kinds', () {
    expect(convertAmount(1.5, 'kg', 'g'), 1500);
    expect(convertAmount(250, 'ml', 'L'), 0.25);
    expect(convertAmount(3, 'pcs', 'pcs'), 3);
    expect(convertAmount(500, 'g', 'ml'), isNull);
    expect(convertAmount(1, 'pack', 'g'), isNull);
  });

  test('scaled amounts are rounded to sensible measures', () {
    expect(scaleAmount(400, 'g', 1.5), 600);
    expect(scaleAmount(30, 'g', 0.5), 15);
    expect(scaleAmount(3, 'pcs', 0.5), 1.5);
    expect(scaleAmount(1, 'pcs', 0.5), 0.5);
    expect(scaleAmount(0.5, 'tsp', 1 / 3), 0.25);
    expect(scaleAmount(200, 'ml', 4 / 3), 270);
  });

  test('every recipe ingredient has an amount in a grocery-list unit', () {
    for (final r in recipeDatabase) {
      for (final i in r.ingredients) {
        expect(i.amount, isNotNull, reason: '${r.name}: ${i.label}');
        expect(units, contains(i.unit), reason: '${r.name}: ${i.label}');
      }
    }
  });

  RecipeSuggestion suggestion(String id, List<PantryItem> pantry) =>
      suggestRecipes(pantry, now: now).firstWhere((s) => s.recipe.id == id);

  test('shortBy reports what is missing, converting kg to g', () {
    // Ayam Masak Kicap needs 600 g chicken for 3 servings.
    final s = suggestion('ayam_masak_kicap', [
      PantryItem('Chicken', inDays(2), quantity: 0.4, unit: 'kg'),
    ]);
    final chicken = s.matches.firstWhere((m) => m.ingredient.label == 'Chicken');
    expect(chicken.haveAmount, 400);
    expect(chicken.shortBy(1), 200);
    expect(chicken.shortBy(2 / 3), 0); // 2 servings need 400 g
  });

  test('shortBy adds up several matching items', () {
    final s = suggestion('telur_dadar', [
      PantryItem('Eggs', inDays(10), quantity: 2),
      PantryItem('Telur kampung', inDays(5), quantity: 3),
    ]);
    final eggs = s.matches.firstWhere((m) => m.ingredient.label == 'Eggs');
    expect(eggs.haveAmount, 5);
    expect(eggs.shortBy(1), 0); // needs 4
    expect(eggs.shortBy(1.5), 1); // needs 6
  });

  test('shortBy is unknown when units cannot be compared', () {
    final s = suggestion('ayam_masak_kicap', [
      PantryItem('Chicken', inDays(2), quantity: 1, unit: 'pack'),
    ]);
    final chicken = s.matches.firstWhere((m) => m.ingredient.label == 'Chicken');
    expect(chicken.shortBy(1), isNull);
  });
}
