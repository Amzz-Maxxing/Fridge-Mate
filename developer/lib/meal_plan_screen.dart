import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'amounts.dart';
import 'meal_plan.dart';
import 'meal_screen.dart' show RecipeDetailScreen;
import 'recipes.dart';

CollectionReference<Map<String, dynamic>> _userCol(String name) {
  final uid = FirebaseAuth.instance.currentUser!.uid;
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection(name);
}

final Map<String, Recipe> _recipesById = {
  for (final r in recipeDatabase) r.id: r,
};

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _monthsShort = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];
String _short(DateTime d) => '${d.day} ${_monthsShort[d.month - 1]}';

/// Weekly meal planner.
class MealPlanScreen extends StatefulWidget {
  const MealPlanScreen({super.key});

  @override
  State<MealPlanScreen> createState() => _PlannerState();
}

class _PlannerState extends State<MealPlanScreen> {
  DateTime _start = weekStart(DateTime.now());
  bool _busy = false;

  DocumentReference<Map<String, dynamic>> get _doc =>
      _userCol('mealPlans').doc(dayKey(_start));

  Map<String, PlanEntry> _entriesOf(Map<String, dynamic>? data) {
    final meals = data?['meals'];
    if (meals is! Map) return {};
    return {
      for (final e in meals.entries)
        '${e.key}': ?PlanEntry.fromMap(e.value),
    };
  }

  Future<void> _setEntry(String key, PlanEntry? entry) => _doc.set({
        'meals': {key: entry == null ? FieldValue.delete() : entry.toMap()},
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

  Future<void> _pick(
      DateTime day, MealSlot slot, List<PantryItem> pantry) async {
    final picked = await showModalBottomSheet<PlanEntry>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        maxChildSize: 1,
        builder: (context, scroll) => _RecipePicker(
          title: '${slot.label} · ${_weekdays[day.weekday - 1]} ${_short(day)}',
          pantry: pantry,
          day: day,
          scroll: scroll,
        ),
      ),
    );
    if (picked != null) await _setEntry(entryKey(day, slot), picked);
  }

