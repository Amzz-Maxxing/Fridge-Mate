import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'amounts.dart';
import 'notification_service.dart';
import 'meal_screen.dart' show IngredientRecipesScreen;
import 'recipes.dart';
import 'profile.dart';
import 'scan_screen.dart';
import 'theme.dart';

// Rough shelf-life estimates in days. Users can always change the date.
const Map<String, int> shelfLifeDays = {
  'Vegetables': 5,
  'Fruits': 7,
  'Meat & Chicken': 3,
  'Seafood': 2,
  'Dairy': 7,
  'Eggs': 21,
  'Leftovers': 3,
  'Other': 7,
};

String _fmt(DateTime d) => '${d.day}/${d.month}/${d.year}';

/// Fridge tab (design C · Shelves): headline, the most urgent item, pastel
/// shelf tiles per category (tap to filter) and the items, soonest first.
class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  /// Category shown in the list, or null for everything.
  String? _category;

  CollectionReference<Map<String, dynamic>> get _col {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('inventory');
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: Row(
          children: [
            const FridgeMateIcon(size: 34),
            const SizedBox(width: 10),
            Text(
              'Fridge Mate',
              style: appFont(fontSize: 22, fontWeight: FontWeight.w900),
            ),
          ],
        ),
        actions: const [ProfileButton(), SizedBox(width: 12)],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: 'add',
            tooltip: 'Add item',
            backgroundColor: p.card,
            foregroundColor: p.ink,
            onPressed: () => showItemSheet(context, _col),
            child: const Icon(Icons.add),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: 64,
            height: 64,
            child: FloatingActionButton(
              heroTag: 'scan',
              tooltip: 'Scan fridge',
              onPressed: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const ScanScreen())),
              child: const Icon(Icons.document_scanner_outlined, size: 28),
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _col.orderBy('expiryDate').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data!.docs;
          final expiryItems = docs.map((doc) {
            final d = doc.data();
            return ExpiryItem(
              '${d['name']}',
              (d['expiryDate'] as Timestamp).toDate(),
            );
          }).toList();
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => NotificationService.reschedule(expiryItems),
          );

          int daysLeftOf(Map<String, dynamic> d) {
            final e = (d['expiryDate'] as Timestamp).toDate();
            return DateTime(e.year, e.month, e.day).difference(today).inDays;
          }

          final pantry = [
            for (final doc in docs)
              PantryItem(
                '${doc.data()['name']}',
                (doc.data()['expiryDate'] as Timestamp).toDate(),
                quantity: quantityOf(doc.data()),
                unit: unitOf(doc.data()),
              ),
          ];

          // Items per category, and whether any expires within 3 days.
          final counts = <String, int>{};
          final soon = <String, int>{}; // smallest daysLeft (not expired)
          for (final doc in docs) {
            final c = '${doc.data()['category'] ?? 'Other'}';
            counts[c] = (counts[c] ?? 0) + 1;
            final dl = daysLeftOf(doc.data());
            if (dl >= 0 && (soon[c] == null || dl < soon[c]!)) soon[c] = dl;
          }
          final category = counts.containsKey(_category) ? _category : null;
          final shown = category == null
              ? docs
              : docs
                    .where((d) => '${d.data()['category']}' == category)
                    .toList();

          final urgent = docs
              .where(
                (d) => daysLeftOf(d.data()) >= 0 && daysLeftOf(d.data()) <= 1,
              )
              .firstOrNull;

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 170),
            children: [
              Text(
                "What's in\nyour fridge?",
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontSize: 32,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 16),
              if (urgent != null) ...[
                _UrgentCard(
                  name: '${urgent.data()['name']}',
                  daysLeft: daysLeftOf(urgent.data()),
                  recipeCount: recipesUsing(
                    '${urgent.data()['name']}',
                    pantry,
                    limit: 100,
                  ).length,
                ),
                const SizedBox(height: 20),
              ],
              if (docs.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: p.shelf('Vegetables'),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Text(
                    'Your shelves are empty.\nTap the scan button to snap your '
                    'fridge, or + to add items by hand.',
                    style: theme.textTheme.titleMedium,
                  ),
                )
              else ...[
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Your shelves',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontSize: 20,
                        ),
                      ),
                    ),
                    Text(
                      '${docs.length} items',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: p.muted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.55,
                  children: [
                    for (final c in shelfLifeDays.keys)
                      if (counts.containsKey(c))
                        _ShelfTile(
                          category: c,
                          count: counts[c]!,
                          soonestDays: soon[c],
                          selected: category == c,
                          onTap: () => setState(
                            () => _category = category == c ? null : c,
                          ),
                        ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        category ?? 'Use first',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontSize: 20,
                        ),
                      ),
                    ),
                    if (category != null)
                      TextButton(
                        onPressed: () => setState(() => _category = null),
                        child: const Text('Show all'),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                for (final doc in shown)
                  _ItemCard(
                    doc: doc,
                    daysLeft: daysLeftOf(doc.data()),
                    onTap: () => showItemSheet(context, _col, existing: doc),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Forest-green card for the item that needs using now.
class _UrgentCard extends StatelessWidget {
  final String name;
  final int daysLeft;
  final int recipeCount;
  const _UrgentCard({
    required this.name,
    required this.daysLeft,
    required this.recipeCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.palette.hero,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: daysLeft == 0 ? urgentSoft : brandLeaf,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$daysLeft',
                  style: appFont(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: brandForest,
                    textStyle: const TextStyle(height: 1),
                  ),
                ),
                Text(
                  daysLeft == 1 ? 'day' : 'days',
                  style: appFont(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: brandForest,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  daysLeft == 0
                      ? '$name expires today'
                      : '$name expires tomorrow',
                  style: appFont(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  recipeCount == 0
                      ? 'Ask the AI for ideas'
                      : '$recipeCount recipe${recipeCount == 1 ? '' : 's'} can use it',
                  style: appFont(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: forestLight,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: brandLeaf,
              foregroundColor: inkOnLeaf,
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => IngredientRecipesScreen(itemName: name),
              ),
            ),
            child: const Text('Cook'),
          ),
        ],
      ),
    );
  }
}

