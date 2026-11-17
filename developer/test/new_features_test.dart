import 'package:flutter_test/flutter_test.dart';
import 'package:fridge_mate/ai_recipes.dart';
import 'package:fridge_mate/meal_plan.dart';
import 'package:fridge_mate/notification_service.dart';
import 'package:fridge_mate/recipes.dart';

void main() {
  final now = DateTime(2026, 11, 16, 9); // a Monday
  DateTime inDays(int d) => DateTime(2026, 11, 16 + d);

  group('AI meal ideas', () {
    test('prompt lists fridge items soonest first and states the rules', () {
      final p = mealIdeasPrompt([
        PantryItem('Milk', inDays(5), quantity: 1, unit: 'L'),
        PantryItem('Spinach', inDays(1)),
        PantryItem('Old bread', inDays(-2)),
      ], diet: Diet.vegetarian, maxMinutes: 30, now: now);
      expect(p.indexOf('Spinach'), lessThan(p.indexOf('Milk')));
      expect(p, contains('expires tomorrow'));
      expect(p, contains('1 L'));
      expect(p, isNot(contains('Old bread'))); // expired
      expect(p, contains('Halal'));
      expect(p, contains('vegetarian'));
      expect(p, contains('30 minutes'));
    });

    test('parseMealIdeas builds usable recipes and fixes bad values', () {
      const json = '''
        {"recipes": [
          {"name": "Spinach Egg Wrap", "origin": "Fusion", "diet": "vegetarian",
           "minutes": 15, "servings": 2,
           "ingredients": [
             {"name": "Spinach", "amount": 100, "unit": "g", "keywords": ["spinach", "bayam"]},
             {"name": "Eggs", "amount": 3, "unit": "dozen", "keywords": []}
           ],
           "staples": [{"name": "Salt"}, {"name": "Oil", "amount": 1, "unit": "tbsp"}],
           "steps": ["Wilt the spinach.", "Add the eggs."]},
          {"name": "", "ingredients": [], "steps": []}
        ]}''';
      final recipes = parseMealIdeas(json, idPrefix: 'ai_test');
      expect(recipes, hasLength(1));
      final r = recipes.single;
      expect(r.aiGenerated, isTrue);
      expect(r.id, 'ai_test_0');
      expect(r.diet, Diet.vegetarian);
      expect(r.ingredients[0].keywords, containsAll(['spinach', 'bayam']));
      expect(r.ingredients[1].unit, 'pcs'); // "dozen" isn't a known unit
      expect(r.ingredients[1].keywords, ['eggs']); // falls back to the name
      expect(r.staples.first.amount, isNull);
      // It matches the fridge like any other recipe.
      final s = evaluateRecipe(r, [PantryItem('Bayam', inDays(1))], now: now);
      expect(s.haveCount, 1);
    });
  });

  group('Expiry notification tips', () {
    test('recipesUsing returns recipes that contain the item', () {
      final pantry = [PantryItem('Spinach', inDays(1))];
      final tips = recipesUsing('Spinach', pantry, now: now);
      expect(tips, isNotEmpty);
      expect(tips.length, lessThanOrEqualTo(3));
      for (final r in tips) {
        expect(r.ingredients.any((i) => matchesKeyword('Spinach', i.keywords)),
            isTrue,
            reason: r.name);
      }
    });

    test('reminder text includes up to three recipe names', () {
      expect(
        NotificationService.reminderBody('Spinach', 'expires tomorrow',
            ['Palak Paneer', 'Frittata', 'Japchae']),
        'Spinach expires tomorrow. Try: Palak Paneer, Frittata or Japchae.',
      );
      expect(NotificationService.reminderBody('Kale', 'expires today', []),
          'Kale expires today. Use it or lose it!');
    });
  });

  group('Meal planning', () {
    test('week maths', () {
      expect(weekStart(DateTime(2026, 11, 19)), DateTime(2026, 11, 16));
      expect(weekStart(DateTime(2026, 11, 22)), DateTime(2026, 11, 16));
      expect(dayKey(DateTime(2026, 1, 5)), '2026-01-05');
      expect(entryKey(DateTime(2026, 11, 16), MealSlot.dinner),
          '2026-11-16|dinner');
      expect(weekDays(DateTime(2026, 11, 16)), hasLength(7));
    });

    test('autoPlan fills empty slots, keeps existing ones, never repeats', () {
      final existing = {
        entryKey(DateTime(2026, 11, 16), MealSlot.dinner):
            const PlanEntry('nasi_lemak', 2),
      };
      final added = autoPlan(
        start: DateTime(2026, 11, 16),
        slots: [MealSlot.lunch, MealSlot.dinner],
        existing: existing,
        pantry: [
          PantryItem('Spinach', inDays(0)),
          PantryItem('Chicken', inDays(2)),
          PantryItem('Eggs', inDays(10)),
        ],
        recipes: recipeDatabase,
        now: now,
      );
      expect(added, hasLength(13)); // 14 slots minus 1 already planned
      expect(added.containsKey(existing.keys.first), isFalse);
      final ids = added.values.map((e) => e.recipeId).toList();
      expect(ids.toSet().length, ids.length);
      expect(ids, isNot(contains('nasi_lemak')));
      // Monday lunch should use the spinach that expires today.
      final monLunch = added[entryKey(DateTime(2026, 11, 16), MealSlot.lunch)]!;
      final r = recipeDatabase.firstWhere((r) => r.id == monLunch.recipeId);
      expect(r.ingredients.any((i) => matchesKeyword('Spinach', i.keywords)),
          isTrue,
          reason: r.name);
    });

    test('autoPlan respects diet and time limits and skips past days', () {
      final added = autoPlan(
        start: DateTime(2026, 11, 16),
        slots: [MealSlot.dinner],
        existing: const {},
        pantry: const [],
        recipes: recipeDatabase,
        diet: Diet.vegan,
        maxMinutes: 30,
        now: DateTime(2026, 11, 19), // Thursday
      );
      expect(added, hasLength(4)); // Thu–Sun
      for (final e in added.values) {
        final r = recipeDatabase.firstWhere((r) => r.id == e.recipeId);
        expect(r.diet, Diet.vegan);
        expect(r.minutes, lessThanOrEqualTo(30));
      }
    });

    test('weeklyShopping totals across meals and subtracts the fridge', () {
      final byId = {for (final r in recipeDatabase) r.id: r};
      // Ayam Masak Kicap (600 g chicken for 3) at 3 servings, plus
      // Chicken Stir-Fry (300 g for 2) at 2 servings = 900 g chicken.
      final needs = weeklyShopping(
        const [
          PlanEntry('ayam_masak_kicap', 3),
          PlanEntry('chicken_stir_fry', 2),
        ],
        byId,
        [PantryItem('Chicken', inDays(3), quantity: 0.5, unit: 'kg')],
        now: now,
      );
      final chicken = needs.firstWhere((n) => n.name == 'Chicken');
      expect(chicken.quantity, 400);
      expect(chicken.unit, 'g');
      expect(chicken.keywords, contains('ayam'));
    });
  });
}
