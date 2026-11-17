// Small widget-level checks. (This replaces Flutter's default counter-app
// test, which didn't apply to Fridge Mate.)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fridge_mate/amounts.dart';
import 'package:fridge_mate/profile.dart';
import 'package:fridge_mate/theme.dart';

void main() {
  test('profile initials come from the name, else the email', () {
    expect(
      const UserProfile(name: 'Siti Aminah', email: 'x@y.com').initials,
      'SA',
    );
    expect(const UserProfile(name: '', email: 'ali@utp.edu.my').initials, 'AU');
    expect(const UserProfile(name: 'Mei', email: '').initials, 'M');
  });

  test('light and dark palettes cover every fridge category', () {
    for (final p in [AppPalette.light, AppPalette.dark]) {
      for (final c in [
        'Vegetables',
        'Fruits',
        'Meat & Chicken',
        'Seafood',
        'Dairy',
        'Eggs',
        'Leftovers',
        'Other',
      ]) {
        expect(p.shelves.containsKey(c), isTrue, reason: c);
      }
      expect(p.shelf('Unknown'), p.shelves['Other']);
    }
  });

  testWidgets('amount field shows the chosen unit', (tester) async {
    final controller = TextEditingController(text: '500');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AmountField(
            controller: controller,
            unit: 'g',
            onUnitChanged: (_) {},
          ),
        ),
      ),
    );
    expect(find.text('500'), findsOneWidget);
    expect(find.text('g'), findsWidgets);
  });
}
