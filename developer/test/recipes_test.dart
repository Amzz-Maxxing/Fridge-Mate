import 'package:flutter_test/flutter_test.dart';
import 'package:fridge_mate/recipes.dart';

void main() {
  final now = DateTime(2026, 11, 16, 12);
  DateTime inDays(int d) => DateTime(2026, 11, 16 + d);

  test('keywords match whole words, plurals and Malay names', () {
    expect(matchesKeyword('Eggs', ['egg']), isTrue);
    expect(matchesKeyword('Telur ayam', ['telur']), isTrue);
    expect(matchesKeyword('Chicken breast', ['chicken']), isTrue);
    expect(matchesKeyword('Eggplant', ['egg']), isFalse);
    expect(matchesKeyword('Coconut milk', ['milk']), isTrue);
  });

  test('recipes using soon-to-expire food rank first', () {
    final pantry = [
      PantryItem('Eggs', inDays(10)),
      PantryItem('Tomatoes', inDays(0)),
      PantryItem('Chicken', inDays(9)),
    ];
    final results = suggestRecipes(pantry, now: now);
    bool usesTomatoes(RecipeSuggestion s) =>
        s.matches.any((m) => m.have && m.item!.name == 'Tomatoes');

    // The top suggestion uses the tomatoes that expire today...
    expect(usesTomatoes(results.first), isTrue);
    // ...and Tomato Egg (2 of 3, with the expiring tomatoes) beats Oyakodon
    // (2 of 5, nothing expiring soon).
    final ids = results.map((s) => s.recipe.id).toList();
    expect(ids.indexOf('tomato_egg'), lessThan(ids.indexOf('oyakodon')));
  });

  test('expired items do not count as owned', () {
    final results = suggestRecipes(
      [PantryItem('Bananas', inDays(-2))],
      now: now,
    );
    expect(results, isEmpty);
  });

  test('findInStock matches both ways and ignores expired items', () {
    final pantry = [
      PantryItem('Milk', inDays(3)),
      PantryItem('Telur ayam', inDays(5)),
      PantryItem('Bread', inDays(-1)),
    ];
    expect(findInStock(pantry, ['Fresh milk'], now: now)?.name, 'Milk');
    expect(findInStock(pantry, ['egg', 'telur'], now: now)?.name, 'Telur ayam');
    expect(findInStock(pantry, ['Bread'], now: now), isNull);
    expect(findInStock(pantry, ['Butter'], now: now), isNull);
  });

  test('recipes with no owned ingredients are hidden', () {
    final results = suggestRecipes([PantryItem('Tuna', inDays(5))], now: now);
    // Only tuna recipes appear, and each one uses the tuna.
    expect(results, isNotEmpty);
    for (final s in results) {
      expect(s.haveCount, 1, reason: s.recipe.id);
      expect(s.matches.any((m) => m.ingredient.label == 'Canned tuna'), isTrue,
          reason: s.recipe.id);
    }
    expect(results.map((r) => r.recipe.id), contains('tuna_sandwich'));
  });
}
