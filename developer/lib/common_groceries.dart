// Common kitchen ingredients for one-tap adding to the grocery list,
// grouped the way a Malaysian shopper would walk the shop.
//
// A label may carry its Malay name in brackets, e.g. "Shallots (bawang
// merah)". Both names are used to spot the item in the fridge.

const Map<String, List<String>> commonGroceries = {
  'Vegetables': [
    'Onions',
    'Shallots (bawang merah)',
    'Garlic (bawang putih)',
    'Ginger (halia)',
    'Chillies (cili)',
    "Bird's eye chilli (cili padi)",
    'Tomatoes',
    'Potatoes (kentang)',
    'Carrots',
    'Cabbage (kubis)',
    'Kangkung',
    'Choy sum (sawi)',
    'Spinach (bayam)',
    'Bean sprouts (taugeh)',
    'Long beans (kacang panjang)',
    'Okra (bendi)',
    'Eggplant (terung)',
    'Cucumber (timun)',
    'Broccoli',
    'Spring onion (daun bawang)',
    'Lemongrass (serai)',
    'Pandan leaves (daun pandan)',
  ],
  'Fruits': [
    'Bananas (pisang)',
    'Apples',
    'Oranges',
    'Papaya',
    'Watermelon (tembikai)',
    'Limes (limau nipis)',
    'Calamansi (limau kasturi)',
  ],
  'Meat & Seafood': [
    'Chicken (ayam)',
    'Chicken wings',
    'Beef (daging)',
    'Minced beef',
    'Mutton (kambing)',
    'Fish (ikan)',
    'Mackerel (ikan kembung)',
    'Prawns (udang)',
    'Squid (sotong)',
    'Anchovies (ikan bilis)',
    'Fish balls',
  ],
  'Eggs, Dairy & Tofu': [
    'Eggs (telur)',
    'Milk (susu)',
    'Butter',
    'Cheese',
    'Yogurt',
    'Tofu (tauhu)',
    'Tempeh',
  ],
  'Rice, Noodles & Bread': [
    'Rice (beras)',
    'Yellow noodles (mee kuning)',
    'Rice vermicelli (bihun)',
    'Flat rice noodles (kuey teow)',
    'Instant noodles',
    'Spaghetti',
    'Bread (roti)',
    'Flour (tepung)',
  ],
  'Sauces & Pastes': [
    'Soy sauce (kicap)',
    'Sweet soy sauce (kicap manis)',
    'Oyster sauce',
    'Chilli sauce (sos cili)',
    'Tomato ketchup',
    'Shrimp paste (belacan)',
    'Dried chilli paste (cili boh)',
    'Curry powder',
    'Tamarind (asam jawa)',
    'Coconut milk (santan)',
  ],
  'Pantry Basics': [
    'Cooking oil (minyak masak)',
    'Salt (garam)',
    'Sugar (gula)',
    'Black pepper',
    'Turmeric powder (kunyit)',
    'Stock cubes',
    'Canned tuna',
    'Canned sardines',
    'Kaya',
    'Peanut butter',
  ],
  'Drinks': [
    'Coffee',
    'Tea (teh)',
    'Milo',
    'Condensed milk (susu pekat)',
    'Evaporated milk (susu cair)',
    'Mineral water',
  ],
};

/// Words that identify a grocery label in the fridge: the English name and,
/// if present, the Malay name in brackets. "Eggs (telur)" → ["Eggs", "telur"].
List<String> groceryKeywords(String label) {
  final m = RegExp(r'^(.*?)\s*\((.+)\)\s*$').firstMatch(label);
  if (m == null) return [label.trim()];
  return [m.group(1)!.trim(), m.group(2)!.trim()];
}
