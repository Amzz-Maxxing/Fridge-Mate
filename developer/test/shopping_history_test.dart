import 'package:flutter_test/flutter_test.dart';
import 'package:fridge_mate/shopping_history.dart';

ShoppingTrip trip(DateTime date, List<String> names) => ShoppingTrip(
    'id', date, null, TripSource.list, [for (final n in names) TripItem(n)]);

void main() {
  test('mostBought counts each item once per trip, ignoring case', () {
    final trips = [
      trip(DateTime(2026, 11, 2), ['Eggs', 'Milk', 'eggs']),
      trip(DateTime(2026, 11, 9), ['eggs', 'Bread']),
      trip(DateTime(2026, 10, 20), ['Milk', 'Eggs']),
    ];
    final top = mostBought(trips);
    expect(top.first.key, 'Eggs');
    expect(top.first.value, 3); // once per trip, not 4
    expect(top[1].key, 'Milk');
    expect(top[1].value, 2);
    expect(top.last.key, 'Bread');
  });

  test('tripsThisMonth keeps only the current calendar month', () {
    final now = DateTime(2026, 11, 16);
    final trips = [
      trip(DateTime(2026, 11, 1), ['A']),
      trip(DateTime(2026, 10, 31), ['B']),
      trip(DateTime(2025, 11, 10), ['C']),
    ];
    expect(tripsThisMonth(trips, now: now).length, 1);
  });

  test('TripItem round-trips through a map and drops empty amounts', () {
    const withAmount =
        TripItem('Chicken', quantity: 1.5, unit: 'kg', category: 'Meat & Chicken');
    final back = TripItem.fromMap(withAmount.toMap());
    expect(back.name, 'Chicken');
    expect(back.quantity, 1.5);
    expect(back.unit, 'kg');
    expect(back.category, 'Meat & Chicken');
    expect(const TripItem('Salt').toMap().keys, ['name']);
  });
}
