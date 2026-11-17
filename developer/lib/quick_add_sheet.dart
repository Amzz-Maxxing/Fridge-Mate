import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'common_groceries.dart';
import 'recipes.dart';

CollectionReference<Map<String, dynamic>> _groceryCol() {
  final uid = FirebaseAuth.instance.currentUser!.uid;
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('groceryList');
}

/// Opens the quick-add sheet. [pantry] is used to mark items that are
/// already in the fridge.
Future<void> showQuickAddSheet(BuildContext context, List<PantryItem> pantry) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 1,
      builder: (context, scroll) =>
          _QuickAddSheet(pantry: pantry, scroll: scroll),
    ),
  );
}

class _QuickAddSheet extends StatefulWidget {
  final List<PantryItem> pantry;
  final ScrollController scroll;
  const _QuickAddSheet({required this.pantry, required this.scroll});

  @override
  State<_QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends State<_QuickAddSheet> {
  final _search = TextEditingController();
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _list =
      _groceryCol().where('checked', isEqualTo: false).snapshots();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// The unticked list entry for [label], if any. Matches the full label or
  /// its English name, so "Eggs" added from a recipe counts as "Eggs (telur)".
  QueryDocumentSnapshot<Map<String, dynamic>>? _onList(
      String label, List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final names = {
      label.toLowerCase(),
      groceryKeywords(label).first.toLowerCase(),
    };
    for (final d in docs) {
      if (names.contains('${d.data()['name']}'.toLowerCase())) return d;
    }
    return null;
  }

  Future<void> _add(String label) => _groceryCol().add({
        'name': label,
        'keywords': groceryKeywords(label),
        'checked': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

  Future<void> _toggle(String label,
      QueryDocumentSnapshot<Map<String, dynamic>>? existing) async {
    try {
      if (existing != null) {
        await existing.reference.delete();
      } else {
        await _add(label);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not update list: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _list,
      builder: (context, snap) {
        final docs = snap.data?.docs ?? const [];
        final query = _search.text.trim();
        final q = query.toLowerCase();

        final sections = <MapEntry<String, List<String>>>[];
        for (final e in commonGroceries.entries) {
          final items = q.isEmpty
              ? e.value
              : e.value.where((l) => l.toLowerCase().contains(q)).toList();
          if (items.isNotEmpty) sections.add(MapEntry(e.key, items));
        }
        final exactPreset = commonGroceries.values
            .expand((l) => l)
            .any((l) => groceryKeywords(l)
                .any((k) => k.toLowerCase() == q));

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Add to grocery list',
                        style: theme.textTheme.titleLarge),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(docs.isEmpty ? 'Done' : 'Done (${docs.length})'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _search,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: 'Search or type your own item',
                  isDense: true,
                  suffixIcon: query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => setState(_search.clear),
                        ),
                ),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) {
                  if (query.isNotEmpty && _onList(query, docs) == null) {
                    _add(query);
                    setState(_search.clear);
                  }
                },
              ),
            ),
            Expanded(
              child: ListView(
                controller: widget.scroll,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  if (query.isNotEmpty && !exactPreset)
                    _customRow(context, query, docs),
                  if (q.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Icon(Icons.kitchen,
                              size: 16, color: Colors.orange.shade800),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Tap to add, tap again to remove. '
                              'This icon means you already have it.',
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                  for (final s in sections) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 12, bottom: 6),
                      child: Text(s.key,
                          style: theme.textTheme.titleSmall?.copyWith(
                              color: theme.colorScheme.primary)),
                    ),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final label in s.value) _chip(label, docs),
                      ],
                    ),
                  ],
                  if (sections.isEmpty && query.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text('No common item matches "$query".',
                          style: theme.textTheme.bodySmall),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _chip(String label,
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final existing = _onList(label, docs);
    final inFridge = existing == null
        ? findInStock(widget.pantry, groceryKeywords(label))
        : null;
    return FilterChip(
      label: Text(label),
      selected: existing != null,
      avatar: inFridge == null
          ? null
          : Icon(Icons.kitchen, size: 16, color: Colors.orange.shade800),
      tooltip: inFridge == null ? null : 'In your fridge: ${inFridge.name}',
      onSelected: (_) => _toggle(label, existing),
    );
  }

  /// "Add `typed text`" row for items that aren't in the common list.
  Widget _customRow(BuildContext context, String query,
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final onList = _onList(query, docs) != null;
    final inFridge = findInStock(widget.pantry, [query]);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.add_circle_outline),
        title: Text('Add "$query"'),
        subtitle: onList
            ? const Text('Already on your list')
            : inFridge != null
                ? Text('You already have ${inFridge.name} in your fridge',
                    style: TextStyle(color: Colors.orange.shade800))
                : null,
        enabled: !onList,
        onTap: () {
          _add(query);
          setState(_search.clear);
        },
      ),
    );
  }
}
