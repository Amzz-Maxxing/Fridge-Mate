// AI meal ideas: asks Gemini for simple recipes built around what's in the
// fridge (soonest-expiring first), including combinations the recipe
// database doesn't cover. Results use the same Recipe model, so fridge
// matching, servings scaling and "add to grocery list" all work on them.

import 'dart:convert';

import 'package:firebase_ai/firebase_ai.dart';
import 'ai_service.dart';
import 'amounts.dart';
import 'recipes.dart';

const List<String> _diets = ['meat', 'pescatarian', 'vegetarian', 'vegan'];

final _schema = Schema.object(properties: {
  'recipes': Schema.array(
    items: Schema.object(
      properties: {
        'name': Schema.string(),
        'origin': Schema.string(
            description: 'Cuisine, e.g. Malay, Chinese, Indian, Italian.'),
        'diet': Schema.enumString(enumValues: _diets),
        'minutes': Schema.integer(),
        'servings': Schema.integer(),
        'ingredients': Schema.array(
          items: Schema.object(properties: {
            'name': Schema.string(),
            'amount': Schema.number(),
            'unit': Schema.enumString(enumValues: units),
            'keywords': Schema.array(
                items: Schema.string(),
                description: 'Lower-case English and Malay names.'),
          }),
        ),
        'staples': Schema.array(
          items: Schema.object(
            properties: {
              'name': Schema.string(),
              'amount': Schema.number(),
              'unit': Schema.string(description: 'tbsp, tsp, cloves, g...'),
            },
            optionalProperties: ['amount', 'unit'],
          ),
        ),
        'steps': Schema.array(items: Schema.string()),
      },
    ),
  ),
});

/// Builds the prompt. Kept separate so it can be checked in tests.
String mealIdeasPrompt(List<PantryItem> pantry,
    {Diet? diet, int? maxMinutes, int count = 3, DateTime? now}) {
  final n = now ?? DateTime.now();
  final today = DateTime(n.year, n.month, n.day);
  final usable = pantry.where((p) => p.daysLeft(today) >= 0).toList()
    ..sort((a, b) => a.expiry.compareTo(b.expiry));
  final lines = usable.map((p) {
    final d = p.daysLeft(today);
    final when = d == 0
        ? 'expires today'
        : d == 1
            ? 'expires tomorrow'
            : 'expires in $d days';
    final amt = p.quantity == null ? '' : ', ${formatAmount(p.quantity!, p.unit)}';
    return '- ${p.name}$amt ($when)';
  }).join('\n');

  final dietRule = switch (diet) {
    null => '',
    Diet.vegan => '- Every recipe must be vegan (no meat, fish, eggs, dairy or honey).\n',
    Diet.vegetarian => '- Every recipe must be vegetarian (no meat or fish).\n',
    Diet.pescatarian => '- No meat; fish and seafood are fine.\n',
    Diet.meat => '',
  };
  final timeRule =
      maxMinutes == null ? '' : '- Each recipe must take $maxMinutes minutes or less.\n';

  return '''
You are a home-cooking assistant for a household in Malaysia.
Suggest $count different, simple meals they can cook mostly from what is in
their fridge, using the items that expire soonest first. Creative or unusual
combinations are welcome, as long as they taste good and are realistic.

Fridge (soonest-expiring first):
$lines

Rules:
- Halal only: no pork, lard, or alcohol (no wine, beer or mirin).
$dietRule$timeRule- Use mainly fridge items; add at most 2 extra ingredients the user may need to buy.
- When you use a fridge item, set the ingredient name to exactly the fridge name above.
- Amounts are for the stated servings. Units must be one of: ${units.join(', ')}.
- keywords: 2–4 lower-case names for each ingredient, English and Malay
  (e.g. "egg", "telur").
- Put cooking basics (oil, salt, sugar, soy sauce, garlic, spices) under
  staples, not ingredients.
- 3 to 7 short, clear steps.
- origin is the cuisine the dish is closest to.
Return JSON only.''';
}

