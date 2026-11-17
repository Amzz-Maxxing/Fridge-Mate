import 'package:flutter_test/flutter_test.dart';
import 'package:fridge_mate/recipes.dart';

void main() {
  test('recipe ids are unique and every recipe is complete', () {
    final ids = recipeDatabase.map((r) => r.id).toList();
    expect(ids.toSet().length, ids.length);
    for (final r in recipeDatabase) {
      expect(r.name, isNotEmpty);
      expect(r.origin, isNotEmpty, reason: r.id);
      expect(r.ingredients, isNotEmpty, reason: r.id);
      expect(r.steps, isNotEmpty, reason: r.id);
      expect(r.minutes, greaterThan(0), reason: r.id);
      expect(r.servings, greaterThan(0), reason: r.id);
    }
  });

  test('database is expanded across many origins', () {
    expect(recipeDatabase.length, greaterThanOrEqualTo(110));
    expect(recipeOrigins, containsAll(['Malay', 'Chinese', 'Indian', 'Italian', 'British']));
    expect(recipeOrigins.first, 'Malay'); // most recipes first
  });

  test('diet filter is inclusive: vegan suits vegetarians and pescatarians', () {
    expect(Diet.vegan.suits(Diet.vegetarian), isTrue);
    expect(Diet.vegan.suits(Diet.pescatarian), isTrue);
    expect(Diet.vegetarian.suits(Diet.pescatarian), isTrue);
    expect(Diet.pescatarian.suits(Diet.vegetarian), isFalse);
    expect(Diet.meat.suits(Diet.pescatarian), isFalse);
    expect(Diet.meat.suits(Diet.meat), isTrue);
  });

  test('each diet filter has recipes to show', () {
    for (final d in [Diet.pescatarian, Diet.vegetarian, Diet.vegan]) {
      expect(recipeDatabase.where((r) => r.diet.suits(d)), isNotEmpty,
          reason: d.label);
    }
  });

  test('evaluateRecipe works for recipes with nothing in the fridge', () {
    final s = evaluateRecipe(recipeDatabase.first, const []);
    expect(s.haveCount, 0);
    expect(s.score, 0);
  });
}