/// Pastel tile showing how many items a category holds. A dot warns when
/// something on that shelf expires within 3 days.
class _ShelfTile extends StatelessWidget {
  final String category;
  final int count;
  final int? soonestDays;
  final bool selected;
  final VoidCallback onTap;

  const _ShelfTile({
    required this.category,
    required this.count,
    required this.soonestDays,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final dot = soonestDays == null
        ? null
        : soonestDays! <= 1
        ? urgentRed
        : soonestDays! <= 3
        ? warnAmber
        : null;
    return Semantics(
      button: true,
      selected: selected,
      label:
          '$category, $count item${count == 1 ? '' : 's'}'
          '${dot == null ? '' : ', something expires soon'}',
      excludeSemantics: true,
      child: Material(
        color: p.shelf(category),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: selected
              ? BorderSide(color: p.ink, width: 2.5)
              : BorderSide.none,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$count',
                  style: appFont(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    color: p.ink,
                    textStyle: const TextStyle(height: 1),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        category,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: appFont(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: p.ink,
                        ),
                      ),
                    ),
                    if (dot != null)
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: dot,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One fridge item. Swipe right to use some, left to delete.
class _ItemCard extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final int daysLeft;
  final VoidCallback onTap;

  const _ItemCard({
    required this.doc,
    required this.daysLeft,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final d = doc.data();
    final expiry = (d['expiryDate'] as Timestamp).toDate();
    final qty = quantityOf(d) ?? 1;
    final unit = unitOf(d);
    final category = '${d['category'] ?? 'Other'}';

    final (Color pillBg, Color pillFg, String pillText) = daysLeft < 0
        ? (p.urgent.bg, p.urgent.fg, 'Expired')
        : daysLeft == 0
        ? (p.urgent.bg, p.urgent.fg, 'Today')
        : daysLeft <= 3
        ? (p.soon.bg, p.soon.fg, daysLeft == 1 ? '1 day' : '$daysLeft days')
        : (p.fresh.bg, p.fresh.fg, '$daysLeft days');

    Widget swipeBg(Color color, Alignment align, Widget child) => Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      alignment: align,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: child,
    );

    return Dismissible(
      key: ValueKey(doc.id),
      // Swipe right: use some. Swipe left: delete.
      background: swipeBg(
        brandLeaf,
        Alignment.centerLeft,
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.remove_circle_outline, color: inkOnLeaf),
            const SizedBox(width: 8),
            Text(
              'Use some',
              style: appFont(fontWeight: FontWeight.w800, color: inkOnLeaf),
            ),
          ],
        ),
      ),
      secondaryBackground: swipeBg(
        urgentRed,
        Alignment.centerRight,
        const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          await showUseSheet(context, doc);
          return false; // keep the row; the sheet updates it
        }
        return true;
      },
      onDismissed: (_) {
        doc.reference.delete();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Removed ${d['name']}'),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () => doc.reference.set(d),
            ),
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: p.cardBorder),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: p.shelf(category),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    '${d['name']}'.isEmpty
                        ? '?'
                        : '${d['name']}'.substring(0, 1).toUpperCase(),
                    style: appFont(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: p.ink,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${d['name']}',
                        style: appFont(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: p.ink,
                        ),
                      ),
                      Text(
                        '${formatAmount(qty, unit)} · Expires ${_fmt(expiry)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: pillBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    pillText,
                    style: appFont(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: pillFg,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Use some" sheet opened by swiping a fridge item to the right. Lowers the
/// amount, or removes the item when it's all used up.
Future<void> showUseSheet(
  BuildContext context,
  QueryDocumentSnapshot<Map<String, dynamic>> doc,
) {
  return showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (_) => _UseSheet(doc: doc),
  );
}

class _UseSheet extends StatefulWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  const _UseSheet({required this.doc});

  @override
  State<_UseSheet> createState() => _UseSheetState();
}

class _UseSheetState extends State<_UseSheet> {
  late final Map<String, dynamic> _d = widget.doc.data();
  late final num _had = quantityOf(_d) ?? 1;
  late final String _unit = unitOf(_d);
  late num _left = _had;
  bool _saving = false;

