// Saved grocery lists ("Monthly groceries", "Weekly basics"...): save the
// current list, then add a whole saved list back in one tap.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'amounts.dart';
import 'common_groceries.dart';
import 'grocery_screen.dart' show GroceryEntry, describeEntry, showGroceryItemDialog;

CollectionReference<Map<String, dynamic>> _userCol(String name) {
  final uid = FirebaseAuth.instance.currentUser!.uid;
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection(name);
}

typedef FirestoreDoc = QueryDocumentSnapshot<Map<String, dynamic>>;

/// Most items one saved list can hold.
const int maxSavedItems = 200;

GroceryEntry _entryFrom(Map<String, dynamic> m) =>
    (name: '${m['name']}', quantity: quantityOf(m), unit: unitOf(m));

Map<String, dynamic> _toMap(GroceryEntry e) => {
      'name': e.name,
      'keywords': groceryKeywords(e.name),
      if (e.quantity != null) 'quantity': e.quantity,
      if (e.quantity != null) 'unit': e.unit,
    };

List<GroceryEntry> _itemsOf(Map<String, dynamic> d) {
  final items = d['items'];
  if (items is! List) return [];
  return items
      .whereType<Map>()
      .map((m) => _entryFrom(Map<String, dynamic>.from(m)))
      .toList();
}

/// Removes repeated names (ignoring case), keeping the first.
List<GroceryEntry> _dedupe(Iterable<GroceryEntry> items) {
  final seen = <String>{};
  return [
    for (final e in items)
      if (seen.add(e.name.toLowerCase())) e,
  ];
}

/// Adds every item of a saved list to the grocery list, skipping items that
/// are already on it and not yet ticked off. Returns (added, skipped).
Future<(int, int)> applySavedList(List<GroceryEntry> items) async {
  final col = _userCol('groceryList');
  final current = await col.where('checked', isEqualTo: false).get();
  final onList =
      current.docs.map((d) => '${d.data()['name']}'.toLowerCase()).toSet();

  final batch = FirebaseFirestore.instance.batch();
  var added = 0;
  for (final e in items) {
    if (!onList.add(e.name.toLowerCase())) continue;
    batch.set(col.doc(), {
      ..._toMap(e),
      'checked': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
    added++;
  }
  if (added > 0) await batch.commit();
  return (added, items.length - added);
}

/// Bottom sheet listing saved lists. [current] is the grocery list as it is
/// now, offered for "Save current list".
Future<void> showSavedListsSheet(BuildContext context, List<FirestoreDoc> current) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scroll) =>
          _SavedListsSheet(current: current, scroll: scroll),
    ),
  );
}

class _SavedListsSheet extends StatelessWidget {
  final List<FirestoreDoc> current;
  final ScrollController scroll;
  const _SavedListsSheet({required this.current, required this.scroll});

  List<GroceryEntry> get _currentItems => _dedupe(current.map(
      (d) => _entryFrom(d.data()))); // ticked items included: it's a template

  Future<void> _saveCurrent(BuildContext context, List<FirestoreDoc> saved) async {
    final messenger = ScaffoldMessenger.of(context);
    final items = _currentItems.take(maxSavedItems).toList();
    final name = await _askName(context,
        title: 'Save current list',
        initial: 'Monthly groceries',
        existing: saved.map((d) => '${d.data()['name']}').toList());
    if (name == null) return;

    final match = saved
        .where((d) =>
            '${d.data()['name']}'.toLowerCase() == name.toLowerCase())
        .firstOrNull;
    final data = {
      'name': name,
      'items': items.map(_toMap).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    try {
      if (match != null) {
        await match.reference.update(data);
      } else {
        await _userCol('savedLists')
            .add({...data, 'createdAt': FieldValue.serverTimestamp()});
      }
      messenger.showSnackBar(SnackBar(
          content: Text(
              '${match != null ? 'Updated' : 'Saved'} "$name" (${items.length} items)')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not save: $e')));
    }
  }

  Future<void> _apply(BuildContext context, FirestoreDoc list) async {
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    try {
      final (added, skipped) = await applySavedList(_itemsOf(list.data()));
      nav.pop();
      messenger.showSnackBar(SnackBar(
        content: Text([
          added == 0
              ? 'Nothing new to add'
              : 'Added $added item${added == 1 ? '' : 's'} from "${list.data()['name']}"',
          if (skipped > 0) '$skipped already on your list',
        ].join(' · ')),
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not add: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _userCol('savedLists').orderBy('name').snapshots(),
      builder: (context, snap) {
        final saved = snap.data?.docs ?? const <FirestoreDoc>[];
        return ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            Text('Saved lists', style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Keep lists you buy often, like your monthly shop, and add the '
              'whole list in one tap.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: current.isEmpty
                      ? null
                      : () => _saveCurrent(context, saved),
                  icon: const Icon(Icons.bookmark_add_outlined),
                  label: const Text('Save current list'),
                ),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const SavedListEditor()),
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('New list'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (snap.hasError)
              Text('Error: ${snap.error}',
                  style: TextStyle(color: theme.colorScheme.error))
            else if (!snap.hasData)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (saved.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'No saved lists yet. Build your grocery list, then tap '
                  '"Save current list".',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
              )
            else
              for (final list in saved)
                Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    leading: const Icon(Icons.list_alt),
                    title: Text('${list.data()['name']}'),
                    subtitle: Text(_summary(_itemsOf(list.data()))),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => SavedListEditor(list: list),
                    )),
                    trailing: FilledButton(
                      onPressed: () => _apply(context, list),
                      child: const Text('Add'),
                    ),
                  ),
                ),
          ],
        );
      },
    );
  }

  static String _summary(List<GroceryEntry> items) {
    if (items.isEmpty) return 'Empty';
    final names = items.take(3).map((e) => e.name).join(', ');
    final more = items.length > 3 ? ' +${items.length - 3} more' : '';
    return '${items.length} item${items.length == 1 ? '' : 's'}: $names$more';
  }
}

