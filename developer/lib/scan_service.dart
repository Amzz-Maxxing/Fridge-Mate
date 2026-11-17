// AI Fridge Scanner: sends a fridge photo to Gemini (through Firebase AI
// Logic, so no API key ships in the app) and cross-checks the detections
// against what the user already has.

import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_ai/firebase_ai.dart';
import 'ai_service.dart';
import 'amounts.dart';
import 'inventory_screen.dart' show shelfLifeDays;
import 'recipes.dart';

/// Gemini model used for scanning. Fast, cheap and multimodal.
/// Gemini model used for scanning (shared with the rest of the app).
const String scanModel = aiModel;

/// Detections below this confidence (after cross-checking) are flagged for
/// the user to double-check, and are not pre-selected.
const double confidenceThreshold = 0.6;

/// How much a detection's confidence goes up when it matches something the
/// user already has in their inventory.
const double expectedItemBoost = 0.15;

/// Most photos sent in one scan. Keeps the request small and fast.
const int maxPhotos = 8;

/// A photo to scan, with its image type.
class ScanImage {
  final Uint8List bytes;
  final String mimeType;
  const ScanImage(this.bytes, this.mimeType);
}

/// The image type for a file name, or null if Gemini can't read it
/// (for example .avif or .gif).
String? mimeTypeFor(String fileName) {
  final ext = fileName.split('.').last.toLowerCase();
  return switch (ext) {
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'webp' => 'image/webp',
    'heic' => 'image/heic',
    'heif' => 'image/heif',
    _ => null,
  };
}

/// One food item as returned by the model.
class RawDetection {
  final String name;
  final String category;
  final num quantity;
  final double confidence;
  final String unit;

  const RawDetection(this.name, this.category, this.quantity, this.confidence,
      {this.unit = defaultUnit});
}

/// A detection after cross-checking against the inventory.
class ScanDetection {
  final String name;
  final String category;
  final num quantity;
  final String unit;
  final double confidence;

  /// The inventory item this detection matches, if any.
  final PantryItem? existing;

  const ScanDetection({
    required this.name,
    required this.category,
    required this.quantity,
    required this.confidence,
    this.unit = defaultUnit,
    this.existing,
  });

  bool get lowConfidence => confidence < confidenceThreshold;
}

class ScanResult {
  final List<ScanDetection> detections;

  /// Inventory items that weren't seen in the photo. They may have been used
  /// up, or may just be hidden behind something.
  final List<PantryItem> notSeen;

  const ScanResult(this.detections, this.notSeen);
}

/// Thrown when the scan fails in a way the user should hear about.
class ScanException implements Exception {
  final String message;
  const ScanException(this.message);
  @override
  String toString() => message;
}

/// Cross-checks model detections against the inventory: boosts confidence
/// for expected items and lists inventory items that weren't detected.
ScanResult crossCheck(List<RawDetection> raw, List<PantryItem> pantry) {
  final seen = <PantryItem>{};
  final detections = <ScanDetection>[];
  for (final r in mergeDuplicates(raw)) {
    final match = findInStock(pantry, [r.name]);
    if (match != null) seen.add(match);
    final conf = (r.confidence + (match != null ? expectedItemBoost : 0))
        .clamp(0.0, 1.0)
        .toDouble();
    detections.add(ScanDetection(
      name: r.name,
      category: shelfLifeDays.containsKey(r.category) ? r.category : 'Other',
      quantity: r.quantity <= 0 ? 1 : roundAmount(r.quantity),
      unit: units.contains(r.unit) ? r.unit : defaultUnit,
      confidence: conf,
      existing: match,
    ));
  }
  // Best guesses first.
  detections.sort((a, b) => b.confidence.compareTo(a.confidence));

  final today = DateTime.now();
  final notSeen = pantry
      .where((p) =>
          !seen.contains(p) &&
          p.daysLeft(DateTime(today.year, today.month, today.day)) >= 0)
      .toList();
  return ScanResult(detections, notSeen);
}