  void _use(num amount) =>
      setState(() => _left = roundAmount((_left - amount).clamp(0, _had)));

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final name = '${_d['name']}';
    setState(() => _saving = true);
    try {
      if (_left <= 0) {
        await widget.doc.reference.delete();
        messenger.showSnackBar(
          SnackBar(
            content: Text('$name used up and removed'),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () => widget.doc.reference.set(_d),
            ),
          ),
        );
      } else {
        await widget.doc.reference.update({
          'quantity': _left,
          'unit': _unit,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        messenger.showSnackBar(
          SnackBar(
            content: Text('$name: ${formatAmount(_left, _unit)} left'),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () => widget.doc.reference.update({
                'quantity': _had,
                'unit': _unit,
              }),
            ),
          ),
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text('Could not update: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final used = roundAmount(_had - _left);
    final step = stepFor(_unit);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Use some ${_d['name']}', style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'You have ${formatAmount(_had, _unit)}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton.filledTonal(
                  iconSize: 28,
                  tooltip: 'Use ${formatAmount(step, _unit)} more',
                  icon: const Icon(Icons.remove),
                  onPressed: _left > 0 ? () => _use(step) : null,
                ),
                SizedBox(
                  width: 150,
                  child: Column(
                    children: [
                      Text(
                        formatAmount(_left, _unit),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall,
                      ),
                      Text('left', style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  iconSize: 28,
                  tooltip: 'Use less',
                  icon: const Icon(Icons.add),
                  onPressed: _left < _had ? () => _use(-step) : null,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final q in quickUseFor(_unit))
                  if (q <= _had)
                    ActionChip(
                      label: Text('−${formatAmount(q, _unit)}'),
                      onPressed: _left > 0 ? () => _use(q) : null,
                    ),
                if (_had > 1 && _unit != 'pcs' && _unit != 'pack')
                  ActionChip(
                    label: const Text('Half'),
                    onPressed: () =>
                        setState(() => _left = roundAmount(_had / 2)),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _saving
                        ? null
                        : () {
                            setState(() => _left = 0);
                            _save();
                          },
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Used it all'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _saving || used == 0 ? null : _save,
                    child: Text(
                      _saving
                          ? 'Saving...'
                          : _left <= 0
                          ? 'Remove'
                          : used == 0
                          ? 'Update'
                          : 'Use ${formatAmount(used, _unit)}',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showItemSheet(
  BuildContext context,
  CollectionReference<Map<String, dynamic>> col, {
  QueryDocumentSnapshot<Map<String, dynamic>>? existing,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => _ItemForm(col: col, existing: existing),
  );
}

class _ItemForm extends StatefulWidget {
  final CollectionReference<Map<String, dynamic>> col;
  final QueryDocumentSnapshot<Map<String, dynamic>>? existing;
  const _ItemForm({required this.col, this.existing});

  @override
  State<_ItemForm> createState() => _ItemFormState();
}

class _ItemFormState extends State<_ItemForm> {
  late final TextEditingController _name;
  late final TextEditingController _qty;
  late String _unit;
  late String _category;
  late DateTime _expiry;
  bool _expiryTouched = false;
  bool _saving = false;
  String? _error;

  DateTime _defaultExpiry(String category) {
    final now = DateTime.now();
    return DateTime(
      now.year,
      now.month,
      now.day,
    ).add(Duration(days: shelfLifeDays[category] ?? 7));
  }

  @override
  void initState() {
    super.initState();
    final d = widget.existing?.data();
    _name = TextEditingController(text: d?['name'] ?? '');
    _qty = TextEditingController(
      text: formatNumber(d == null ? 1 : (quantityOf(d) ?? 1)),
    );
    _unit = d == null ? defaultUnit : unitOf(d);
    final c = d?['category'];
    _category = shelfLifeDays.containsKey(c) ? c : 'Vegetables';
    if (d != null) {
      _expiry = (d['expiryDate'] as Timestamp).toDate();
      _expiryTouched = true;
    } else {
      _expiry = _defaultExpiry(_category);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _qty.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiry,
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: now.add(const Duration(days: 3650)),
    );
    if (picked != null) {
      setState(() {
        _expiry = picked;
        _expiryTouched = true;
      });
    }
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final qty = parseAmount(_qty.text);
    if (name.isEmpty || qty == null || qty <= 0) {
      setState(() => _error = 'Enter a name and an amount above 0.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final data = {
      'name': name,
      'quantity': qty,
      'unit': _unit,
      'category': _category,
      'expiryDate': Timestamp.fromDate(_expiry),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    try {
      if (widget.existing == null) {
        await widget.col.add({
          ...data,
          'purchaseDate': Timestamp.now(),
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        await widget.existing!.reference.update(data);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not save: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.existing == null ? 'Add item' : 'Edit item',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Name (e.g. Eggs)'),
            ),
            const SizedBox(height: 12),
            AmountField(
              controller: _qty,
              unit: _unit,
              onUnitChanged: (u) => setState(() => _unit = u),
              hint: 'e.g. 2, 500, 1.5',
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: shelfLifeDays.keys
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) {
                if (v == null) return;
                setState(() {
                  _category = v;
                  if (!_expiryTouched) _expiry = _defaultExpiry(v);
                });
              },
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Expiry date (estimate)'),
              subtitle: Text(_fmt(_expiry)),
              trailing: const Icon(Icons.calendar_today),
              onTap: _pickDate,
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Saving...' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }
}
