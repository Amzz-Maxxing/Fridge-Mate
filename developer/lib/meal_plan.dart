// Weekly meal planning. Pure logic only, so it can be tested:
// week maths, auto-planning and the weekly shopping list. Plans are stored
// as users/{uid}/mealPlans/{weekStart} with a `meals` map keyed by
// "yyyy-mm-dd|slot".

import 'amounts.dart';
import 'recipes.dart';

enum MealSlot {
  breakfast('Breakfast'),
  lunch('Lunch'),
  dinner('Dinner');

  final String label;
  const MealSlot(this.label);
}

/// One planned meal.
class PlanEntry {
  final String recipeId;
  final int servings;
  const PlanEntry(this.recipeId, this.servings);

  Map<String, dynamic> toMap() => {'recipeId': recipeId, 'servings': servings};

  static PlanEntry? fromMap(Object? m) {
    if (m is! Map || m['recipeId'] is! String) return null;
    final s = m['servings'];
    return PlanEntry(m['recipeId'] as String, s is num ? s.round() : 2);
  }
}

DateTime _date(DateTime d) => DateTime(d.year, d.month, d.day);

/// Monday of the week containing [d].
DateTime weekStart(DateTime d) =>
    _date(d).subtract(Duration(days: d.weekday - DateTime.monday));

/// "2026-11-16".
String dayKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Key of one meal in a week's `meals` map: "2026-11-16|dinner".
String entryKey(DateTime day, MealSlot slot) => '${dayKey(day)}|${slot.name}';

/// The seven days of the week starting at [start].
List<DateTime> weekDays(DateTime start) =>
    [for (var i = 0; i < 7; i++) _date(start).add(Duration(days: i))];

/// Fills the empty [slots] of the week with recipes, expiry first.
///
/// Days are planned in order. For each day the fridge is scored as it will
/// be on that day (so food that has expired by then no longer counts), and
/// once a meal is chosen its fridge ingredients are treated as used, so
/// later meals lean on other food. Recipes aren't repeated within the week.
/// Days before [now] are left alone. Returns only the new entries.
Map<String, PlanEntry> autoPlan({
  required DateTime start,
  required List<MealSlot> slots,
  required Map<String, PlanEntry> existing,
  required List<PantryItem> pantry,
  required List<Recipe> recipes,
  Diet? diet,
  int? maxMinutes,
  int servings = 2,
  DateTime? now,
}) {
  final today = _date(now ?? DateTime.now());
  var remaining = List.of(pantry);
  final used = existing.values.map((e) => e.recipeId).toSet();
  final candidates = recipes
      .where((r) => !r.aiGenerated)
      .where((r) => diet == null || r.diet.suits(diet))
      .where((r) => maxMinutes == null || r.minutes <= maxMinutes)
      .toList();

  final added = <String, PlanEntry>{};
  for (final day in weekDays(start)) {
    if (day.isBefore(today)) continue;
    for (final slot in slots) {
      final key = entryKey(day, slot);
      if (existing.containsKey(key)) continue;

      RecipeSuggestion? best;
      var bestScore = -1.0;
      for (final r in candidates) {
        if (used.contains(r.id)) continue;
        final s = evaluateRecipe(r, remaining, now: day);
        // Planning rule: food that would go off by tomorrow must be used
        // today, so recipes that use it jump ahead of everything else.
        final rescues = s.matches.any((m) => m.have && m.daysLeft! <= 1);
        final score = s.score + (rescues ? 1 : 0);
        if (best == null ||
            score > bestScore ||
            (score == bestScore && s.missingCount < best.missingCount)) {
          best = s;
          bestScore = score;
        }
      }
      if (best == null) continue; // ran out of recipes

      added[key] = PlanEntry(best.recipe.id, servings);
      used.add(best.recipe.id);
      final consumed = {for (final m in best.matches) ...m.usable};
      remaining = remaining.where((p) => !consumed.contains(p)).toList();
    }
  }
  return added;
}

/// Something to buy for the week's meals.
typedef ShoppingNeed = ({
  String name,
  num quantity,
  String unit,
  List<String> keywords,
});

/// Totals every planned meal's ingredients (scaled to its servings), takes
/// off what's already in the fridge, and returns what's left to buy.
///
/// Amounts in comparable units are added together (500 g + 1 kg = 1.5 kg).
/// If a matching fridge item has no amount recorded, the ingredient is
/// assumed to be covered.
List<ShoppingNeed> weeklyShopping(
  Iterable<PlanEntry> entries,
  Map<String, Recipe> recipesById,
  List<PantryItem> pantry, {
  DateTime? now,
}) {
  final today = _date(now ?? DateTime.now());
  final usable = pantry.where((p) => p.daysLeft(today) >= 0).toList();

  // Sum the needs per ingredient.
  final totals = <String, ({Ingredient ing, num amount})>{};
  for (final e in entries) {
    final r = recipesById[e.recipeId];
    if (r == null) continue;
    final factor = e.servings / r.servings;
    for (final ing in r.ingredients) {
      final a = ing.amount;
      if (a == null) continue;
      final scaled = a * factor;
      final k = ing.label.toLowerCase();
      final prev = totals[k];
      if (prev == null) {
        totals[k] = (ing: ing, amount: scaled);
        continue;
      }
      final c = convertAmount(scaled, ing.unit, prev.ing.unit);
      if (c != null) {
        totals[k] = (ing: prev.ing, amount: prev.amount + c);
      } else {
        // Units that don't compare (e.g. pcs vs g) stay separate.
        final k2 = '$k|${ing.unit}';
        final p2 = totals[k2];
        totals[k2] = (ing: ing, amount: (p2?.amount ?? 0) + scaled);
      }
    }
  }

  final out = <ShoppingNeed>[];
  for (final t in totals.values) {
    final matching = usable
        .where((p) => matchesKeyword(p.name, t.ing.keywords))
        .toList();
    if (matching.any((p) => p.quantity == null)) continue; // assume covered
    num have = 0;
    for (final p in matching) {
      have += convertAmount(p.quantity!, p.unit, t.ing.unit) ?? 0;
    }
    final short = t.amount - have;
    if (short <= 0) continue;
    out.add((
      name: t.ing.label,
      quantity: niceAmount(short, t.ing.unit),
      unit: t.ing.unit,
      keywords: t.ing.keywords,
    ));
  }
  out.sort((a, b) => a.name.compareTo(b.name));
  return out;
}
