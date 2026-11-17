// Curated recipe database and the expiry-first recommendation logic.
//
// Matching is keyword based: an inventory item named "Chicken breast" or
// "Ayam" both match the chicken ingredient. Keywords are matched as whole
// words (with simple plurals), so "egg" does not match "eggplant".

import 'amounts.dart';
import 'recipe_data.dart';

export 'recipe_data.dart' show recipeDatabase, recipeOrigins;

class Ingredient {
  /// What the user sees, e.g. "Eggs".
  final String label;

  /// Lower-case words (English and Malay) that identify this ingredient in
  /// the user's inventory.
  final List<String> keywords;

  /// How much the recipe needs for its base servings, in [unit] (one of the
  /// app's [units], so it can go straight onto the grocery list).
  final num? amount;
  final String unit;

  const Ingredient(this.label, this.keywords,
      {this.amount, this.unit = defaultUnit});

  /// The same ingredient with an amount, e.g. `_egg(2, 'pcs')`.
  Ingredient call(num amount, String unit, {String? label}) =>
      Ingredient(label ?? this.label, keywords, amount: amount, unit: unit);
}

/// A pantry staple with an optional amount. [unit] is free text here
/// (tbsp, tsp, cloves) since staples never go to the grocery list.
class Staple {
  final String name;
  final num? amount;
  final String unit;
  const Staple(this.name, [this.amount, this.unit = '']);
}

/// What a recipe contains, from least to most restrictive. A vegan dish also
/// suits vegetarians and pescatarians, and so on.
enum Diet {
  meat('Contains meat'),
  pescatarian('Pescatarian'),
  vegetarian('Vegetarian'),
  vegan('Vegan');

  final String label;
  const Diet(this.label);

  /// Whether a dish with this diet suits someone who eats [filter].
  bool suits(Diet filter) => index >= filter.index;
}

class Recipe {
  final String id;
  final String name;

  /// Where the dish comes from, e.g. 'Malay', 'Chinese', 'Italian'.
  final String origin;
  final Diet diet;
  final int minutes;
  final int servings;

  /// Ingredients that count towards the match score.
  final List<Ingredient> ingredients;

  /// Pantry staples (salt, oil, sauces) assumed to be at home. They are shown
  /// in the recipe but don't affect the score or the grocery list.
  final List<Staple> staples;
  final List<String> steps;

  /// True for recipes Gemini made up on the spot (not in the database).
  final bool aiGenerated;

  const Recipe({
    required this.id,
    required this.name,
    required this.origin,
    required this.diet,
    required this.minutes,
    required this.servings,
    required this.ingredients,
    this.staples = const [],
    required this.steps,
    this.aiGenerated = false,
  });
}

/// A single item from the user's inventory, as needed for matching.
class PantryItem {
  final String name;
  final DateTime expiry;

  /// How much is in the fridge, if known.
  final num? quantity;
  final String unit;

  const PantryItem(this.name, this.expiry,
      {this.quantity, this.unit = defaultUnit});

  int daysLeft(DateTime today) {
    final d = DateTime(expiry.year, expiry.month, expiry.day);
    return d.difference(today).inDays;
  }
}

/// How one recipe ingredient lines up with the inventory.
class IngredientMatch {
  final Ingredient ingredient;

  /// The soonest-expiring usable (not expired) item, or null if missing.
  final PantryItem? item;
  final int? daysLeft;

  /// An expired item that would have matched, so the UI can warn about it.
  final PantryItem? expiredItem;

  /// Every usable (not expired) fridge item that matches, for totting up
  /// how much the user has.
  final List<PantryItem> usable;

  const IngredientMatch(this.ingredient,
      {this.item, this.daysLeft, this.expiredItem, this.usable = const []});

  bool get have => item != null;

  /// How much the user has in total, in the ingredient's unit, counting only
  /// items whose units can be compared (500 g and 1 kg add up; a "pack" of
  /// chicken can't be compared with grams). Null if nothing comparable.
  num? get haveAmount {
    num? total;
    for (final p in usable) {
      final q = p.quantity;
      if (q == null) continue;
      final c = convertAmount(q, p.unit, ingredient.unit);
      if (c == null) continue;
      total = (total ?? 0) + c;
    }
    return total == null ? null : roundAmount(total);
  }

  /// How much more is needed when cooking at [factor] × the base servings,
  /// in the ingredient's unit. 0 when there's enough; null when it can't be
  /// worked out (no amount, or units that don't compare).
  num? shortBy(double factor) {
    final need = ingredient.amount;
    if (need == null || !have) return null;
    final got = haveAmount;
    if (got == null) return null;
    final s = scaleAmount(need, ingredient.unit, factor) - got;
    return s > 0 ? niceAmount(s, ingredient.unit) : 0;
  }
}

class RecipeSuggestion {
  final Recipe recipe;
  final List<IngredientMatch> matches;
  final double score;

  const RecipeSuggestion(this.recipe, this.matches, this.score);

  int get haveCount => matches.where((m) => m.have).length;
  int get missingCount => matches.length - haveCount;
  List<IngredientMatch> get missing => matches.where((m) => !m.have).toList();