/// Turns Gemini's JSON into recipes. Skips anything incomplete and fixes
/// small problems (unknown units, missing keywords).
List<Recipe> parseMealIdeas(String json, {String idPrefix = 'ai'}) {
  final decoded = jsonDecode(json);
  final list = decoded is Map ? decoded['recipes'] : decoded;
  if (list is! List) return const [];

  final out = <Recipe>[];
  for (var i = 0; i < list.length; i++) {
    final r = list[i];
    if (r is! Map) continue;
    final name = '${r['name'] ?? ''}'.trim();
    final steps = (r['steps'] is List)
        ? (r['steps'] as List).map((s) => '$s'.trim()).where((s) => s.isNotEmpty).toList()
        : <String>[];

    final ingredients = <Ingredient>[];
    if (r['ingredients'] is List) {
      for (final ing in r['ingredients'] as List) {
        if (ing is! Map) continue;
        final label = '${ing['name'] ?? ''}'.trim();
        if (label.isEmpty) continue;
        final kws = <String>{
          label.toLowerCase(),
          if (ing['keywords'] is List)
            for (final k in ing['keywords'] as List)
              if ('$k'.trim().isNotEmpty) '$k'.trim().toLowerCase(),
        }.toList();
        final amount = ing['amount'] is num && (ing['amount'] as num) > 0
            ? roundAmount(ing['amount'] as num)
            : null;
        final unit = units.contains(ing['unit']) ? ing['unit'] as String : defaultUnit;
        ingredients.add(Ingredient(label, kws, amount: amount, unit: unit));
      }
    }

    final staples = <Staple>[];
    if (r['staples'] is List) {
      for (final s in r['staples'] as List) {
        if (s is! Map) continue;
        final sName = '${s['name'] ?? ''}'.trim();
        if (sName.isEmpty) continue;
        final a = s['amount'];
        staples.add(Staple(sName, a is num && a > 0 ? roundAmount(a) : null,
            '${s['unit'] ?? ''}'.trim()));
      }
    }

    if (name.isEmpty || ingredients.isEmpty || steps.isEmpty) continue;
    final minutes = (r['minutes'] as num?)?.round() ?? 30;
    final servings = (r['servings'] as num?)?.round() ?? 2;
    out.add(Recipe(
      id: '${idPrefix}_$i',
      name: name,
      origin: '${r['origin'] ?? ''}'.trim().isEmpty ? 'AI idea' : '${r['origin']}'.trim(),
      diet: Diet.values.firstWhere((d) => d.name == r['diet'],
          orElse: () => Diet.meat),
      minutes: minutes.clamp(1, 600),
      servings: servings.clamp(1, 12),
      ingredients: ingredients,
      staples: staples,
      steps: steps,
      aiGenerated: true,
    ));
  }
  return out;
}

/// Asks Gemini for [count] meal ideas from the fridge.
Future<List<Recipe>> generateMealIdeas(
  List<PantryItem> pantry, {
  Diet? diet,
  int? maxMinutes,
  int count = 3,
}) async {
  if (pantry.isEmpty) {
    throw const AiException('Add some items to your fridge first.');
  }
  final text = await askGemini(
    _schema,
    mealIdeasPrompt(pantry, diet: diet, maxMinutes: maxMinutes, count: count),
    timeout: const Duration(seconds: 60),
  );
  try {
    final recipes = parseMealIdeas(text,
        idPrefix: 'ai_${DateTime.now().millisecondsSinceEpoch}');
    // Respect the filters even if the model slips.
    final filtered = recipes
        .where((r) => diet == null || r.diet.suits(diet))
        .where((r) => maxMinutes == null || r.minutes <= maxMinutes)
        .toList();
    if (filtered.isEmpty) {
      throw const AiException(
          "The AI couldn't come up with ideas this time. Try again.");
    }
    return filtered;
  } on FormatException {
    throw const AiException("Couldn't read the AI's reply. Please try again.");
  }
}
