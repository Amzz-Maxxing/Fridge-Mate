import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'amounts.dart';
import 'inventory_screen.dart' show shelfLifeDays;
import 'recipes.dart';
import 'scan_service.dart';
import 'shopping_history.dart';

String _fmt(DateTime d) => '${d.day}/${d.month}/${d.year}';

DateTime _today() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

/// Estimated expiry: the purchase day plus the category's shelf life.
DateTime _defaultExpiry(String category, DateTime purchased) =>
    purchased.add(Duration(days: shelfLifeDays[category] ?? 7));

typedef _GroceryDoc = QueryDocumentSnapshot<Map<String, dynamic>>;

/// An editable row on the review screen.
class _Row {
  final TextEditingController name;
  String category;
  num quantity;
  String unit;
  DateTime expiry;
  bool selected;
  final double? confidence; // null for rows the user added by hand
  final PantryItem? existing;

  _Row({
    required String name,
    required this.category,
    required this.quantity,
    required this.selected,
    required DateTime purchased,
    this.unit = defaultUnit,
    this.confidence,
    this.existing,
  })  : name = TextEditingController(text: name),
        expiry = _defaultExpiry(category, purchased);

  bool get lowConfidence =>
      confidence != null && confidence! < confidenceThreshold;
}

enum _Stage { pick, scanning, review }

/// Take or pick photos of the fridge (or of a grocery receipt), let the AI
/// find the food, then review and correct the results before they're added
/// to the inventory.
class ScanScreen extends StatefulWidget {
  /// Receipt mode: reads a shop receipt instead of a fridge photo, uses the
  /// receipt date as the purchase date, and ticks off grocery list items.
  final bool receipt;

  const ScanScreen({super.key, this.receipt = false});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  _Stage _stage = _Stage.pick;
  String? _error;
  bool _saving = false;

  // Photos waiting to be scanned.
  final _photos = <ScanImage>[];

  final _rows = <_Row>[];
  // Inventory items not seen in the photo, and whether to remove them.
  final _notSeen = <PantryItem, bool>{};
  final _refs = <PantryItem, DocumentReference<Map<String, dynamic>>>{};

  // Receipt mode only.
  DateTime _purchased = _today();
  String? _store;
  // Grocery list items bought on this receipt, and whether to tick them off.
  final _groceryTicks = <_GroceryDoc, bool>{};

  bool get _receipt => widget.receipt;