  Future<void> _autoPlan(
      Map<String, PlanEntry> existing, List<PantryItem> pantry) async {
    final opts = await showDialog<_AutoPlanOptions>(
      context: context,
      builder: (_) => const _AutoPlanDialog(),
    );
    if (opts == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final added = autoPlan(
        start: _start,
        slots: opts.slots,
        existing: existing,
        pantry: pantry,
        recipes: recipeDatabase,
        diet: opts.diet,
        maxMinutes: opts.maxMinutes,
        servings: opts.servings,
      );
      if (added.isEmpty) {
        messenger.showSnackBar(const SnackBar(
            content: Text('Nothing to fill: those meals are already planned')));
        return;
      }
      await _doc.set({
        'meals': {for (final e in added.entries) e.key: e.value.toMap()},
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      messenger.showSnackBar(SnackBar(
          content: Text('Planned ${added.length} meals, expiring food first')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not plan: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _shop(
      Map<String, PlanEntry> entries, List<PantryItem> pantry) async {
    final messenger = ScaffoldMessenger.of(context);
    final needs = weeklyShopping(entries.values, _recipesById, pantry);
    if (needs.isEmpty) {
      messenger.showSnackBar(const SnackBar(
          content: Text('You already have everything for this week')));
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add ${needs.length} items to your grocery list?'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              const Text(
                  "Everything this week's meals need, minus what's already "
                  'in your fridge:'),
              const SizedBox(height: 8),
              for (final n in needs)
                Text('• ${n.name} · ${formatAmount(n.quantity, n.unit)}'),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Add')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      final col = _userCol('groceryList');
      final current = await col.where('checked', isEqualTo: false).get();
      final onList = current.docs
          .map((d) => '${d.data()['name']}'.toLowerCase())
          .toSet();
      final batch = FirebaseFirestore.instance.batch();
      var added = 0;
      for (final n in needs) {
        if (!onList.add(n.name.toLowerCase())) continue;
        batch.set(col.doc(), {
          'name': n.name,
          'keywords': n.keywords,
          'quantity': n.quantity,
          'unit': n.unit,
          'fromRecipe': 'Meal plan, week of ${_short(_start)}',
          'checked': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
        added++;
      }
      if (added > 0) await batch.commit();
      final skipped = needs.length - added;
      messenger.showSnackBar(SnackBar(
        content: Text([
          'Added $added item${added == 1 ? '' : 's'} to your grocery list',
          if (skipped > 0) '$skipped already on it',
        ].join(' · ')),
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not add: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _clearWeek() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear this week?'),
        content: const Text('All planned meals for this week will be removed.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Clear')),
        ],
      ),
    );
    if (ok == true) await _doc.delete();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final thisWeek = weekStart(DateTime.now());
    final weekLabel = _start == thisWeek
        ? 'This week'
        : _start == thisWeek.add(const Duration(days: 7))
            ? 'Next week'
            : 'Week of ${_short(_start)}';

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _userCol('inventory').snapshots(),
      builder: (context, invSnap) {
        final pantry = (invSnap.data?.docs ?? const []).map((doc) {
          final d = doc.data();
          return PantryItem(
            '${d['name']}',
            (d['expiryDate'] as Timestamp).toDate(),
            quantity: quantityOf(d),
            unit: unitOf(d),
          );
        }).toList();

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _doc.snapshots(),
          builder: (context, planSnap) {
            final entries = _entriesOf(planSnap.data?.data());
            return Scaffold(
              appBar: AppBar(
                title: const Text('Meal plan'),
                actions: [
                  if (entries.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.delete_sweep_outlined),
                      tooltip: 'Clear week',
                      onPressed: _clearWeek,
                    ),
                ],
              ),
              bottomNavigationBar: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _busy || !invSnap.hasData
                              ? null
                              : () => _autoPlan(entries, pantry),
                          icon: const Icon(Icons.auto_fix_high),
                          label: const Text('Auto-plan'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _busy || entries.isEmpty
                              ? null
                              : () => _shop(entries, pantry),
                          icon: const Icon(Icons.shopping_cart_checkout),
                          label: const Text('Shop for week'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              body: ListView(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                children: [
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Previous week',
                        icon: const Icon(Icons.chevron_left),
                        onPressed: () => setState(() => _start =
                            _start.subtract(const Duration(days: 7))),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text(weekLabel, style: theme.textTheme.titleMedium),
                            Text(
                              '${_short(_start)} – '
                              '${_short(_start.add(const Duration(days: 6)))}'
                              ' · ${entries.length} meals planned',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Next week',
                        icon: const Icon(Icons.chevron_right),
                        onPressed: () => setState(() =>
                            _start = _start.add(const Duration(days: 7))),
                      ),
                    ],
                  ),
                  for (final day in weekDays(_start))
                    _DayCard(
                      day: day,
                      entries: entries,
                      onAdd: (slot) => _pick(day, slot, pantry),
                      onOpen: (slot, e) {
                        final r = _recipesById[e.recipeId];
                        if (r == null) return;
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => RecipeDetailScreen(
                            suggestion: evaluateRecipe(r, pantry),
                            servings: e.servings,
                          ),
                        ));
                      },
                      onRemove: (slot) =>
                          _setEntry(entryKey(day, slot), null),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _DayCard extends StatelessWidget {
  final DateTime day;
  final Map<String, PlanEntry> entries;
  final void Function(MealSlot) onAdd;
  final void Function(MealSlot, PlanEntry) onOpen;
  final void Function(MealSlot) onRemove;

  const _DayCard({
    required this.day,
    required this.entries,
    required this.onAdd,
    required this.onOpen,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final isToday =
        day.year == now.year && day.month == now.month && day.day == now.day;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: isToday
          ? RoundedRectangleBorder(
              side: BorderSide(color: theme.colorScheme.primary, width: 1.5),
              borderRadius: BorderRadius.circular(12),
            )
          : null,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 4, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_weekdays[day.weekday - 1]} ${_short(day)}'
              '${isToday ? ' · Today' : ''}',
              style: theme.textTheme.titleSmall,
            ),
            for (final slot in MealSlot.values)
              _slotRow(context, slot, entries[entryKey(day, slot)]),
          ],
        ),
      ),
    );
  }

  Widget _slotRow(BuildContext context, MealSlot slot, PlanEntry? e) {
    final theme = Theme.of(context);
    final r = e == null ? null : _recipesById[e.recipeId];
    return Row(
      children: [
        SizedBox(
          width: 76,
          child: Text(slot.label, style: theme.textTheme.bodySmall),
        ),
        Expanded(
          child: r == null || e == null
              ? Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact),
                    onPressed: () => onAdd(slot),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add'),
                  ),
                )
              : InkWell(
                  onTap: () => onOpen(slot, e),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      '${r.name} · ${e.servings} '
                      'serving${e.servings == 1 ? '' : 's'}',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ),
        ),
        if (r != null)
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Remove',
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => onRemove(slot),
          ),
      ],
    );
  }
}

/// Bottom sheet to choose a recipe and servings for one meal. Recipes are
/// ranked by how well they use the fridge on that day.
class _RecipePicker extends StatefulWidget {
  final String title;
  final List<PantryItem> pantry;
  final DateTime day;
  final ScrollController scroll;

  const _RecipePicker({
    required this.title,
    required this.pantry,
    required this.day,
    required this.scroll,
  });

  @override
  State<_RecipePicker> createState() => _RecipePickerState();
}

class _RecipePickerState extends State<_RecipePicker> {
  final _search = TextEditingController();
  int _servings = 2;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final q = _search.text.trim().toLowerCase();
    final ranked = [
      for (final r in recipeDatabase)
        if (q.isEmpty ||
            r.name.toLowerCase().contains(q) ||
            r.origin.toLowerCase().contains(q))
          evaluateRecipe(r, widget.pantry, now: widget.day),
    ]..sort((a, b) {
        final c = b.score.compareTo(a.score);
        return c != 0 ? c : a.recipe.name.compareTo(b.recipe.name);
      });

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            children: [
              Expanded(
                  child: Text(widget.title, style: theme.textTheme.titleMedium)),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.remove_circle_outline),
                onPressed:
                    _servings > 1 ? () => setState(() => _servings--) : null,
              ),
              Text('$_servings serving${_servings == 1 ? '' : 's'}'),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.add_circle_outline),
                onPressed:
                    _servings < 12 ? () => setState(() => _servings++) : null,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _search,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search recipes',
              isDense: true,
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        Expanded(
          child: ListView.builder(
            controller: widget.scroll,
            itemCount: ranked.length,
            itemBuilder: (context, i) {
              final s = ranked[i];
              final r = s.recipe;
              return ListTile(
                title: Text(r.name),
                subtitle: Text(
                    '${r.origin} · ${r.minutes} min · have ${s.haveCount}/'
                    '${s.matches.length}'
                    '${s.expiringWithin(3) > 0 ? ' · uses expiring food' : ''}'),
                trailing: s.missingCount == 0
                    ? Icon(Icons.check_circle, color: Colors.green.shade600)
                    : null,
                onTap: () =>
                    Navigator.pop(context, PlanEntry(r.id, _servings)),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AutoPlanOptions {
  final List<MealSlot> slots;
  final Diet? diet;
  final int? maxMinutes;
  final int servings;
  const _AutoPlanOptions(this.slots, this.diet, this.maxMinutes, this.servings);
}

class _AutoPlanDialog extends StatefulWidget {
  const _AutoPlanDialog();

  @override
  State<_AutoPlanDialog> createState() => _AutoPlanDialogState();
}

class _AutoPlanDialogState extends State<_AutoPlanDialog> {
  final Set<MealSlot> _slots = {MealSlot.lunch, MealSlot.dinner};
  Diet? _diet;
  int? _maxMinutes = 60;
  int _servings = 2;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Auto-plan the week'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
                'Fills empty meals from today on, using food that expires '
                'soonest first and without repeating recipes.'),
            const SizedBox(height: 12),
            Text('Meals to plan', style: theme.textTheme.labelLarge),
            Wrap(
              spacing: 6,
              children: [
                for (final s in MealSlot.values)
                  FilterChip(
                    label: Text(s.label),
                    selected: _slots.contains(s),
                    onSelected: (on) => setState(
                        () => on ? _slots.add(s) : _slots.remove(s)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Diet', style: theme.textTheme.labelLarge),
            Wrap(
              spacing: 6,
              children: [
                ChoiceChip(
                  label: const Text('Any'),
                  selected: _diet == null,
                  onSelected: (_) => setState(() => _diet = null),
                ),
                for (final d in [Diet.pescatarian, Diet.vegetarian, Diet.vegan])
                  ChoiceChip(
                    label: Text(d.label),
                    selected: _diet == d,
                    onSelected: (_) => setState(() => _diet = d),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Cooking time', style: theme.textTheme.labelLarge),
            Wrap(
              spacing: 6,
              children: [
                for (final t in [30, 60, null])
                  ChoiceChip(
                    label: Text(t == null ? 'Any' : '≤ $t min'),
                    selected: _maxMinutes == t,
                    onSelected: (_) => setState(() => _maxMinutes = t),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('Servings per meal', style: theme.textTheme.labelLarge),
                const Spacer(),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: _servings > 1
                      ? () => setState(() => _servings--)
                      : null,
                ),
                Text('$_servings'),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: _servings < 12
                      ? () => setState(() => _servings++)
                      : null,
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: _slots.isEmpty
              ? null
              : () => Navigator.pop(
                    context,
                    _AutoPlanOptions(
                      MealSlot.values.where(_slots.contains).toList(),
                      _diet,
                      _maxMinutes,
                      _servings,
                    ),
                  ),
          child: const Text('Plan'),
        ),
      ],
    );
  }
}
