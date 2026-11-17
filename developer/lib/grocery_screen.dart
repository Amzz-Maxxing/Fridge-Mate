import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'recipes.dart';
import 'amounts.dart';
import 'common_groceries.dart';
import 'quick_add_sheet.dart';
import 'saved_lists.dart';
import 'scan_screen.dart';
import 'shopping_history.dart';
import 'theme.dart';

CollectionReference<Map<String, dynamic>> _userCol(String name) {
  final uid = FirebaseAuth.instance.currentUser!.uid;
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection(name);
}

/// Live count of grocery items not yet ticked off, for the tab badge.
Stream<int> groceryToBuyCount() =>
    _userCol('groceryList')
        .where('checked', isEqualTo: false)
        .snapshots()
        .map((s) => s.size);

typedef _Doc = QueryDocumentSnapshot<Map<String, dynamic>>;

List<String> _keywordsOf(Map<String, dynamic> d) {
  final k = d['keywords'];
  if (k is List && k.isNotEmpty) return k.map((e) => '$e').toList();
  return ['${d['name']}'];
}

/// Smart grocery list: items added from recipes or by hand, ticked off while
/// shopping. Items already in the fridge are flagged to avoid buying twice.
class GroceryScreen extends StatelessWidget {
  const GroceryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _userCol('groceryList').snapshots(),
      builder: (context, listSnap) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _userCol('inventory').snapshots(),
          builder: (context, invSnap) {
            final docs = listSnap.data?.docs ?? <_Doc>[];
            final pantry = (invSnap.data?.docs ?? <_Doc>[]).map((doc) {
              final d = doc.data();
              return PantryItem(
                '${d['name']}',
                (d['expiryDate'] as Timestamp).toDate(),
              );
            }).toList();

            return Scaffold(
              appBar: AppBar(
                titleSpacing: 20,
                title: const Text('Shopping'),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.history),
                    tooltip: 'Shopping history',
                    style: IconButton.styleFrom(
                      backgroundColor: context.palette.soft,
                    ),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ShoppingHistoryScreen(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(Icons.bookmarks_outlined),
                    tooltip: 'Saved lists',
                    style: IconButton.styleFrom(
                      backgroundColor: context.palette.soft,
                    ),
                    onPressed: () => showSavedListsSheet(context, docs),
                  ),
                  const SizedBox(width: 12),
                ],
              ),
              floatingActionButton: SizedBox(
                width: 64,
                height: 64,
                child: FloatingActionButton(
                  heroTag: 'add-grocery',
                  tooltip: 'Add item',
                  onPressed: () => showQuickAddSheet(context, pantry),
                  child: const Icon(Icons.add, size: 30),
                ),
              ),
              body: _body(context, listSnap, docs, pantry),
            );
          },
        );
      },
    );
  }

  Widget _body(
    BuildContext context,
    AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snap,
    List<_Doc> docs,
    List<PantryItem> pantry,
  ) {
    if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
    if (!snap.hasData) return const Center(child: CircularProgressIndicator());
    if (docs.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 12),
            const Text(
              'Your grocery list is empty.\n'
              'Add items here, or from a recipe on the Meals tab.\n'
              'After shopping, scan your receipt to fill your fridge.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ScanScreen(receipt: true),
                ),
              ),
              icon: const Icon(Icons.receipt_long_outlined),
              label: const Text('Scan receipt'),
            ),
          ],
        ),
      );
    }

    // Newest first within each section. createdAt can be null for a moment
    // while a write is pending, so treat that as "just now".
    int byNewest(_Doc a, _Doc b) {
      final ta = a.data()['createdAt'] as Timestamp?;
      final tb = b.data()['createdAt'] as Timestamp?;
      if (ta == null) return -1;
      if (tb == null) return 1;
      return tb.compareTo(ta);
    }

    final toBuy = docs.where((d) => d.data()['checked'] != true).toList()
      ..sort(byNewest);
    final ticked = docs.where((d) => d.data()['checked'] == true).toList()
      ..sort(byNewest);

    return ListView(
      padding: const EdgeInsets.only(bottom: 120),
      children: [
        _progressCard(context, docs.length, ticked.length),
        _header(context, 'To buy · ${toBuy.length}'),
        if (toBuy.isEmpty)
          const ListTile(title: Text('All done! Everything is ticked off.')),
        ...toBuy.map((d) => _tile(context, d, docs, pantry)),
        if (ticked.isNotEmpty) ...[
          _header(
            context,
            'In the cart · ${ticked.length}',
            action: TextButton(
              onPressed: () => _clearTicked(context, docs),
              child: const Text('Save & clear'),
            ),
          ),
          ...ticked.map((d) => _tile(context, d, docs, pantry)),
        ],
      ],
    );
  }

  /// Forest card: how far through the shop you are, plus Scan receipt.
  Widget _progressCard(BuildContext context, int total, int done) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
    child: Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 12, 14),
      decoration: BoxDecoration(
        color: context.palette.hero,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$done of $total in the cart',
                  style: appFont(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: total == 0 ? 0 : done / total,
                    minHeight: 8,
                    color: brandLeaf,
                    backgroundColor: context.palette.heroTrack,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Tooltip(
            message: 'Scan receipt',
            child: Material(
              color: brandLeaf,
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ScanScreen(receipt: true),
                  ),
                ),
                child: const SizedBox(
                  width: 56,
                  height: 56,
                  child: Icon(
                    Icons.receipt_long_outlined,
                    color: inkOnLeaf,
                    semanticLabel: 'Scan receipt',
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _header(BuildContext context, String text, {Widget? action}) =>
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 12, 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontSize: 18),
              ),
            ),
            ?action,
          ],
        ),
      );

  Widget _tile(
    BuildContext context,
    _Doc doc,
    List<_Doc> all,
    List<PantryItem> pantry,
  ) {
    final d = doc.data();
    final checked = d['checked'] == true;
    final recipe = d['fromRecipe'] as String?;
    final inStock = checked ? null : findInStock(pantry, _keywordsOf(d));

    final subtitleParts = [
      if (recipe != null) 'For $recipe',
      if (inStock != null) 'Already in fridge: ${inStock.name}',
    ];

    return Dismissible(
      key: ValueKey(doc.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
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
      child: CheckboxListTile(
        controlAffinity: ListTileControlAffinity.leading,
        value: checked,
        onChanged: (v) => doc.reference.update({'checked': v ?? false}),
        title: Text(
          describeEntry('${d['name']}', quantityOf(d), unitOf(d)),
          style: checked
              ? TextStyle(
                  decoration: TextDecoration.lineThrough,
                  color: Theme.of(context).colorScheme.outline,
                )
              : null,
        ),
        subtitle: subtitleParts.isEmpty
            ? null
            : Text(
                subtitleParts.join('  •  '),
                style: inStock != null
                    ? TextStyle(color: Colors.orange.shade800)
                    : null,
              ),
        secondary: IconButton(
          icon: const Icon(Icons.edit_outlined),
          tooltip: 'Edit',
          onPressed: () => _addOrEdit(context, all, pantry, existing: doc),
        ),
      ),
    );
  }

  /// Clears ticked items and, by default, saves them as a shopping trip.
  /// Items already recorded through a scanned receipt aren't logged again.
  Future<void> _clearTicked(BuildContext context, List<_Doc> docs) async {
    final messenger = ScaffoldMessenger.of(context);
    final ticked = docs.where((d) => d.data()['checked'] == true).toList();
    final toLog = ticked
        .where((d) => d.data()['boughtViaReceipt'] != true)
        .toList();
    final store = TextEditingController();
    var save = toLog.isNotEmpty;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Clear ticked items?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Remove ${ticked.length} ticked '
                'item${ticked.length == 1 ? '' : 's'} from the list.',
              ),
              if (toLog.isNotEmpty) ...[
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: save,
                  onChanged: (v) => setState(() => save = v),
                  title: const Text('Save to shopping history'),
                  subtitle: Text(
                    toLog.length == ticked.length
                        ? 'Keeps a record of this trip'
                        : '${toLog.length} items (the rest were already '
                              'saved from a receipt)',
                  ),
                ),
                if (save)
                  TextField(
                    controller: store,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Shop (optional)',
                      hintText: 'e.g. Mydin, Lotus\'s',
                      isDense: true,
                    ),
                  ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(save && toLog.isNotEmpty ? 'Save & clear' : 'Clear'),
            ),
          ],
        ),
      ),
    );
    final storeName = store.text.trim();
    store.dispose();
    if (ok != true) return;

    final batch = FirebaseFirestore.instance.batch();
    for (final d in ticked) {
      batch.delete(d.reference);
    }
    final logged = save && toLog.isNotEmpty;
    if (logged) {
      addTripToBatch(
        batch,
        date: DateTime.now(),
        store: storeName.isEmpty ? null : storeName,
        source: TripSource.list,
        items: [
          for (final d in toLog)
            TripItem(
              '${d.data()['name']}',
              quantity: quantityOf(d.data()),
              unit: unitOf(d.data()),
            ),
        ],
      );
    }
    try {
      await batch.commit();
      if (logged) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Saved to your shopping history')),
        );
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not clear: $e')));
    }
  }

  Future<void> _addOrEdit(
    BuildContext context,
    List<_Doc> all,
    List<PantryItem> pantry, {
    _Doc? existing,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final d = existing?.data();
    final entry = await showGroceryItemDialog(
      context,
      initial: d == null
          ? null
          : (name: '${d['name']}', quantity: quantityOf(d), unit: unitOf(d)),
      onList: all
          .where((x) => x.id != existing?.id && x.data()['checked'] != true)
          .map((x) => '${x.data()['name']}')
          .toList(),
      pantry: pantry,
    );
    if (entry == null) return;
    try {
      if (existing == null) {
        await _userCol('groceryList').add({
          'name': entry.name,
          'keywords': groceryKeywords(entry.name),
          if (entry.quantity != null) 'quantity': entry.quantity,
          if (entry.quantity != null) 'unit': entry.unit,
          'checked': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        // A manual rename replaces the recipe keywords with the new name.
        await existing.reference.update({
          'name': entry.name,
          'keywords': groceryKeywords(entry.name),
          'quantity': entry.quantity ?? FieldValue.delete(),
          'unit': entry.quantity == null ? FieldValue.delete() : entry.unit,
        });
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not save: $e')));
    }
  }
}

/// A grocery item: name plus an optional amount ("Chicken", 1.5, "kg").
typedef GroceryEntry = ({String name, num? quantity, String unit});

/// "Chicken · 1.5 kg", or just "Chicken" when there's no amount.
String describeEntry(String name, num? quantity, String unit) =>
    quantity == null ? name : '$name · ${formatAmount(quantity, unit)}';

/// Dialog to add or edit a grocery item with an optional amount. Warns as
/// you type when the item is in [onList] or already in the fridge.
Future<GroceryEntry?> showGroceryItemDialog(
  BuildContext context, {
  GroceryEntry? initial,
  List<String> onList = const [],
  List<PantryItem> pantry = const [],
  String? title,
}) => showDialog<GroceryEntry>(
  context: context,
  builder: (_) => _GroceryItemDialog(
    initial: initial,
    onList: onList,
    pantry: pantry,
    title: title,
  ),
);

class _GroceryItemDialog extends StatefulWidget {
  final GroceryEntry? initial;
  final List<String> onList;
  final List<PantryItem> pantry;
  final String? title;

  const _GroceryItemDialog({
    required this.initial,
    required this.onList,
    required this.pantry,
    this.title,
  });

  @override
  State<_GroceryItemDialog> createState() => _GroceryItemDialogState();
}

class _GroceryItemDialogState extends State<_GroceryItemDialog> {
  late final TextEditingController _c = TextEditingController(
    text: widget.initial?.name ?? '',
  );
  late final TextEditingController _amount = TextEditingController(
    text: widget.initial?.quantity == null
        ? ''
        : formatNumber(widget.initial!.quantity!),
  );
  late String _unit = widget.initial?.unit ?? defaultUnit;

  bool get _isEdit => widget.initial != null;

  @override
  void dispose() {
    _c.dispose();
    _amount.dispose();
    super.dispose();
  }

  String? get _warning {
    final name = _c.text.trim();
    if (name.isEmpty) return null;
    final lower = name.toLowerCase();
    if (widget.onList.any((n) => n.toLowerCase() == lower)) {
      return '$name is already on your list.';
    }
    final inStock = findInStock(widget.pantry, [name]);
    if (inStock != null) {
      final today = DateTime.now();
      final days = inStock.daysLeft(
        DateTime(today.year, today.month, today.day),
      );
      final when = switch (days) {
        0 => 'expires today',
        1 => 'expires tomorrow',
        _ => 'expires in $days days',
      };
      return 'You already have ${inStock.name} in your fridge ($when).';
    }
    return null;
  }

  /// Blank amount is fine (no amount). Anything else must be a number > 0.
  bool get _amountValid {
    if (_amount.text.trim().isEmpty) return true;
    final q = parseAmount(_amount.text);
    return q != null && q > 0;
  }

  void _submit() {
    final name = _c.text.trim();
    if (name.isEmpty || !_amountValid) return;
    Navigator.pop<GroceryEntry>(context, (
      name: name,
      quantity: parseAmount(_amount.text),
      unit: _unit,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final warning = _warning;
    return AlertDialog(
      title: Text(
        widget.title ?? (_isEdit ? 'Edit item' : 'Add to grocery list'),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _c,
              autofocus: !_isEdit,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Item (e.g. Eggs)'),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 12),
            AmountField(
              controller: _amount,
              unit: _unit,
              onUnitChanged: (u) => setState(() => _unit = u),
              label: 'Amount (optional)',
              hint: 'e.g. 2 or 500',
            ),
            if (!_amountValid)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Enter a number above 0, or leave it blank.',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (warning != null) ...[
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 18,
                    color: Colors.orange.shade800,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      warning,
                      style: TextStyle(color: Colors.orange.shade800),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _c.text.trim().isEmpty || !_amountValid ? null : _submit,
          child: Text(
            warning != null
                ? (_isEdit ? 'Save anyway' : 'Add anyway')
                : (_isEdit ? 'Save' : 'Add'),
          ),
        ),
      ],
    );
  }
}