/// Merges detections with the same name (ignoring case and plurals), which
/// happens when one item shows up in two photos. Keeps the higher quantity
/// rather than adding them up, since overlapping photos show the same item.
List<RawDetection> mergeDuplicates(List<RawDetection> raw) {
  String key(String name) {
    var k = name.toLowerCase().replaceAll(RegExp(r'[^a-z]+'), ' ').trim();
    if (k.endsWith('es') && k.length > 3) {
      k = k.substring(0, k.length - 2);
    } else if (k.endsWith('s') && k.length > 2) {
      k = k.substring(0, k.length - 1);
    }
    return k;
  }

  final merged = <String, RawDetection>{};
  for (final r in raw) {
    final k = key(r.name);
    final prev = merged[k];
    if (prev == null) {
      merged[k] = r;
    } else {
      merged[k] = RawDetection(
        prev.name,
        prev.category,
        r.quantity > prev.quantity ? r.quantity : prev.quantity,
        r.confidence > prev.confidence ? r.confidence : prev.confidence,
        unit: r.quantity > prev.quantity ? r.unit : prev.unit,
      );
    }
  }
  return merged.values.toList();
}

/// Parses the model's JSON reply into detections. Tolerates missing fields.
List<RawDetection> parseDetections(String json) {
  final decoded = jsonDecode(json);
  final list = decoded is Map ? decoded['items'] : decoded;
  if (list is! List) return const [];
  final out = <RawDetection>[];
  for (final e in list) {
    if (e is! Map) continue;
    final name = '${e['name'] ?? ''}'.trim();
    if (name.isEmpty) continue;
    out.add(RawDetection(
      name,
      '${e['category'] ?? 'Other'}',
      (e['quantity'] as num?) ?? 1,
      (e['confidence'] as num?)?.toDouble() ?? 0.5,
      unit: units.contains(e['unit']) ? e['unit'] as String : defaultUnit,
    ));
  }
  return out;
}

final _schema = Schema.object(properties: {
  'items': Schema.array(
    items: Schema.object(properties: {
      'name': Schema.string(
          description: 'Short common English name, e.g. "Eggs", "Milk".'),
      'category': Schema.enumString(enumValues: shelfLifeDays.keys.toList()),
      'quantity': Schema.number(
          description: 'Amount in the given unit, e.g. 6 (pcs), 1 (pack), '
              '1.2 (kg), 500 (g), 2 (L).'),
      'unit': Schema.enumString(
          enumValues: units,
          description: 'pcs for single items, pack for packs/cartons/trays, '
              'or a weight/volume when it is known (kg, g, L, ml).'),
      'confidence': Schema.number(
          description: 'How sure you are, from 0.0 to 1.0.'),
    }),
  ),
});

// ---------------------------------------------------------------------------
// Receipts
// ---------------------------------------------------------------------------

/// What a receipt scan found.
class ReceiptResult {
  final String? store;

  /// Purchase date printed on the receipt, if it could be read and is
  /// believable (not in the future, not more than 60 days ago).
  final DateTime? purchaseDate;
  final List<ScanDetection> detections;

  const ReceiptResult(this.store, this.purchaseDate, this.detections);
}

/// Reads a receipt date like "2026-11-14". Rejects unreadable, future or
/// very old dates, since those are almost always misreads.
DateTime? parseReceiptDate(String? raw, {DateTime? now}) {
  if (raw == null) return null;
  final d = DateTime.tryParse(raw.trim());
  if (d == null) return null;
  final n = now ?? DateTime.now();
  final today = DateTime(n.year, n.month, n.day);
  final day = DateTime(d.year, d.month, d.day);
  if (day.isAfter(today)) return null;
  if (today.difference(day).inDays > 60) return null;
  return day;
}

/// Parses the model's receipt JSON.
ReceiptResult parseReceipt(String json, List<PantryItem> pantry,
    {DateTime? now}) {
  final decoded = jsonDecode(json);
  if (decoded is! Map) throw const FormatException('Not a JSON object');
  final store = '${decoded['store'] ?? ''}'.trim();
  final raw = parseDetections(json);
  // Cross-check against the fridge only to show "you already have some".
  final detections = crossCheck(raw, pantry).detections;
  return ReceiptResult(
    store.isEmpty || store == 'null' ? null : store,
    parseReceiptDate(decoded['date'] as String?, now: now),
    detections,
  );
}

