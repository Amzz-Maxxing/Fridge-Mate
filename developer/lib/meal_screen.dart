import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'ai_recipes.dart';
import 'amounts.dart';
import 'favourites.dart';
import 'meal_plan_screen.dart';
import 'recipes.dart';
import 'theme.dart';

CollectionReference<Map<String, dynamic>> _userCol(String name) {
  final uid = FirebaseAuth.instance.currentUser!.uid;
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection(name);
}

/// Meals tab: "For you" ranks recipes by what's in the fridge; "All recipes"
/// lets you browse the whole database with filters.
class MealScreen extends StatelessWidget {
  const MealScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 20,
          title: const Text("Let's cook"),
          actions: [
            IconButton(
              tooltip: 'Meal plan',
              style: IconButton.styleFrom(backgroundColor: context.palette.soft),
              icon: const Icon(Icons.calendar_month),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const MealPlanScreen())),
            ),
            const SizedBox(width: 12),
          ],
          bottom: const TabBar(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
            tabs: [
              Tab(height: 40, text: 'For you'),
              Tab(height: 40, text: 'All recipes'),
              Tab(height: 40, text: 'Favourites'),
            ],
          ),
        ),
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _userCol('inventory').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final pantry = snapshot.data!.docs.map((doc) {
              final d = doc.data();
              return PantryItem(
                '${d['name']}',
                (d['expiryDate'] as Timestamp).toDate(),
                quantity: quantityOf(d),
                unit: unitOf(d),
              );
            }).toList();

            return StreamBuilder<Set<String>>(
              stream: favouriteIds(),
              builder: (context, favSnap) => _Favourites(
                ids: favSnap.data ?? const {},
                child: TabBarView(
                  children: [
                    _ForYouTab(pantry: pantry),
                    _AllRecipesTab(pantry: pantry),
                    _FavouritesTab(pantry: pantry),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Makes the user's favourite recipe ids available to every card below.
class _Favourites extends InheritedWidget {
  final Set<String> ids;
  const _Favourites({required this.ids, required super.child});

  static Set<String> of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_Favourites>()?.ids ??
      const {};

  @override
  bool updateShouldNotify(_Favourites old) =>
      old.ids.length != ids.length || !old.ids.containsAll(ids);
}

// ---------------------------------------------------------------------------
// Favourites
// ---------------------------------------------------------------------------

class _FavouritesTab extends StatelessWidget {
  final List<PantryItem> pantry;
  const _FavouritesTab({required this.pantry});

  @override
  Widget build(BuildContext context) {
    final ids = _Favourites.of(context);
    final favs =
        [
          for (final r in recipeDatabase)
            if (ids.contains(r.id)) evaluateRecipe(r, pantry),
        ]..sort((a, b) {
          // Ready-to-cook and fridge-friendly favourites first.
          final c = b.score.compareTo(a.score);
          return c != 0 ? c : a.recipe.name.compareTo(b.recipe.name);
        });

    if (favs.isEmpty) {
      return const _Empty(
        icon: Icons.favorite_border,
        text: 'No favourites yet.\nTap the ♡ on any recipe to keep it here.',
      );
    }
    final ready = favs.where((s) => s.missingCount == 0).length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
          child: Text(
            '${favs.length} favourite${favs.length == 1 ? '' : 's'}'
            '${ready > 0 ? ' · $ready ready to cook now' : ''}',
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        for (final s in favs) _SuggestionCard(s),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// For you
// ---------------------------------------------------------------------------

enum _Filter { all, ready, expiring }

class _ForYouTab extends StatefulWidget {
  final List<PantryItem> pantry;
  const _ForYouTab({required this.pantry});

  @override
  State<_ForYouTab> createState() => _ForYouTabState();
}

class _ForYouTabState extends State<_ForYouTab>
    with AutomaticKeepAliveClientMixin {
  _Filter _filter = _Filter.all;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final pantry = widget.pantry;
    final all = suggestRecipes(pantry);
    final shown = switch (_filter) {
      _Filter.all => all,
      _Filter.ready => all.where((s) => s.missingCount == 0).toList(),
      _Filter.expiring => all.where((s) => s.expiringWithin(3) > 0).toList(),
    };

    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Row(
            children: [
              _chip('All matches', _Filter.all),
              _chip('Ready to cook', _Filter.ready),
              _chip('Uses expiring food', _Filter.expiring),
            ],
          ),
        ),
        Expanded(child: _list(context, pantry, all, shown)),
      ],
    );
  }

  Widget _chip(String label, _Filter f) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: FilterChip(
      label: Text(label),
      selected: _filter == f,
      onSelected: (_) => setState(() => _filter = f),
    ),
  );

  Widget _list(
    BuildContext context,
    List<PantryItem> pantry,
    List<RecipeSuggestion> all,
    List<RecipeSuggestion> shown,
  ) {
    if (pantry.isEmpty) {
      return const _Empty(
        icon: Icons.kitchen,
        text:
            'Add some items to your fridge and\nmeal ideas will appear here.\n'
            'Or browse "All recipes".',
      );
    }
    if (all.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
        children: [
          _AiIdeasBanner(pantry: pantry),
          const SizedBox(height: 40),
          const _Empty(
            icon: Icons.search_off,
            text:
                "None of our recipes use what's in your fridge yet.\n"
                'Ask the AI for ideas above, or add more items.',
          ),
        ],
      );
    }
    if (shown.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
        children: [
          _AiIdeasBanner(pantry: pantry),
          const SizedBox(height: 40),
          _Empty(
            icon: Icons.filter_alt_off,
            text: _filter == _Filter.ready
                ? "You're missing at least one ingredient\nfor every recipe right now."
                : 'No matching recipe uses food\nthat expires in the next 3 days.',
          ),
        ],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
      itemCount: shown.length + 1,
      itemBuilder: (context, i) => i == 0
          ? _AiIdeasBanner(pantry: pantry)
          : _SuggestionCard(shown[i - 1]),
    );
  }
}

// ---------------------------------------------------------------------------
// All recipes
// ---------------------------------------------------------------------------

enum _Sort {
  bestMatch('Best match for my fridge'),
  quickest('Quickest first'),
  name('A–Z');

  final String label;
  const _Sort(this.label);
}

/// Time limits offered by the duration filter, in minutes.
const List<int> _timeLimits = [15, 30, 60];

class _AllRecipesTab extends StatefulWidget {
  final List<PantryItem> pantry;
  const _AllRecipesTab({required this.pantry});

  @override
  State<_AllRecipesTab> createState() => _AllRecipesTabState();
}

class _AllRecipesTabState extends State<_AllRecipesTab>
    with AutomaticKeepAliveClientMixin {
  final _search = TextEditingController();
  final Set<String> _origins = {};
  Diet? _diet; // null = any
  int? _maxMinutes; // null = any
  _Sort _sort = _Sort.bestMatch;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool get _filtered =>
      _origins.isNotEmpty ||
      _diet != null ||
      _maxMinutes != null ||
      _search.text.trim().isNotEmpty;

  void _clear() => setState(() {
    _origins.clear();
    _diet = null;
    _maxMinutes = null;
    _search.clear();
  });

  bool _matchesQuery(Recipe r, String q) {
    if (q.isEmpty) return true;
    return r.name.toLowerCase().contains(q) ||
        r.origin.toLowerCase().contains(q) ||
        r.ingredients.any((i) => i.label.toLowerCase().contains(q));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final q = _search.text.trim().toLowerCase();

    final results = [
      for (final r in recipeDatabase)
        if ((_origins.isEmpty || _origins.contains(r.origin)) &&
            (_diet == null || r.diet.suits(_diet!)) &&
            (_maxMinutes == null || r.minutes <= _maxMinutes!) &&
            _matchesQuery(r, q))
          evaluateRecipe(r, widget.pantry),
    ];
    results.sort(
      (a, b) => switch (_sort) {
        _Sort.bestMatch =>
          b.score.compareTo(a.score) != 0
              ? b.score.compareTo(a.score)
              : a.recipe.name.compareTo(b.recipe.name),
        _Sort.quickest =>
          a.recipe.minutes.compareTo(b.recipe.minutes) != 0
              ? a.recipe.minutes.compareTo(b.recipe.minutes)
              : a.recipe.name.compareTo(b.recipe.name),
        _Sort.name => a.recipe.name.compareTo(b.recipe.name),
      },
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      children: [
        TextField(
          controller: _search,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: 'Search recipes or ingredients',
            isDense: true,
            suffixIcon: _search.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => setState(_search.clear),
                  ),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 10),
        _filterRow(theme, 'Origin', [
          for (final o in recipeOrigins)
            FilterChip(
              label: Text(o),
              selected: _origins.contains(o),
              onSelected: (on) =>
                  setState(() => on ? _origins.add(o) : _origins.remove(o)),
            ),
        ]),
        _filterRow(theme, 'Diet', [
          ChoiceChip(
            label: const Text('Any'),
            selected: _diet == null,
            onSelected: (_) => setState(() => _diet = null),
          ),
          for (final d in [Diet.pescatarian, Diet.vegetarian, Diet.vegan])
            ChoiceChip(
              avatar: Icon(_dietIcon(d), size: 16),
              label: Text(d.label),
              selected: _diet == d,
              onSelected: (_) => setState(() => _diet = d),
            ),
        ]),
        _filterRow(theme, 'Time', [
          ChoiceChip(
            label: const Text('Any'),
            selected: _maxMinutes == null,
            onSelected: (_) => setState(() => _maxMinutes = null),
          ),
          for (final t in _timeLimits)
            ChoiceChip(
              avatar: const Icon(Icons.timer_outlined, size: 16),
              label: Text('≤ $t min'),
              selected: _maxMinutes == t,
              onSelected: (_) => setState(() => _maxMinutes = t),
            ),
        ]),
        Row(
          children: [
            Expanded(
              child: Text(
                '${results.length} recipe${results.length == 1 ? '' : 's'}',
                style: theme.textTheme.titleSmall,
              ),
            ),
            if (_filtered)
              TextButton(onPressed: _clear, child: const Text('Clear filters')),
            PopupMenuButton<_Sort>(
              tooltip: 'Sort',
              initialValue: _sort,
              onSelected: (s) => setState(() => _sort = s),
              itemBuilder: (_) => [
                for (final s in _Sort.values)
                  PopupMenuItem(value: s, child: Text(s.label)),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.sort, size: 18),
                    const SizedBox(width: 4),
                    Text(
                      _sort == _Sort.bestMatch
                          ? 'Best match'
                          : _sort == _Sort.quickest
                          ? 'Quickest'
                          : 'A–Z',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (results.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: _Empty(
              icon: Icons.filter_alt_off,
              text: 'No recipes match these filters.',
            ),
          ),
        for (final s in results) _SuggestionCard(s),
      ],
    );
  }

  /// A label and a sideways-scrolling row of chips.
  Widget _filterRow(ThemeData theme, String label, List<Widget> chips) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          children: [
            SizedBox(
              width: 52,
              child: Text(label, style: theme.textTheme.labelMedium),
            ),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final c in chips)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: c,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
}

IconData _dietIcon(Diet d) => switch (d) {
  Diet.vegan => Icons.eco,
  Diet.vegetarian => Icons.egg_outlined,
  Diet.pescatarian => Icons.set_meal_outlined,
  Diet.meat => Icons.restaurant,
};

Color _dietColor(Diet d) => switch (d) {
  Diet.vegan => Colors.green.shade100,
  Diet.vegetarian => Colors.lightGreen.shade100,
  Diet.pescatarian => Colors.lightBlue.shade100,
  Diet.meat => Colors.brown.shade100,
};

// ---------------------------------------------------------------------------
// AI meal ideas
// ---------------------------------------------------------------------------

/// Card at the top of "For you" that opens AI meal ideas.
class _AiIdeasBanner extends StatelessWidget {
  final List<PantryItem> pantry;
  const _AiIdeasBanner({required this.pantry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      color: theme.colorScheme.secondaryContainer,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => AiIdeasScreen(pantry: pantry)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(
                Icons.auto_awesome,
                color: theme.colorScheme.onSecondaryContainer,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI meal ideas',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                    ),
                    Text(
                      'New recipes made from what\'s in your fridge, '
                      'using expiring food first',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Asks Gemini for fresh recipe ideas based on the fridge.
class AiIdeasScreen extends StatefulWidget {
  final List<PantryItem> pantry;
  const AiIdeasScreen({super.key, required this.pantry});

  @override
  State<AiIdeasScreen> createState() => _AiIdeasScreenState();
}

class _AiIdeasScreenState extends State<AiIdeasScreen> {
  Diet? _diet;
  int? _maxMinutes;
  bool _loading = false;
  String? _error;
  List<RecipeSuggestion> _ideas = const [];

  Future<void> _generate() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final recipes = await generateMealIdeas(
        widget.pantry,
        diet: _diet,
        maxMinutes: _maxMinutes,
      );
      if (!mounted) return;
      setState(
        () => _ideas = [
          for (final r in recipes) evaluateRecipe(r, widget.pantry),
        ],
      );
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('AI meal ideas')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
        children: [
          Text(
            'Gemini looks at your ${widget.pantry.length} fridge items and '
            'invents recipes around the ones expiring soonest, including '
            'combinations our recipe book doesn\'t cover.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ChoiceChip(
                label: const Text('Any diet'),
                selected: _diet == null,
                onSelected: (_) => setState(() => _diet = null),
              ),
              for (final d in [Diet.pescatarian, Diet.vegetarian, Diet.vegan])
                ChoiceChip(
                  avatar: Icon(_dietIcon(d), size: 16),
                  label: Text(d.label),
                  selected: _diet == d,
                  onSelected: (_) => setState(() => _diet = d),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ChoiceChip(
                label: const Text('Any time'),
                selected: _maxMinutes == null,
                onSelected: (_) => setState(() => _maxMinutes = null),
              ),
              for (final t in _timeLimits)
                ChoiceChip(
                  avatar: const Icon(Icons.timer_outlined, size: 16),
                  label: Text('≤ $t min'),
                  selected: _maxMinutes == t,
                  onSelected: (_) => setState(() => _maxMinutes = t),
                ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _loading ? null : _generate,
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome),
            label: Text(
              _loading
                  ? 'Thinking up recipes...'
                  : _ideas.isEmpty
                  ? 'Get 3 ideas'
                  : 'Get 3 new ideas',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ],
          if (_ideas.isNotEmpty) ...[
            const SizedBox(height: 16),
            for (final s in _ideas) _SuggestionCard(s),
            const SizedBox(height: 8),
            Text(
              'AI recipes are generated automatically. Check ingredients for '
              'allergies and cook meat and seafood thoroughly.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Recipes for one item (opened from an expiry reminder)
// ---------------------------------------------------------------------------

/// Every recipe that uses [itemName], best fit for the fridge first, plus a
/// shortcut to AI ideas. Opened by tapping an expiry notification.
class IngredientRecipesScreen extends StatelessWidget {
  final String itemName;
  const IngredientRecipesScreen({super.key, required this.itemName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Recipes with $itemName')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _userCol('inventory').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final pantry = snapshot.data!.docs.map((doc) {
            final d = doc.data();
            return PantryItem(
              '${d['name']}',
              (d['expiryDate'] as Timestamp).toDate(),
              quantity: quantityOf(d),
              unit: unitOf(d),
            );
          }).toList();
          final recipes = recipesUsing(itemName, pantry, limit: 50);

          return StreamBuilder<Set<String>>(
            stream: favouriteIds(),
            builder: (context, favSnap) => _Favourites(
              ids: favSnap.data ?? const {},
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
                    child: Text(
                      recipes.isEmpty
                          ? 'None of our recipes use $itemName yet.'
                          : '${recipes.length} recipe'
                              '${recipes.length == 1 ? '' : 's'} use $itemName. '
                              'Best match for your fridge first.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  if (pantry.isNotEmpty) _AiIdeasBanner(pantry: pantry),
                  for (final r in recipes)
                    _SuggestionCard(evaluateRecipe(r, pantry)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared widgets
// ---------------------------------------------------------------------------

class _Empty extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Empty({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 48, color: Theme.of(context).colorScheme.outline),
        const SizedBox(height: 12),
        Text(text, textAlign: TextAlign.center),
      ],
    ),
  );
}

class _SuggestionCard extends StatelessWidget {
  final RecipeSuggestion s;
  const _SuggestionCard(this.s);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = s.recipe;
    final expiring = s.expiringWithin(3);
    final total = s.matches.length;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => RecipeDetailScreen(suggestion: s)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(r.name, style: theme.textTheme.titleMedium),
                  ),
                  const Icon(Icons.timer_outlined, size: 16),
                  const SizedBox(width: 2),
                  Text('${r.minutes} min', style: theme.textTheme.bodySmall),
                  if (!r.aiGenerated)
                    FavouriteButton(
                      recipeId: r.id,
                      recipeName: r.name,
                      isFavourite: _Favourites.of(context).contains(r.id),
                      compact: true,
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Text(r.origin, style: theme.textTheme.bodySmall),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: total == 0 ? 0 : s.haveCount / total,
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'You have ${s.haveCount} of $total ingredients',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (r.aiGenerated)
                    _Tag(
                      'AI idea',
                      Colors.purple.shade100,
                      icon: Icons.auto_awesome,
                    ),
                  if (r.diet != Diet.meat)
                    _Tag(
                      r.diet.label,
                      _dietColor(r.diet),
                      icon: _dietIcon(r.diet),
                    ),
                  if (expiring > 0)
                    _Tag(
                      expiring == 1
                          ? 'Uses 1 item expiring soon'
                          : 'Uses $expiring items expiring soon',
                      Colors.orange.shade100,
                    ),
                  s.missingCount == 0
                      ? _Tag('Ready to cook', Colors.green.shade100)
                      : _Tag(
                          'Missing ${s.missingCount}',
                          theme.colorScheme.surfaceContainerHighest,
                        ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;
  const _Tag(this.text, this.color, {this.icon});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 13, color: Colors.black87),
          const SizedBox(width: 3),
        ],
        Text(
          text,
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: Colors.black87),
        ),
      ],
    ),
  );
}

String _expiryText(int daysLeft) => switch (daysLeft) {
  0 => 'expires today',
  1 => 'expires tomorrow',
  _ => 'expires in $daysLeft days',
};

/// What to put on the grocery list for one ingredient: the full amount when
/// it's missing, or the shortfall when there isn't enough.
typedef _ToBuy = ({IngredientMatch match, num? amount, bool short});

/// Full recipe: amounts scaled to the chosen servings, what you have and
/// whether it's enough, steps, and a button that adds what's missing (or
/// short) to the grocery list.
class RecipeDetailScreen extends StatefulWidget {
  final RecipeSuggestion suggestion;

  /// Servings to open with (e.g. from the meal plan); defaults to the
  /// recipe's own.
  final int? servings;
  const RecipeDetailScreen(
      {super.key, required this.suggestion, this.servings});

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  bool _adding = false;
  late int _servings = widget.servings ?? widget.suggestion.recipe.servings;
  final Stream<Set<String>> _favStream = favouriteIds();

  double get _factor => _servings / widget.suggestion.recipe.servings;

  num? _scaled(num? amount, String unit) =>
      amount == null ? null : scaleAmount(amount, unit, _factor);

  List<_ToBuy> get _toBuy => [
    for (final m in widget.suggestion.matches)
      if (!m.have)
        (
          match: m,
          amount: _scaled(m.ingredient.amount, m.ingredient.unit),
          short: false,
        )
      else if ((m.shortBy(_factor) ?? 0) > 0)
        (match: m, amount: m.shortBy(_factor), short: true),
  ];

  Future<void> _addToGroceries(List<_ToBuy> items) async {
    final s = widget.suggestion;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _adding = true);
    try {
      final col = _userCol('groceryList');
      // Skip anything already on the list and not yet ticked off.
      final existing = await col.where('checked', isEqualTo: false).get();
      final onList = existing.docs
          .map((d) => '${d.data()['name']}'.toLowerCase())
          .toSet();

      final batch = FirebaseFirestore.instance.batch();
      var added = 0;
      for (final t in items) {
        final ing = t.match.ingredient;
        if (onList.contains(ing.label.toLowerCase())) continue;
        batch.set(col.doc(), {
          'name': ing.label,
          // Lets the grocery list spot the item once it's in the fridge.
          'keywords': ing.keywords,
          if (t.amount != null) 'quantity': t.amount,
          if (t.amount != null) 'unit': ing.unit,
          'fromRecipe': s.recipe.name,
          'checked': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
        added++;
      }
      if (added > 0) await batch.commit();

      final skipped = items.length - added;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            [
              if (added > 0)
                'Added $added item${added == 1 ? '' : 's'} to your grocery list',
              if (skipped > 0) '$skipped already on the list',
            ].join(' · '),
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not update grocery list: $e')),
      );
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.suggestion;
    final r = s.recipe;
    final theme = Theme.of(context);
    final toBuy = _toBuy;
    final shortCount = toBuy.where((t) => t.short).length;

    return Scaffold(
      appBar: AppBar(
        title: Text(r.name),
        actions: [
          // This screen sits outside the Meals tab, so it listens itself.
          if (!r.aiGenerated)
            StreamBuilder<Set<String>>(
              stream: _favStream,
              builder: (context, snap) => FavouriteButton(
                recipeId: r.id,
                recipeName: r.name,
                isFavourite: snap.data?.contains(r.id) ?? false,
              ),
            ),
        ],
      ),
      bottomNavigationBar: toBuy.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton.icon(
                  onPressed: _adding ? null : () => _addToGroceries(toBuy),
                  icon: const Icon(Icons.add_shopping_cart),
                  label: Text(
                    _adding
                        ? 'Adding...'
                        : shortCount == 0
                        ? 'Add ${toBuy.length} missing to grocery list'
                        : 'Add ${toBuy.length} to grocery list '
                              '($shortCount not enough)',
                  ),
                ),
              ),
            ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _meta(Icons.public, r.origin),
              if (r.diet != Diet.meat) _meta(_dietIcon(r.diet), r.diet.label),
              _meta(Icons.timer_outlined, '${r.minutes} min'),
              _servingsStepper(theme),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Text('Ingredients', style: theme.textTheme.titleMedium),
              ),
              Text(
                'for $_servings serving${_servings == 1 ? '' : 's'}',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 4),
          ...s.matches.map((m) => _ingredientTile(context, m)),
          if (r.staples.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Pantry staples', style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final st in r.staples)
                  Chip(
                    visualDensity: VisualDensity.compact,
                    label: Text(_stapleText(st)),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          Text('Steps', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          for (var i = 0; i < r.steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 12,
                    child: Text('${i + 1}', style: theme.textTheme.labelSmall),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(r.steps[i])),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _stapleText(Staple st) {
    final a = _scaled(st.amount, st.unit);
    if (a == null) return '${st.name} (to taste)';
    return '${st.name} · ${formatNumber(a)} ${st.unit}'.trimRight();
  }

  Widget _servingsStepper(ThemeData theme) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Icon(Icons.people_outline, size: 18),
      IconButton(
        visualDensity: VisualDensity.compact,
        tooltip: 'Fewer servings',
        icon: const Icon(Icons.remove_circle_outline, size: 20),
        onPressed: _servings > 1 ? () => setState(() => _servings--) : null,
      ),
      Text('Serves $_servings'),
      IconButton(
        visualDensity: VisualDensity.compact,
        tooltip: 'More servings',
        icon: const Icon(Icons.add_circle_outline, size: 20),
        onPressed: _servings < 12 ? () => setState(() => _servings++) : null,
      ),
    ],
  );

  Widget _meta(IconData icon, String text) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [Icon(icon, size: 18), const SizedBox(width: 4), Text(text)],
  );

  Widget _ingredientTile(BuildContext context, IngredientMatch m) {
    final ing = m.ingredient;
    final need = _scaled(ing.amount, ing.unit);
    final warn = Colors.orange.shade800;
    final String subtitle;
    Color? subtitleColor;
    final Widget icon;

    if (m.have) {
      final d = m.daysLeft!;
      final got = m.haveAmount;
      final short = m.shortBy(_factor);
      final gotText = got == null ? '' : ' (${formatAmount(got, ing.unit)})';
      if (short != null && short > 0) {
        subtitle =
            'Only ${formatAmount(got!, ing.unit)} in your fridge · '
            'need ${formatAmount(short, ing.unit)} more';
        subtitleColor = warn;
        icon = Icon(Icons.error_outline, color: warn);
      } else {
        subtitle = '${m.item!.name}$gotText · ${_expiryText(d)}';
        icon = Icon(
          Icons.check_circle,
          color: d <= 1 ? Colors.orange : Colors.green,
        );
      }
    } else {
      subtitle = m.expiredItem != null
          ? '${m.expiredItem!.name} has expired'
          : 'Not in your fridge';
      icon = Icon(
        Icons.radio_button_unchecked,
        color: Theme.of(context).colorScheme.outline,
      );
    }
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: icon,
      title: Text(ing.label),
      subtitle: Text(
        subtitle,
        style: subtitleColor == null ? null : TextStyle(color: subtitleColor),
      ),
      trailing: need == null
          ? null
          : Text(
              formatAmount(need, ing.unit),
              style: Theme.of(context).textTheme.titleSmall,
            ),
    );
  }
}