  /// Matched ingredients that expire within [days] days.
  int expiringWithin(int days) => matches
      .where((m) => m.have && m.daysLeft! <= days)
      .length;
}

// ---------------------------------------------------------------------------
// Scoring
// ---------------------------------------------------------------------------

String _normalise(String s) =>
    ' ${s.toLowerCase().replaceAll(RegExp(r'[^a-z]+'), ' ').trim()} ';

bool matchesKeyword(String itemName, List<String> keywords) {
  final name = _normalise(itemName);
  for (final kw in keywords) {
    final k = _normalise(kw).trim();
    if (name.contains(' $k ') ||
        name.contains(' ${k}s ') ||
        name.contains(' ${k}es ')) {
      return true;
    }
  }
  return false;
}

/// Whether [name] and any of [keywords] refer to the same thing, checked both
/// ways: "Fresh milk" matches ["Milk"], and "Milk" matches ["Fresh milk"].
bool namesMatch(String name, List<String> keywords) =>
    matchesKeyword(name, keywords) ||
    keywords.any((k) => matchesKeyword(k, [name]));

/// Returns the soonest-expiring usable item in [pantry] that matches a grocery
/// entry, or null. Matches both ways, so "Fresh milk" on the list matches
/// "Milk" in the fridge and "Eggs" on the list matches "Telur ayam" via the
/// stored keywords.
PantryItem? findInStock(List<PantryItem> pantry, List<String> keywords,
    {DateTime? now}) {
  final n = now ?? DateTime.now();
  final today = DateTime(n.year, n.month, n.day);
  PantryItem? best;
  for (final item in pantry) {
    if (item.daysLeft(today) < 0) continue;
    if (namesMatch(item.name, keywords) &&
        (best == null || item.expiry.isBefore(best.expiry))) {
      best = item;
    }
  }
  return best;
}

/// Urgency of using an item: 1.0 if it expires today, falling off quickly.
double _urgency(int daysLeft) => 1 / (1 + daysLeft);

/// Matches one recipe's ingredients against the fridge and scores it.
///
/// score = 0.6 × (share of ingredients the user has)
///       + 0.4 × (how urgently those ingredients need using, capped at 1)
RecipeSuggestion evaluateRecipe(Recipe recipe, List<PantryItem> pantry,
    {DateTime? now}) {
  final n = now ?? DateTime.now();
  final today = DateTime(n.year, n.month, n.day);
  final matches = <IngredientMatch>[];
  var urgency = 0.0;

  for (final ing in recipe.ingredients) {
    PantryItem? best;
    int? bestDays;
    PantryItem? expired;
    final usable = <PantryItem>[];
    for (final item in pantry) {
      if (!matchesKeyword(item.name, ing.keywords)) continue;
      final d = item.daysLeft(today);
      if (d < 0) {
        expired ??= item;
        continue;
      }
      usable.add(item);
      if (bestDays == null || d < bestDays) {
        best = item;
        bestDays = d;
      }
    }
    if (best != null) urgency += _urgency(bestDays!);
    matches.add(IngredientMatch(ing,
        item: best, daysLeft: bestDays, expiredItem: expired, usable: usable));
  }

  final have = matches.where((m) => m.have).length;
  final coverage = matches.isEmpty ? 0.0 : have / matches.length;
  final score = 0.6 * coverage + 0.4 * (urgency > 1 ? 1 : urgency);
  return RecipeSuggestion(recipe, matches, score);
}

/// Scores every recipe against the inventory and returns those that use at
/// least one item, best first.
List<RecipeSuggestion> suggestRecipes(
  List<PantryItem> pantry, {
  DateTime? now,
  List<Recipe>? recipes,
}) {
  final results = [
    for (final recipe in recipes ?? recipeDatabase)
      evaluateRecipe(recipe, pantry, now: now),
  ].where((s) => s.haveCount > 0).toList();

  results.sort((a, b) {
    final c = b.score.compareTo(a.score);
    return c != 0 ? c : a.missingCount.compareTo(b.missingCount);
  });
  return results;
}

/// The best recipes that use [itemName], ranked by how well they fit the
/// whole fridge (and how urgently the rest of it needs using). Used for
/// expiry notifications: "Spinach expires tomorrow. Try: ...".
List<Recipe> recipesUsing(String itemName, List<PantryItem> pantry,
    {int limit = 3, DateTime? now}) {
  final using = [
    for (final r in recipeDatabase)
      if (r.ingredients.any((i) => matchesKeyword(itemName, i.keywords)))
        evaluateRecipe(r, pantry, now: now),
  ]..sort((a, b) {
      final c = b.score.compareTo(a.score);
      return c != 0 ? c : a.recipe.minutes.compareTo(b.recipe.minutes);
    });
  return using.take(limit).map((s) => s.recipe).toList();
}

/// "A", "A or B", "A, B or C".
String joinOr(List<String> names) => switch (names.length) {
      0 => '',
      1 => names.first,
      _ => '${names.sublist(0, names.length - 1).join(', ')} or ${names.last}',
    };