/// Asks for a list name. Shows a note when it will replace an existing list.
Future<String?> _askName(
  BuildContext context, {
  required String title,
  String initial = '',
  List<String> existing = const [],
  String? keepName,
}) {
  final c = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        final name = c.text.trim();
        final replaces = name.isNotEmpty &&
            name.toLowerCase() != keepName?.toLowerCase() &&
            existing.any((e) => e.toLowerCase() == name.toLowerCase());
        return AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: c,
                autofocus: true,
                maxLength: 60,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'List name',
                ),
                onChanged: (_) => setState(() {}),
              ),
              if (replaces)
                Text('This will replace your saved list "$name".',
                    style: TextStyle(color: Colors.orange.shade800)),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: name.isEmpty ? null : () => Navigator.pop(ctx, name),
              child: Text(replaces ? 'Replace' : 'Save'),
            ),
          ],
        );
      },
    ),
  );
}

/// Create or edit a saved list: rename it, add, edit or remove items.
class SavedListEditor extends StatefulWidget {
  /// The list to edit, or null to create a new one.
  final FirestoreDoc? list;
  const SavedListEditor({super.key, this.list});

  @override
  State<SavedListEditor> createState() => _SavedListEditorState();
}

class _SavedListEditorState extends State<SavedListEditor> {
  late final TextEditingController _name = TextEditingController(
      text: widget.list == null ? '' : '${widget.list!.data()['name']}');
  late final List<GroceryEntry> _items =
      widget.list == null ? [] : _itemsOf(widget.list!.data());
  TextEditingController? _addField;
  bool _dirty = false;
  bool _saving = false;

  static final List<String> _catalogue =
      commonGroceries.values.expand((l) => l).toList();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _add(String text) {
    final name = text.trim();
    if (name.isEmpty) return;
    if (_items.any((e) => e.name.toLowerCase() == name.toLowerCase())) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$name is already in this list')));
      return;
    }
    if (_items.length >= maxSavedItems) return;
    setState(() {
      _items.add((name: name, quantity: null, unit: defaultUnit));
      _dirty = true;
    });
    _addField?.clear();
  }

  Future<void> _edit(int i) async {
    final e = await showGroceryItemDialog(
      context,
      initial: _items[i],
      onList: [
        for (var j = 0; j < _items.length; j++)
          if (j != i) _items[j].name,
      ],
      title: 'Edit item',
    );
    if (e == null) return;
    setState(() {
      _items[i] = e;
      _dirty = true;
    });
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Give the list a name first')));
      return;
    }
    setState(() => _saving = true);
    final data = {
      'name': name,
      'items': _dedupe(_items).map(_toMap).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    try {
      if (widget.list == null) {
        await _userCol('savedLists')
            .add({...data, 'createdAt': FieldValue.serverTimestamp()});
      } else {
        await widget.list!.reference.update(data);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not save: $e')));
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete saved list?'),
        content: Text('"${_name.text.trim()}" will be deleted. Your current '
            'grocery list is not affected.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    await widget.list!.reference.delete();
    if (mounted) Navigator.pop(context);
  }

  Future<bool> _confirmDiscard() async {
    if (!_dirty) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard changes?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep editing')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Discard')),
        ],
      ),
    );
    return ok == true;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final nav = Navigator.of(context);
        if (await _confirmDiscard()) {
          _dirty = false;
          nav.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.list == null ? 'New saved list' : 'Edit saved list'),
          actions: [
            if (widget.list != null)
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Delete list',
                onPressed: _delete,
              ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save_outlined),
              label: Text(_saving ? 'Saving...' : 'Save list'),
            ),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _name,
              maxLength: 60,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'List name (e.g. Monthly groceries)',
              ),
              onChanged: (_) => _dirty = true,
            ),
            const SizedBox(height: 4),
            Autocomplete<String>(
              optionsBuilder: (v) {
                final q = v.text.trim().toLowerCase();
                if (q.isEmpty) return const Iterable<String>.empty();
                return _catalogue
                    .where((l) => l.toLowerCase().contains(q))
                    .take(8);
              },
              onSelected: _add,
              fieldViewBuilder: (context, controller, focus, onSubmit) {
                _addField = controller;
                return TextField(
                  controller: controller,
                  focusNode: focus,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: 'Add an item',
                    hintText: 'Type to search, or enter your own',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.add),
                      tooltip: 'Add',
                      onPressed: () => _add(controller.text),
                    ),
                  ),
                  onSubmitted: (_) => _add(controller.text),
                );
              },
            ),
            const SizedBox(height: 16),
            Text(
              '${_items.length} item${_items.length == 1 ? '' : 's'} · '
              'tap an item to set an amount',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            if (_items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text('No items yet. Add some above.',
                    textAlign: TextAlign.center),
              ),
            for (var i = 0; i < _items.length; i++)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(describeEntry(
                    _items[i].name, _items[i].quantity, _items[i].unit)),
                onTap: () => _edit(i),
                trailing: IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Remove',
                  onPressed: () => setState(() {
                    _items.removeAt(i);
                    _dirty = true;
                  }),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