final _receiptSchema = Schema.object(
  properties: {
    'store': Schema.string(description: 'Shop name, if printed.'),
    'date': Schema.string(
        description: 'Purchase date as YYYY-MM-DD, if printed.'),
    'items': _schema.properties!['items']!,
  },
  optionalProperties: ['store', 'date'],
);

/// Scans one or more photos of a grocery receipt (long receipts can be
/// photographed in parts) and returns the food items on it.
///
/// [expected] are names from the user's grocery list, so the model reuses
/// them, which lets the app tick those items off.
Future<ReceiptResult> scanReceipt(List<ScanImage> images,
    List<PantryItem> pantry, List<String> expected) async {
  if (images.isEmpty) throw const ScanException('Add at least one photo.');
  final parts = images.length == 1
      ? 'a photo of a grocery receipt'
      : '${images.length} photos of one grocery receipt, in order (top to bottom)';
  final list = expected.toSet().join(', ');
  final text = await askGemini(_receiptSchema, images: _ai(images), '''
You are reading $parts from a shop in Malaysia.
List the FOOD and DRINK items that were bought.
- Receipt lines are abbreviated (for example "AYM PTG", "SUSU SEGAR 1L",
  "TELUR GRED A 10S"). Turn each into a short, plain English name a person
  would use at home, such as "Chicken", "Fresh milk", "Eggs".
- quantity and unit describe how much was bought. Use the weight or volume
  when it is printed ("AYAM 1.25KG" → 1.25 kg, "SUSU 1L" x2 → 2 L).
  Otherwise count packs or pieces ("TELUR 10S" x1 → 1 pack, "PISANG" x3 →
  3 pcs). Use the multiplier column when shown.
- Skip anything that isn't food or drink (detergent, tissue, bags,
  toiletries), and skip discounts, totals, tax, change and payment lines.
- Never include card numbers, membership numbers or any personal details.
- If the same product appears on several lines, combine them.
- confidence is how sure you are about what the product is.
- The user's grocery list has: ${list.isEmpty ? '(nothing)' : list}.
  If a product is one of these, use exactly that name.
- store is the shop name. date is the purchase date as YYYY-MM-DD.
Return JSON only.''');
  return parseReceipt(text, pantry);
}

// ---------------------------------------------------------------------------
// Gemini call shared by fridge and receipt scans
// ---------------------------------------------------------------------------

/// Scans one or more fridge photos in a single request and returns
/// cross-checked detections.
Future<ScanResult> scanFridge(
    List<ScanImage> images, List<PantryItem> pantry) async {
  if (images.isEmpty) throw const ScanException('Add at least one photo.');

  // Telling the model what we expect makes it reuse the user's own names
  // (so "Telur" stays "Telur") – this is the receipt-to-fridge cross-check.
  final expected = pantry.map((p) => p.name).toSet().join(', ');
  final photos = images.length == 1
      ? 'a photo of the inside of a household fridge or kitchen'
      : '${images.length} photos of the inside of a household fridge or kitchen';
  final text = await askGemini(_schema, images: _ai(images), '''
You are looking at $photos in Malaysia.
List every distinct food or drink item you can see across all photos.
- One entry per kind of item; set quantity to how many you can count, with
  unit pcs (single items) or pack (cartons, trays, packets). Only use kg, g,
  L or ml when the size is clearly printed on the package.
- If the same item appears in more than one photo, list it once.
- Ignore the fridge itself, shelves, and non-food objects.
- If unsure what something is, still include it with a low confidence.
- The user already has these items recorded: ${expected.isEmpty ? '(none)' : expected}.
  If you see one of them, use exactly that name.
Return JSON only.''');
  try {
    return crossCheck(parseDetections(text), pantry);
  } on FormatException {
    throw const ScanException(
        "Couldn't read the scanner's reply. Please try again.");
  }
}

List<AiImage> _ai(List<ScanImage> images) =>
    [for (final i in images) AiImage(i.bytes, i.mimeType)];