  CollectionReference<Map<String, dynamic>> _userCol(String name) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection(name);
  }

  CollectionReference<Map<String, dynamic>> get _col => _userCol('inventory');

  @override
  void dispose() {
    for (final r in _rows) {
      r.name.dispose();
    }
    super.dispose();
  }

  int get _spaceLeft => maxPhotos - _photos.length;

  /// Adds photos to the tray: one from the camera, or several from the
  /// gallery. Unsupported formats are skipped with a message.
  Future<void> _addPhotos(ImageSource source) async {
    if (_spaceLeft <= 0) return;
    final List<XFile> picked;
    try {
      final picker = ImagePicker();
      if (source == ImageSource.camera) {
        final photo = await picker.pickImage(
          source: ImageSource.camera,
          // Fridge photos are taken with the back camera.
          preferredCameraDevice: CameraDevice.rear,
          maxWidth: 1600,
          maxHeight: 1600,
          imageQuality: 80,
        );
        picked = [?photo];
      } else {
        picked = await picker.pickMultiImage(
          maxWidth: 1600,
          maxHeight: 1600,
          imageQuality: 80,
          limit: _spaceLeft,
        );
      }
    } catch (e) {
      setState(() => _error = 'Could not open the camera or gallery: $e');
      return;
    }
    if (picked.isEmpty) return; // user cancelled

    final skipped = <String>[];
    final added = <ScanImage>[];
    for (final f in picked.take(_spaceLeft)) {
      final mime = mimeTypeFor(f.name) ?? mimeTypeFor(f.path);
      if (mime == null) {
        skipped.add(f.name);
        continue;
      }
      added.add(ScanImage(await f.readAsBytes(), mime));
    }
    if (!mounted) return;
    setState(() {
      _photos.addAll(added);
      _error = skipped.isEmpty
          ? null
          : 'Skipped ${skipped.join(', ')}: only JPG, PNG, WebP and HEIC '
              'photos can be scanned.';
    });
  }

  Future<void> _scan() async {
    if (_photos.isEmpty) return;
    setState(() {
      _stage = _Stage.scanning;
      _error = null;
    });

    try {
      final snap = await _col.get();
      _refs.clear();
      final pantry = snap.docs.map((doc) {
        final d = doc.data();
        final item = PantryItem(
            '${d['name']}', (d['expiryDate'] as Timestamp).toDate());
        _refs[item] = doc.reference;
        return item;
      }).toList();

      final List<ScanDetection> detections;
      _notSeen.clear();
      _groceryTicks.clear();
      if (_receipt) {
        final list = (await _userCol('groceryList')
                .where('checked', isEqualTo: false)
                .get())
            .docs;
        final result = await scanReceipt(List.of(_photos), pantry,
            list.map((d) => '${d.data()['name']}').toList());
        detections = result.detections;
        _store = result.store;
        _purchased = result.purchaseDate ?? _today();
        // Grocery items that appear on the receipt get ticked off.
        for (final doc in list) {
          final k = doc.data()['keywords'];
          final keywords = k is List && k.isNotEmpty
              ? k.map((e) => '$e').toList()
              : ['${doc.data()['name']}'];
          if (detections.any((d) => namesMatch(d.name, keywords))) {
            _groceryTicks[doc] = true;
          }
        }
      } else {
        final result = await scanFridge(List.of(_photos), pantry);
        detections = result.detections;
        _purchased = _today();
        _notSeen.addEntries(result.notSeen.map((p) => MapEntry(p, false)));
      }
      if (!mounted) return;

      for (final r in _rows) {
        r.name.dispose();
      }
      _rows
        ..clear()
        ..addAll(detections.map((d) => _Row(
              name: d.name,
              category: d.category,
              quantity: d.quantity,
              unit: d.unit,
              confidence: d.confidence,
              existing: d.existing,
              purchased: _purchased,
              // Fridge: pre-select confident, new items only. Receipt: you
              // bought it, so it's new stock even if you already had some.
              selected: !d.lowConfidence && (_receipt || d.existing == null),
            )));
      setState(() => _stage = _Stage.review);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _stage = _Stage.pick;
        _error = '$e';
      });
    }
  }

  int get _addCount =>
      _rows.where((r) => r.selected && r.name.text.trim().isNotEmpty).length;
  int get _removeCount => _notSeen.values.where((v) => v).length;
  int get _tickCount => _groceryTicks.values.where((v) => v).length;

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final batch = FirebaseFirestore.instance.batch();
      for (final r in _rows) {
        final name = r.name.text.trim();
        if (!r.selected || name.isEmpty) continue;
        batch.set(_col.doc(), {
          'name': name,
          'quantity': r.quantity,
          'unit': r.unit,
          'category': r.category,
          'expiryDate': Timestamp.fromDate(r.expiry),
          'purchaseDate': _receipt
              ? Timestamp.fromDate(_purchased)
              : Timestamp.now(),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      _notSeen.forEach((item, remove) {
        final ref = _refs[item];
        if (remove && ref != null) batch.delete(ref);
      });
      _groceryTicks.forEach((doc, tick) {
        // Marked so clearing the list later doesn't log this purchase twice.
        if (tick) {
          batch.update(
              doc.reference, {'checked': true, 'boughtViaReceipt': true});
        }
      });
      if (_receipt) {
        addTripToBatch(
          batch,
          date: _purchased,
          store: _store,
          source: TripSource.receipt,
          items: [
            for (final r in _rows)
              if (r.selected && r.name.text.trim().isNotEmpty)
                TripItem(r.name.text.trim(),
                    quantity: r.quantity, unit: r.unit, category: r.category),
          ],
        );
      }
      await batch.commit();
      if (!mounted) return;
      final added = _addCount, removed = _removeCount, ticked = _tickCount;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text([
          if (added > 0)
            'Added $added item${added == 1 ? '' : 's'} to your fridge',
          if (removed > 0) 'removed $removed',
          if (ticked > 0) 'ticked off $ticked on your grocery list',
        ].join(', ')),
      ));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not save: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_stage == _Stage.review
            ? 'Check what we found'
            : (_receipt ? 'Scan receipt' : 'Scan fridge')),
        actions: [
          if (_stage == _Stage.review)
            IconButton(
              icon: const Icon(Icons.camera_alt_outlined),
              tooltip: 'Scan again',
              onPressed: () => setState(() {
                _photos.clear();
                _stage = _Stage.pick;
              }),
            ),
        ],
      ),
      body: switch (_stage) {
        _Stage.pick => _pickView(context),
        _Stage.scanning => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(_receipt
                    ? 'Reading your receipt...'
                    : _photos.length == 1
                        ? 'Looking for food in your photo...'
                        : 'Looking for food in ${_photos.length} photos...'),
              ],
            ),
          ),
        _Stage.review => _reviewView(context),
      },
      bottomNavigationBar: _stage != _Stage.review
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton.icon(
                  onPressed:
                      _saving || (_addCount + _removeCount + _tickCount == 0)
                          ? null
                          : _save,
                  icon: const Icon(Icons.check),
                  label: Text(_saving
                      ? 'Saving...'
                      : [
                          'Add $_addCount to fridge',
                          if (_removeCount > 0) 'remove $_removeCount',
                          if (_tickCount > 0) 'tick off $_tickCount',
                        ].join(', ')),
                ),
              ),
            ),
    );
  }

  Widget _pickView(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
                _receipt
                    ? Icons.receipt_long_outlined
                    : Icons.document_scanner_outlined,
                size: 64,
                color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(_receipt ? 'Snap your receipt' : 'Snap your fridge',
                style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              _receipt
                  ? 'Lay the receipt flat in good light. For a long receipt, '
                      'take it in parts from top to bottom (up to $maxPhotos '
                      'photos). Food items go into your fridge and get ticked '
                      'off your grocery list.'
                  : 'Take a photo of each shelf, or pick several photos at '
                      "once (up to $maxPhotos). They're scanned together, and "
                      "you can check and fix everything before it's saved.",
              textAlign: TextAlign.center,
            ),
            if (_photos.isNotEmpty) ...[
              const SizedBox(height: 16),
              _photoTray(context),
            ],
            const SizedBox(height: 24),
            if (_photos.isNotEmpty) ...[
              FilledButton.icon(
                onPressed: _scan,
                icon: const Icon(Icons.auto_awesome),
                label: Text(_photos.length == 1
                    ? 'Scan 1 photo'
                    : 'Scan ${_photos.length} photos'),
              ),
              const SizedBox(height: 8),
            ],
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                if (_photos.isEmpty)
                  FilledButton.icon(
                    onPressed: () => _addPhotos(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Take photo'),
                  )
                else
                  OutlinedButton.icon(
                    onPressed: _spaceLeft > 0
                        ? () => _addPhotos(ImageSource.camera)
                        : null,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Take another'),
                  ),
                OutlinedButton.icon(
                  onPressed: _spaceLeft > 0
                      ? () => _addPhotos(ImageSource.gallery)
                      : null,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: Text(_photos.isEmpty
                      ? 'Choose from gallery'
                      : 'Add from gallery'),
                ),
              ],
            ),
            if (_spaceLeft <= 0) ...[
              const SizedBox(height: 8),
              Text('That\'s the maximum of $maxPhotos photos per scan.',
                  style: theme.textTheme.bodySmall),
            ],
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: theme.colorScheme.error)),
            ],
            const SizedBox(height: 24),
            Text(
              _receipt
                  ? 'Your receipt photo is sent to Google Gemini to read the '
                      'food items. Only item names, quantities and the date '
                      'are kept; prices and payment details are not stored.'
                  : 'Your photo is sent to Google Gemini to identify food and '
                      'is not stored by Fridge Mate.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  /// Thumbnails of the photos waiting to be scanned, each with a remove button.
  Widget _photoTray(BuildContext context) => Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: [
          for (var i = 0; i < _photos.length; i++)
            Stack(
              clipBehavior: Clip.none,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    _photos[i].bytes,
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                    cacheWidth: 240,
                  ),
                ),
                Positioned(
                  top: -8,
                  right: -8,
                  child: IconButton.filledTonal(
                    visualDensity: VisualDensity.compact,
                    iconSize: 16,
                    tooltip: 'Remove photo',
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => _photos.removeAt(i)),
                  ),
                ),
              ],
            ),
        ],
      );

  Widget _reviewView(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      children: [
        if (_receipt) _receiptHeader(context),
        if (_rows.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              _receipt
                  ? "We couldn't find any food items on that receipt. Try a "
                      'sharper photo, or add items by hand below.'
                  : "We couldn't spot any food in that photo. Try again with "
                      'more light, or add items by hand below.',
              textAlign: TextAlign.center,
            ),
          ),
        ..._rows.map((r) => _rowCard(context, r)),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => setState(() => _rows.add(_Row(
                  name: '',
                  category: 'Other',
                  quantity: 1,
                  selected: true,
                  purchased: _purchased,
                ))),
            icon: const Icon(Icons.add),
            label: const Text('Add something we missed'),
          ),
        ),
        if (_notSeen.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('Not seen in the photo', style: theme.textTheme.titleMedium),
          const SizedBox(height: 2),
          Text(
            'These are in your fridge list but weren\'t spotted. They may be '
            'hidden. Tick any you\'ve used up to remove them.',
            style: theme.textTheme.bodySmall,
          ),
          ..._notSeen.keys.map((p) => CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: _notSeen[p],
                onChanged: (v) => setState(() => _notSeen[p] = v ?? false),
                title: Text(p.name),
                subtitle: Text('Expires ${_fmt(p.expiry)} · tick to remove'),
              )),
        ],
        if (_groceryTicks.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('On your grocery list', style: theme.textTheme.titleMedium),
          const SizedBox(height: 2),
          Text('These were on the receipt, so they\'ll be ticked off.',
              style: theme.textTheme.bodySmall),
          ..._groceryTicks.keys.map((doc) => CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: _groceryTicks[doc],
                onChanged: (v) =>
                    setState(() => _groceryTicks[doc] = v ?? false),
                title: Text('${doc.data()['name']}'),
              )),
        ],
      ],
    );
  }

  /// Shop name and purchase date. The date sets every item's estimated
  /// expiry, so it can be corrected here.
  Widget _receiptHeader(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (_store != null)
            Text(_store!, style: theme.textTheme.titleMedium),
          ActionChip(
            avatar: const Icon(Icons.event, size: 16),
            label: Text('Bought ${_fmt(_purchased)}'),
            tooltip: 'Change purchase date',
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _purchased,
                firstDate: _today().subtract(const Duration(days: 60)),
                lastDate: _today(),
              );
              if (picked == null) return;
              setState(() {
                _purchased = picked;
                for (final r in _rows) {
                  r.expiry = _defaultExpiry(r.category, picked);
                }
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _rowCard(BuildContext context, _Row r) {
    final warn = Colors.orange.shade800;
    final notes = [
      if (r.existing != null)
        _receipt
            ? 'You also have some in your fridge ("${r.existing!.name}")'
            : 'Already in fridge as "${r.existing!.name}"',
      if (r.lowConfidence) 'Not sure about this one, please check',
    ];

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 12, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: r.selected,
              onChanged: (v) => setState(() => r.selected = v ?? false),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: r.name,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      isDense: true,
                      hintText: 'Item name',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  if (notes.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(notes.join(' · '),
                        style: TextStyle(color: warn, fontSize: 12)),
                  ],
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      DropdownButton<String>(
                        value: r.category,
                        isDense: true,
                        underline: const SizedBox.shrink(),
                        items: shelfLifeDays.keys
                            .map((c) =>
                                DropdownMenuItem(value: c, child: Text(c)))
                            .toList(),
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() {
                            r.category = v;
                            r.expiry = _defaultExpiry(v, _purchased);
                          });
                        },
                      ),
                      _qty(r),
                      ActionChip(
                        avatar: const Icon(Icons.event, size: 16),
                        label: Text(_fmt(r.expiry)),
                        onPressed: () => _pickDate(r),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// − amount + with a unit dropdown. Steps follow the unit (1 pcs, 100 g,
  /// 0.5 kg...). Tap the amount to type an exact value.
  Widget _qty(_Row r) {
    final step = stepFor(r.unit);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.remove_circle_outline, size: 20),
          onPressed: r.quantity > step
              ? () => setState(() => r.quantity = roundAmount(r.quantity - step))
              : null,
        ),
        InkWell(
          onTap: () => _typeAmount(r),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
            child: Text(formatNumber(r.quantity)),
          ),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.add_circle_outline, size: 20),
          onPressed: () =>
              setState(() => r.quantity = roundAmount(r.quantity + step)),
        ),
        DropdownButton<String>(
          value: r.unit,
          isDense: true,
          underline: const SizedBox.shrink(),
          items: units
              .map((u) => DropdownMenuItem(value: u, child: Text(u)))
              .toList(),
          onChanged: (u) {
            if (u != null) setState(() => r.unit = u);
          },
        ),
      ],
    );
  }

  Future<void> _typeAmount(_Row r) async {
    final c = TextEditingController(text: formatNumber(r.quantity));
    final value = await showDialog<num>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Amount (${r.unit})'),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onSubmitted: (_) => Navigator.pop(ctx, parseAmount(c.text)),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, parseAmount(c.text)),
              child: const Text('OK')),
        ],
      ),
    );
    c.dispose();
    if (value != null && value > 0) setState(() => r.quantity = value);
  }

  Future<void> _pickDate(_Row r) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: r.expiry,
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: now.add(const Duration(days: 3650)),
    );
    if (picked != null) setState(() => r.expiry = picked);
  }
}
