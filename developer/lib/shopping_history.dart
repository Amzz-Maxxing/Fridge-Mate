// Shopping history: each shopping trip (from a scanned receipt, or from
// ticking off the grocery list) is kept as users/{uid}/shoppingTrips/{id}.
// Prices are not stored, in line with the app's privacy promise.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'amounts.dart';
import 'grocery_screen.dart' show GroceryEntry, describeEntry;
import 'saved_lists.dart' show applySavedList;

CollectionReference<Map<String, dynamic>> _tripsCol() {
  final uid = FirebaseAuth.instance.currentUser!.uid;
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('shoppingTrips');
}

/// Most items kept for one trip.
const int maxTripItems = 200;

/// Where a trip was recorded from.
enum TripSource {
  receipt('Scanned receipt', Icons.receipt_long_outlined),
  list('Grocery list', Icons.checklist);

  final String label;
  final IconData icon;
  const TripSource(this.label, this.icon);
}

/// One item bought on a trip.
class TripItem {
  final String name;
  final num? quantity;
  final String unit;
  final String? category;

  const TripItem(this.name,
      {this.quantity, this.unit = defaultUnit, this.category});

  Map<String, dynamic> toMap() => {
        'name': name,
        if (quantity != null) 'quantity': quantity,
        if (quantity != null) 'unit': unit,
        if (category != null) 'category': category,
      };

  static TripItem fromMap(Map<String, dynamic> m) => TripItem(
        '${m['name']}',
        quantity: quantityOf(m),
        unit: unitOf(m),
        category: m['category'] as String?,
      );
}

/// A shopping trip read from Firestore.
class ShoppingTrip {
  final String id;
  final DateTime date;
  final String? store;
  final TripSource source;
  final List<TripItem> items;
  final DocumentReference<Map<String, dynamic>>? ref;

  ShoppingTrip(this.id, this.date, this.store, this.source, this.items,
      [this.ref]);

  static ShoppingTrip fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data();
    final items = m['items'];
    return ShoppingTrip(
      d.id,
      (m['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      m['store'] as String?,
      TripSource.values.firstWhere((s) => s.name == m['source'],
          orElse: () => TripSource.list),
      items is List
          ? items
              .whereType<Map>()
              .map((e) => TripItem.fromMap(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
      d.reference,
    );
  }
}

/// Adds a new trip to [batch], so it's saved together with the rest of the
/// change (e.g. the fridge items from a receipt).
void addTripToBatch(
  WriteBatch batch, {
  required DateTime date,
  required TripSource source,
  required List<TripItem> items,
  String? store,
}) {
  if (items.isEmpty) return;
  batch.set(_tripsCol().doc(), {
    'date': Timestamp.fromDate(date),
    if (store != null && store.trim().isNotEmpty) 'store': store.trim(),
    'source': source.name,
    'items': items.take(maxTripItems).map((i) => i.toMap()).toList(),
    'createdAt': FieldValue.serverTimestamp(),
  });
}

// ---------------------------------------------------------------------------
// Stats (pure functions, so they can be tested)
// ---------------------------------------------------------------------------

/// How many times each item was bought across [trips], most first. Names
/// are compared ignoring case; the first spelling seen is shown.
List<MapEntry<String, int>> mostBought(List<ShoppingTrip> trips,
    {int limit = 8}) {
  final counts = <String, int>{};
  final display = <String, String>{};
  for (final t in trips) {
    // Count each item once per trip.
    final seen = <String>{};
    for (final i in t.items) {
      final k = i.name.trim().toLowerCase();
      if (k.isEmpty || !seen.add(k)) continue;
      counts[k] = (counts[k] ?? 0) + 1;
      display.putIfAbsent(k, () => i.name.trim());
    }
  }
  final list = counts.entries
      .map((e) => MapEntry(display[e.key]!, e.value))
      .toList()
    ..sort((a, b) {
      final c = b.value.compareTo(a.value);
      return c != 0 ? c : a.key.compareTo(b.key);
    });
  return list.take(limit).toList();
}

/// Trips in the same calendar month as [now].
List<ShoppingTrip> tripsThisMonth(List<ShoppingTrip> trips, {DateTime? now}) {
  final n = now ?? DateTime.now();
  return trips
      .where((t) => t.date.year == n.year && t.date.month == n.month)
      .toList();
}

const _months = [
  'January', 'February', 'March', 'April', 'May', 'June', 'July',
  'August', 'September', 'October', 'November', 'December',
];

String _fmt(DateTime d) => '${d.day}/${d.month}/${d.year}';
String _monthLabel(DateTime d) => '${_months[d.month - 1]} ${d.year}';

// ---------------------------------------------------------------------------
// Screens
// ---------------------------------------------------------------------------

/// All past shopping trips, newest first, grouped by month, with a summary
/// of this month and the most-bought items.
class ShoppingHistoryScreen extends StatelessWidget {
  const ShoppingHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Shopping history')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _tripsCol().orderBy('date', descending: true).snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final trips = snap.data!.docs.map(ShoppingTrip.fromDoc).toList();
          if (trips.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.history,
                        size: 48, color: theme.colorScheme.outline),
                    const SizedBox(height: 12),
                    const Text(
                      'No shopping trips yet.\n\nScan a receipt, or tick off '
                      'your grocery list and tap "Clear", and your trips '
                      'will appear here.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          final month = tripsThisMonth(trips);
          final monthItems =
              month.fold<int>(0, (total, t) => total + t.items.length);
          final top = mostBought(trips);

          final children = <Widget>[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('This month', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _Stat(value: '${month.length}',
                            label: month.length == 1 ? 'trip' : 'trips'),
                        const SizedBox(width: 24),
                        _Stat(value: '$monthItems',
                            label: monthItems == 1 ? 'item' : 'items'),
                        const SizedBox(width: 24),
                        _Stat(value: '${trips.length}', label: 'trips in total'),
                      ],
                    ),
                    if (top.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text('You buy most often',
                          style: theme.textTheme.titleSmall),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final e in top)
                            Chip(
                              visualDensity: VisualDensity.compact,
                              label: Text('${e.key} ×${e.value}'),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ];

          String? lastMonth;
          for (final t in trips) {
            final m = _monthLabel(t.date);
            if (m != lastMonth) {
              lastMonth = m;
              children.add(Padding(
                padding: const EdgeInsets.fromLTRB(4, 16, 4, 4),
                child: Text(m,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(color: theme.colorScheme.primary)),
              ));
            }
            children.add(_TripTile(trip: t));
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
            children: children,
          );
        },
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  const _Stat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: Theme.of(context).textTheme.headlineSmall),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      );
}

class _TripTile extends StatelessWidget {
  final ShoppingTrip trip;
  const _TripTile({required this.trip});

