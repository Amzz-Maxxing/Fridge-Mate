import 'package:flutter_test/flutter_test.dart';
import 'package:fridge_mate/common_groceries.dart';
import 'package:fridge_mate/recipes.dart';

void main() {
  test('groceryKeywords splits English and Malay names', () {
    expect(groceryKeywords('Eggs (telur)'), ['Eggs', 'telur']);
    expect(groceryKeywords('Shallots (bawang merah)'), ['Shallots', 'bawang merah']);
    expect(groceryKeywords('Kangkung'), ['Kangkung']);
  });

  test('common items are spotted in the fridge by either name', () {
    final pantry = [
      PantryItem('Telur ayam', DateTime.now().add(const Duration(days: 5))),
      PantryItem('Santan kotak', DateTime.now().add(const Duration(days: 2))),
    ];
    expect(findInStock(pantry, groceryKeywords('Eggs (telur)')), isNotNull);
    expect(findInStock(pantry, groceryKeywords('Coconut milk (santan)')), isNotNull);
    expect(findInStock(pantry, groceryKeywords('Milk (susu)')), isNull);
  });

  test('catalogue has no duplicate labels', () {
    final all = commonGroceries.values.expand((l) => l).toList();
    expect(all.toSet().length, all.length);
  });
}