  @override
  Widget build(BuildContext context) {
    final names = trip.items.take(4).map((i) => i.name).join(', ');
    final more = trip.items.length > 4 ? ' +${trip.items.length - 4} more' : '';
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(child: Icon(trip.source.icon, size: 20)),
        title: Text(trip.store ?? trip.source.label),
        subtitle: Text(
          '${_fmt(trip.date)} · ${trip.items.length} '
          'item${trip.items.length == 1 ? '' : 's'}\n$names$more',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        isThreeLine: true,
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => TripDetailScreen(trip: trip),
        )),
      ),
    );
  }
}

/// One trip: everything bought, with "Buy again" and delete.
class TripDetailScreen extends StatefulWidget {
  final ShoppingTrip trip;
  const TripDetailScreen({super.key, required this.trip});

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  bool _busy = false;

  Future<void> _buyAgain() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final entries = <GroceryEntry>[
        for (final i in widget.trip.items)
          (name: i.name, quantity: i.quantity, unit: i.unit),
      ];
      final (added, skipped) = await applySavedList(entries);
      messenger.showSnackBar(SnackBar(
        content: Text([
          added == 0
              ? 'Nothing new to add'
              : 'Added $added item${added == 1 ? '' : 's'} to your grocery list',
          if (skipped > 0) '$skipped already on it',
        ].join(' · ')),
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not add: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this trip?'),
        content: const Text(
            'It will be removed from your shopping history. Your fridge and '
            'grocery list are not affected.'),
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
    await widget.trip.ref?.delete();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.trip;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(t.store ?? 'Shopping trip'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete trip',
            onPressed: _delete,
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            onPressed: _busy || t.items.isEmpty ? null : _buyAgain,
            icon: const Icon(Icons.replay),
            label: Text(_busy ? 'Adding...' : 'Buy again'),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Icon(t.source.icon, size: 18),
              const SizedBox(width: 6),
              Text('${t.source.label} · ${_fmt(t.date)}',
                  style: theme.textTheme.bodyMedium),
            ],
          ),
          const SizedBox(height: 12),
          Text('${t.items.length} item${t.items.length == 1 ? '' : 's'}',
              style: theme.textTheme.titleMedium),
          const Divider(),
          for (final i in t.items)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.shopping_bag_outlined),
              title: Text(describeEntry(i.name, i.quantity, i.unit)),
              subtitle: i.category == null ? null : Text(i.category!),
            ),
        ],
      ),
    );
  }
}
