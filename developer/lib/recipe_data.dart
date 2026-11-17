// The curated recipe database. Amounts are for each recipe's base servings;
// the recipe screen scales them. Every recipe is pork- and alcohol-free.
//
// To add a recipe: give it a unique id, an origin (reuse an existing one
// where possible so the filter stays tidy), a diet, and ingredients with
// amounts in a grocery-list unit (pcs, pack, g, kg, ml, L).

import 'recipes.dart';

part 'recipe_data_asia.dart';
part 'recipe_data_world.dart';

// Shared ingredients. Call them with an amount: _egg(2, 'pcs').
const _egg = Ingredient('Eggs', ['egg', 'telur']);
const _rice = Ingredient('Cooked rice', ['rice', 'nasi', 'beras']);
const _onion = Ingredient('Onion / shallots', ['onion', 'shallot', 'bawang']);
const _chili = Ingredient('Chillies', ['chili', 'chilli', 'cili', 'cabai']);
const _chicken = Ingredient('Chicken', ['chicken', 'ayam']);
const _tomato = Ingredient('Tomatoes', ['tomato', 'tomatoes']);
const _potato = Ingredient('Potatoes', ['potato', 'potatoes', 'kentang']);
const _carrot = Ingredient('Carrots', ['carrot', 'lobak merah']);
const _cabbage = Ingredient('Cabbage', ['cabbage', 'kubis']);
const _coconutMilk = Ingredient('Coconut milk', ['coconut milk', 'santan']);
const _springOnion =
    Ingredient('Spring onion', ['spring onion', 'scallion', 'daun bawang']);
const _milk = Ingredient('Milk', ['milk', 'susu']);
const _tofu = Ingredient('Tofu', ['tofu', 'tauhu']);
const _fish = Ingredient(
    'Fish', ['fish', 'ikan', 'mackerel', 'kembung', 'tenggiri', 'siakap']);
const _prawns = Ingredient('Prawns', ['prawn', 'shrimp', 'udang']);
const _mincedBeef = Ingredient(
    'Minced beef', ['minced beef', 'beef', 'mince', 'minced meat', 'daging']);
const _cheese =
    Ingredient('Cheese', ['cheese', 'mozzarella', 'cheddar', 'parmesan', 'keju']);
const _butter = Ingredient('Butter', ['butter', 'mentega']);
const _bread = Ingredient('Bread slices', ['bread', 'roti']);
const _spaghetti = Ingredient('Spaghetti', ['spaghetti', 'pasta']);
const _ginger = Ingredient('Ginger', ['ginger', 'halia']);
const _lemongrass = Ingredient('Lemongrass', ['lemongrass', 'serai']);
const _lime = Ingredient('Lime', ['lime', 'limau', 'calamansi']);
const _lemon = Ingredient('Lemon', ['lemon']);
const _beanSprouts =
    Ingredient('Bean sprouts', ['bean sprouts', 'bean sprout', 'taugeh']);
const _bellPepper = Ingredient('Bell pepper', ['bell pepper', 'capsicum']);
const _mushroom = Ingredient('Mushrooms', ['mushroom', 'cendawan']);
const _chickpeas = Ingredient('Chickpeas', ['chickpea', 'kacang kuda']);
const _beans = Ingredient(
    'Canned beans', ['baked beans', 'kidney beans', 'black beans', 'canned beans']);
const _eggplant = Ingredient('Eggplant', ['eggplant', 'brinjal', 'terung']);
const _longBeans =
    Ingredient('Long beans', ['long beans', 'long bean', 'kacang panjang']);
const _basil = Ingredient('Basil', ['basil', 'selasih', 'kemangi']);
const _anchovies = Ingredient('Anchovies', ['anchovy', 'anchovies', 'ikan bilis']);
const _cucumber = Ingredient('Cucumber', ['cucumber', 'timun']);
const _broccoli = Ingredient('Broccoli', ['broccoli', 'brokoli']);
const _peas = Ingredient('Green peas', ['pea', 'green pea']);
const _lettuce = Ingredient('Lettuce leaves', ['lettuce', 'salad', 'salad leaves']);
const _banana = Ingredient('Bananas', ['banana', 'pisang']);
const _yogurt = Ingredient('Yogurt', ['yogurt', 'yoghurt']);
const _noodles = Ingredient('Yellow noodles', ['noodle', 'mee', 'mi']);
const _salmon = Ingredient('Salmon fillets', ['salmon']);
const _tortilla = Ingredient('Tortillas', ['tortilla', 'wrap']);
const _corn = Ingredient('Sweet corn', ['corn', 'jagung']);
const _zucchini = Ingredient('Zucchini', ['zucchini', 'courgette']);
const _beef = Ingredient('Beef', ['beef', 'daging']);
const _mutton = Ingredient('Mutton', ['mutton', 'lamb', 'kambing']);
const _squid = Ingredient('Squid', ['squid', 'sotong', 'calamari']);
const _tempeh = Ingredient('Tempeh', ['tempeh', 'tempe']);
const _pumpkin = Ingredient('Pumpkin', ['pumpkin', 'labu']);
const _spinach = Ingredient('Spinach', ['spinach', 'bayam']);
const _bokChoy = Ingredient('Bok choy', ['bok choy', 'pak choy', 'sawi']);
const _cauliflower = Ingredient('Cauliflower', ['cauliflower', 'kubis bunga']);
const _kueyTeow =
    Ingredient('Flat rice noodles', ['kuey teow', 'kway teow', 'flat rice noodle']);
const _riceNoodles = Ingredient(
    'Rice noodles', ['rice noodle', 'rice stick', 'pho noodle', 'bihun']);
const _peanuts = Ingredient('Peanuts', ['peanut', 'kacang tanah']);
const _cream = Ingredient('Cooking cream', ['cream', 'krim']);
const _avocado = Ingredient('Avocado', ['avocado']);
const _mango = Ingredient('Mango', ['mango', 'mangga']);
const _oats = Ingredient('Rolled oats', ['oat', 'oats']);
const _celery = Ingredient('Celery', ['celery', 'saderi']);
const _pastry = Ingredient('Puff pastry', ['puff pastry', 'pastry']);
const _paneer = Ingredient('Paneer', ['paneer', 'cottage cheese']);
const _feta = Ingredient('Feta cheese', ['feta']);

/// Every recipe in the app.
final List<Recipe> recipeDatabase = [
  ..._coreRecipes,
  ..._asianRecipes,
  ..._worldRecipes,
];

final List<Recipe> _coreRecipes = [
  // =========================== Malay ===========================
  Recipe(
    id: 'nasi_goreng',
    name: 'Nasi Goreng Kampung',
    origin: 'Malay',
    diet: Diet.pescatarian,
    minutes: 20,
    servings: 2,
    ingredients: [
      _rice(400, 'g'),
      _egg(2, 'pcs'),
      _onion(3, 'pcs', label: 'Shallots'),
      _chili(3, 'pcs'),
      _anchovies(30, 'g'),
    ],
    staples: [
      Staple('Garlic', 2, 'cloves'),
      Staple('Soy sauce', 1, 'tbsp'),
      Staple('Cooking oil', 2, 'tbsp'),
      Staple('Salt'),
    ],
    steps: [
      'Pound or blend the onion, garlic and chillies into a rough paste.',
      'Fry the anchovies in oil until crisp, then set them aside.',
      'Fry the paste in the same oil until fragrant.',
      'Push the paste aside, scramble the eggs, then add the rice.',
      'Season with soy sauce and salt, toss well and top with the anchovies.',
    ],
  ),
  Recipe(
    id: 'nasi_lemak',
    name: 'Nasi Lemak',
    origin: 'Malay',
    diet: Diet.pescatarian,
    minutes: 45,
    servings: 2,
    ingredients: [
      _rice(250, 'g', label: 'Rice (uncooked)'),
      _coconutMilk(200, 'ml'),
      _egg(2, 'pcs'),
      _anchovies(40, 'g'),
      _cucumber(0.5, 'pcs'),
      _onion(2, 'pcs'),
      _chili(4, 'pcs'),
    ],
    staples: [
      Staple('Pandan leaves', 2, 'pcs'),
      Staple('Sugar', 1, 'tbsp'),
      Staple('Tamarind', 1, 'tbsp'),
      Staple('Cooking oil', 4, 'tbsp'),
      Staple('Salt'),
    ],
    steps: [
      'Cook the rice with the coconut milk, a knotted pandan leaf and a pinch of salt.',
      'Hard-boil the eggs, then peel and halve them.',
      'Fry the anchovies until crisp and set half aside for serving.',
      'Blend the chillies and onion, then fry slowly in oil until dark red.',
      'Add the remaining anchovies, tamarind and sugar to make the sambal.',
      'Serve the rice with sambal, egg, crispy anchovies and sliced cucumber.',
    ],
  ),
  Recipe(
    id: 'telur_dadar',
    name: 'Telur Dadar',
    origin: 'Malay',
    diet: Diet.vegetarian,
    minutes: 10,
    servings: 2,
    ingredients: [
      _egg(4, 'pcs'),
      _onion(1, 'pcs'),
      _chili(2, 'pcs'),
      _springOnion(1, 'pcs'),
    ],
    staples: [Staple('Salt'), Staple('Cooking oil', 1, 'tbsp')],
    steps: [
      'Beat the eggs with a pinch of salt.',
      'Stir in the sliced onion, chillies and spring onion.',
      'Pour into a hot oiled pan and cook until the edges crisp.',
      'Flip and cook the other side until golden.',
    ],
  ),
  Recipe(
    id: 'sayur_masak_lemak',
    name: 'Sayur Masak Lemak',
    origin: 'Malay',
    diet: Diet.vegan,
    minutes: 25,
    servings: 3,
    ingredients: [
      _cabbage(300, 'g'),
      _carrot(1, 'pcs'),
      _coconutMilk(200, 'ml'),
      _onion(1, 'pcs'),
      _chili(2, 'pcs'),
    ],
    staples: [
      Staple('Turmeric powder', 0.5, 'tsp'),
      Staple('Salt'),
      Staple('Cooking oil', 1, 'tbsp'),
    ],
    steps: [
      'Fry the sliced onion and chillies in a little oil until soft.',
      'Add turmeric and about a cup of water, then bring to a boil.',
      'Add the carrot first, then the cabbage, and simmer until tender.',
      'Stir in the coconut milk, season with salt and heat gently without boiling.',
    ],
  ),
  Recipe(
    id: 'ayam_masak_kicap',
    name: 'Ayam Masak Kicap',
    origin: 'Malay',
    diet: Diet.meat,
    minutes: 40,
    servings: 3,
    ingredients: [
      _chicken(600, 'g'),
      _onion(2, 'pcs'),
      _potato(2, 'pcs'),
      _chili(2, 'pcs'),
    ],
    staples: [
      Staple('Garlic', 3, 'cloves'),
      Staple('Sweet soy sauce', 4, 'tbsp'),
      Staple('Cooking oil', 3, 'tbsp'),
    ],
    steps: [
      'Season the chicken with salt and fry until lightly browned.',
      'Remove the chicken and fry the onion, garlic and chillies.',
      'Return the chicken, add the potatoes, soy sauce and a cup of water.',
      'Simmer covered until the chicken is cooked and the sauce thickens.',
    ],
  ),
  Recipe(
    id: 'ayam_goreng_berempah',
    name: 'Ayam Goreng Berempah',
    origin: 'Malay',
    diet: Diet.meat,
    minutes: 50,
    servings: 4,
    ingredients: [
      _chicken(800, 'g'),
      _ginger(20, 'g'),
      _lemongrass(2, 'pcs'),
      _onion(3, 'pcs', label: 'Shallots'),
    ],
    staples: [
      Staple('Turmeric powder', 1, 'tsp'),
      Staple('Chilli powder', 1, 'tbsp'),
      Staple('Garlic', 3, 'cloves'),
      Staple('Cooking oil (for frying)'),
      Staple('Salt'),
    ],
    steps: [
      'Blend the ginger, lemongrass, shallots and garlic into a paste.',
      'Rub the paste, turmeric, chilli powder and salt into the chicken.',
      'Leave to marinate for at least 20 minutes.',
      'Deep-fry on medium heat until cooked through and the spices are crisp.',
    ],
  ),
  Recipe(
    id: 'ikan_bakar',
    name: 'Ikan Bakar',
    origin: 'Malay',
    diet: Diet.pescatarian,
    minutes: 35,
    servings: 2,
    ingredients: [
      _fish(500, 'g'),
      _chili(3, 'pcs'),
      _onion(3, 'pcs', label: 'Shallots'),
      _lime(1, 'pcs'),
    ],
    staples: [
      Staple('Belacan (shrimp paste)', 1, 'tsp'),
      Staple('Tamarind', 1, 'tbsp'),
      Staple('Cooking oil', 2, 'tbsp'),
      Staple('Salt'),
    ],
    steps: [
      'Blend the chillies, shallots and belacan, then fry in oil until fragrant.',
      'Season the paste with tamarind and salt.',
      'Score the fish and spread the paste inside and out.',
      'Grill or pan-fry on a lined pan until cooked, about 8 minutes a side.',
      'Serve with lime wedges.',
    ],
  ),
  Recipe(
    id: 'kangkung_belacan',
    name: 'Kangkung Goreng Belacan',
    origin: 'Malay',
    diet: Diet.pescatarian,
    minutes: 10,
    servings: 2,
    ingredients: [
      Ingredient('Kangkung', ['kangkung', 'water spinach'],
          amount: 250, unit: 'g'),
      _chili(4, 'pcs'),
      _onion(3, 'pcs', label: 'Shallots'),
    ],
    staples: [
      Staple('Belacan (shrimp paste)', 1, 'tsp'),
      Staple('Garlic', 3, 'cloves'),
      Staple('Cooking oil', 2, 'tbsp'),
    ],
    steps: [
      'Pound the chillies, shallots, garlic and belacan together.',
      'Fry the paste in hot oil until fragrant.',
      'Add the kangkung and stir-fry on high heat for 1–2 minutes.',
    ],
  ),
  Recipe(
    id: 'bubur_ayam',
    name: 'Bubur Ayam',
    origin: 'Malay',
    diet: Diet.meat,
    minutes: 45,
    servings: 3,
    ingredients: [
      _rice(150, 'g', label: 'Rice (uncooked)'),
      _chicken(300, 'g'),
      _ginger(30, 'g'),
      _springOnion(2, 'pcs'),
    ],
    staples: [
      Staple('Salt'),
      Staple('Pepper'),
      Staple('Fried shallots', 2, 'tbsp'),
    ],
    steps: [
      'Simmer the rice in plenty of water with sliced ginger, stirring often.',
      'Add the chicken and cook until it is done, then shred it.',
      'Keep simmering until the porridge is thick and creamy.',
      'Season, then top with shredded chicken, spring onion and fried shallots.',
    ],
  ),
  Recipe(
    id: 'kari_ikan',
    name: 'Kari Ikan',
    origin: 'Malay',
    diet: Diet.pescatarian,
    minutes: 35,
    servings: 3,
    ingredients: [
      _fish(500, 'g'),
      _coconutMilk(200, 'ml'),
      _tomato(2, 'pcs'),
      Ingredient('Okra', ['okra', 'lady finger', 'bendi'],
          amount: 6, unit: 'pcs'),
      _onion(1, 'pcs'),
    ],
    staples: [
      Staple('Fish curry powder', 3, 'tbsp'),
      Staple('Tamarind', 1, 'tbsp'),
      Staple('Cooking oil', 3, 'tbsp'),
      Staple('Salt'),
    ],
    steps: [
      'Mix the curry powder with a little water into a paste.',
      'Fry the onion, then the curry paste, until the oil separates.',
      'Add water and tamarind juice and bring to a simmer.',
      'Add the okra and tomato, then the fish, and cook gently.',
      'Stir in the coconut milk and season to taste.',
    ],
  ),
  Recipe(
    id: 'sambal_udang',
    name: 'Sambal Udang',
    origin: 'Malay',
    diet: Diet.pescatarian,
    minutes: 25,
    servings: 3,
    ingredients: [
      _prawns(400, 'g'),
      _onion(2, 'pcs'),
      _chili(2, 'pcs'),
      _tomato(1, 'pcs'),
    ],
    staples: [
      Staple('Dried chilli paste', 3, 'tbsp'),
      Staple('Sugar', 1, 'tbsp'),
      Staple('Tamarind', 1, 'tbsp'),
      Staple('Cooking oil', 4, 'tbsp'),
    ],
    steps: [
      'Fry the chilli paste slowly until dark and the oil separates.',
      'Add the sliced onion and tomato and cook until soft.',
      'Season with tamarind juice, sugar and salt.',
      'Add the prawns and cook just until they turn pink.',
    ],
  ),
  Recipe(
    id: 'tauhu_goreng',
    name: 'Tauhu Goreng',
    origin: 'Malay',
    diet: Diet.vegan,
    minutes: 20,
    servings: 2,
    ingredients: [
      _tofu(4, 'pcs'),
      _cucumber(1, 'pcs'),
      _beanSprouts(100, 'g'),
    ],
    staples: [
      Staple('Sweet soy sauce', 3, 'tbsp'),
      Staple('Chilli sauce', 2, 'tbsp'),
      Staple('Crushed peanuts', 2, 'tbsp'),
      Staple('Cooking oil (for frying)'),
    ],
    steps: [
      'Pat the tofu dry and deep-fry until golden and crisp outside.',
      'Blanch the bean sprouts for 30 seconds and shred the cucumber.',
      'Mix the sweet soy and chilli sauce into a dressing.',
      'Cut each tofu open, stuff with the vegetables, and top with dressing and peanuts.',
    ],
  ),
  Recipe(
    id: 'bihun_goreng',
    name: 'Bihun Goreng',
    origin: 'Malay',
    diet: Diet.pescatarian,
    minutes: 25,
    servings: 3,
    ingredients: [
      Ingredient('Rice vermicelli', ['vermicelli', 'bihun', 'mee hoon'],
          amount: 200, unit: 'g'),
      _egg(2, 'pcs'),
      _cabbage(150, 'g'),
      _carrot(1, 'pcs'),
      _prawns(150, 'g'),
    ],
    staples: [
      Staple('Garlic', 3, 'cloves'),
      Staple('Soy sauce', 2, 'tbsp'),
      Staple('Chilli paste', 1, 'tbsp'),
      Staple('Cooking oil', 3, 'tbsp'),
    ],
    steps: [
      'Soak the vermicelli in warm water until soft, then drain.',
      'Fry the garlic and chilli paste, then add the prawns.',
      'Add the shredded carrot and cabbage and stir-fry for 2 minutes.',
      'Push aside, scramble the eggs, then add the vermicelli and soy sauce.',
      'Toss until everything is evenly coloured.',
    ],
  ),
  Recipe(
    id: 'pisang_goreng',
    name: 'Pisang Goreng',
    origin: 'Malay',
    diet: Diet.vegan,
    minutes: 20,
    servings: 3,
    ingredients: [_banana(6, 'pcs')],
    staples: [
      Staple('Flour', 100, 'g'),
      Staple('Rice flour', 2, 'tbsp'),
      Staple('Sugar', 1, 'tbsp'),
      Staple('Salt'),
      Staple('Cooking oil (for frying)'),
    ],
    steps: [
      'Whisk both flours, sugar, a pinch of salt and cold water into a thick batter.',
      'Peel the bananas and halve them lengthwise.',
      'Dip in the batter and deep-fry until golden and crisp.',
      'Drain on paper and serve warm.',
    ],
  ),

  // =========================== Chinese ===========================
  Recipe(
    id: 'chicken_stir_fry',
    name: 'Chicken & Vegetable Stir-Fry',
    origin: 'Chinese',
    diet: Diet.meat,
    minutes: 20,
    servings: 2,
    ingredients: [
      _chicken(300, 'g'),
      _broccoli(200, 'g'),
      _carrot(1, 'pcs'),
      _bellPepper(1, 'pcs'),
    ],
    staples: [
      Staple('Garlic', 2, 'cloves'),
      Staple('Oyster sauce', 2, 'tbsp'),
      Staple('Cooking oil', 1, 'tbsp'),
    ],
    steps: [
      'Slice the chicken thinly and stir-fry until it is no longer pink.',
      'Add the garlic, carrot and broccoli with a splash of water.',
      'Add the pepper and oyster sauce and toss until glossy.',
    ],
  ),
  Recipe(
    id: 'tomato_egg',
    name: 'Tomato Egg Stir-Fry',
    origin: 'Chinese',
    diet: Diet.vegetarian,
    minutes: 10,
    servings: 2,
    ingredients: [_egg(3, 'pcs'), _tomato(3, 'pcs'), _springOnion(1, 'pcs')],
    staples: [
      Staple('Sugar', 1, 'tsp'),
      Staple('Salt'),
      Staple('Cooking oil', 2, 'tbsp'),
    ],
    steps: [
      'Softly scramble the eggs and take them out of the pan.',
      'Cook the tomato wedges with a pinch of sugar and salt until saucy.',
      'Return the eggs, fold through and finish with spring onion.',
    ],
  ),
  Recipe(
    id: 'egg_fried_rice',
    name: 'Egg Fried Rice',
    origin: 'Chinese',
    diet: Diet.vegetarian,
    minutes: 15,
    servings: 2,
    ingredients: [
      _rice(400, 'g'),
      _egg(2, 'pcs'),
      _springOnion(2, 'pcs'),
      _peas(80, 'g'),
    ],
    staples: [
      Staple('Soy sauce', 1, 'tbsp'),
      Staple('Sesame oil', 1, 'tsp'),
      Staple('Cooking oil', 2, 'tbsp'),
      Staple('Salt'),
    ],
    steps: [
      'Use day-old rice if you can; break up any clumps.',
      'Scramble the eggs in hot oil until just set, then add the rice.',
      'Add the peas and stir-fry on high heat for 3 minutes.',
      'Season with soy sauce, sesame oil and salt, then add spring onion.',
    ],
  ),
  Recipe(
    id: 'stir_fried_bean_sprouts',
    name: 'Stir-Fried Bean Sprouts',
    origin: 'Chinese',
    diet: Diet.vegan,
    minutes: 10,
    servings: 2,
    ingredients: [_beanSprouts(300, 'g'), _springOnion(1, 'pcs'), _chili(1, 'pcs')],
    staples: [
      Staple('Garlic', 2, 'cloves'),
      Staple('Soy sauce', 1, 'tbsp'),
      Staple('Cooking oil', 1, 'tbsp'),
    ],
    steps: [
      'Fry the garlic and sliced chilli for a few seconds.',
      'Add the bean sprouts and toss on the highest heat for 1 minute.',
      'Add soy sauce and spring onion and serve while still crunchy.',
    ],
  ),
  Recipe(
    id: 'steamed_fish_ginger',
    name: 'Steamed Fish with Ginger',
    origin: 'Chinese',
    diet: Diet.pescatarian,
    minutes: 25,
    servings: 3,
    ingredients: [_fish(500, 'g'), _ginger(30, 'g'), _springOnion(2, 'pcs')],
    staples: [
      Staple('Soy sauce', 3, 'tbsp'),
      Staple('Sesame oil', 1, 'tsp'),
      Staple('Cooking oil', 2, 'tbsp'),
      Staple('Sugar', 1, 'tsp'),
    ],
    steps: [
      'Lay the fish on a plate with half the ginger, cut into strips.',
      'Steam over boiling water for 10–12 minutes until the flesh flakes.',
      'Pour off the liquid, then top with the rest of the ginger and spring onion.',
      'Heat the oil until smoking and pour it over the fish.',
      'Spoon over the soy sauce, sugar and sesame oil.',
    ],
  ),
  Recipe(
    id: 'mapo_tofu',
    name: 'Mapo Tofu',
    origin: 'Chinese',
    diet: Diet.meat,
    minutes: 20,
    servings: 3,
    ingredients: [_tofu(2, 'pcs'), _mincedBeef(150, 'g'), _springOnion(1, 'pcs')],
    staples: [
      Staple('Chilli bean paste', 2, 'tbsp'),
      Staple('Garlic', 2, 'cloves'),
      Staple('Soy sauce', 1, 'tbsp'),
      Staple('Cornflour', 1, 'tsp'),
      Staple('Cooking oil', 1, 'tbsp'),
    ],
    steps: [
      'Cut the tofu into cubes and soak in hot salted water.',
      'Brown the beef, then add the garlic and chilli bean paste.',
      'Add a cup of water and the soy sauce and bring to a simmer.',
      'Drain the tofu, slide it in and simmer gently for 5 minutes.',
      'Thicken with cornflour mixed in water and top with spring onion.',
    ],
  ),
  Recipe(
    id: 'kung_pao_chicken',
    name: 'Kung Pao Chicken',
    origin: 'Chinese',
    diet: Diet.meat,
    minutes: 25,
    servings: 3,
    ingredients: [
      _chicken(400, 'g'),
      _chili(4, 'pcs'),
      Ingredient('Peanuts', ['peanut', 'kacang tanah'], amount: 50, unit: 'g'),
      _springOnion(2, 'pcs'),
    ],
    staples: [
      Staple('Soy sauce', 2, 'tbsp'),
      Staple('Vinegar', 1, 'tbsp'),
      Staple('Sugar', 1, 'tsp'),
      Staple('Garlic', 2, 'cloves'),
      Staple('Cornflour', 1, 'tsp'),
      Staple('Cooking oil', 2, 'tbsp'),
    ],
    steps: [
      'Cube the chicken and toss with a little soy sauce and cornflour.',
      'Mix the rest of the soy sauce with vinegar, sugar and 2 tbsp water.',
      'Fry the chillies briefly, then add the chicken and cook through.',
      'Add the garlic, sauce, peanuts and spring onion and toss until glossy.',
    ],
  ),

  // =========================== Indian ===========================
  Recipe(
    id: 'mee_goreng_mamak',
    name: 'Mee Goreng Mamak',
    origin: 'Indian',
    diet: Diet.vegetarian,
    minutes: 20,
    servings: 2,
    ingredients: [
      _noodles(400, 'g'),
      _egg(2, 'pcs'),
      _tofu(1, 'pcs'),
      Ingredient('Choy sum', ['choy sum', 'sawi'], amount: 150, unit: 'g'),
      _tomato(1, 'pcs'),
    ],
    staples: [
      Staple('Garlic', 2, 'cloves'),
      Staple('Soy sauce', 1, 'tbsp'),
      Staple('Chilli sauce', 2, 'tbsp'),
      Staple('Cooking oil', 2, 'tbsp'),
    ],
    steps: [
      'Fry the garlic and cubed tofu until the tofu is golden.',
      'Add the noodles, soy sauce and chilli sauce, and toss.',
      'Push aside, scramble the egg and mix it through.',
      'Add the choy sum and tomato wedges and cook until the greens wilt.',
    ],
  ),
  Recipe(
    id: 'dhal_curry',
    name: 'Dhal Curry',
    origin: 'Indian',
    diet: Diet.vegan,
    minutes: 35,
    servings: 4,
    ingredients: [
      Ingredient('Lentils (dhal)', ['lentil', 'dhal', 'dal', 'dhall'],
          amount: 200, unit: 'g'),
      _onion(1, 'pcs'),
      _tomato(2, 'pcs'),
      _chili(2, 'pcs'),
      _carrot(1, 'pcs'),
    ],
    staples: [
      Staple('Curry powder', 1, 'tbsp'),
      Staple('Turmeric powder', 0.5, 'tsp'),
      Staple('Mustard seeds', 1, 'tsp'),
      Staple('Cooking oil', 2, 'tbsp'),
      Staple('Salt'),
    ],
    steps: [
      'Rinse the lentils and boil with turmeric and diced carrot until soft.',
      'In another pan, fry the mustard seeds until they pop.',
      'Add the onion and chillies, then the curry powder and tomatoes.',
      'Stir the spice mix into the lentils, add water to loosen, and season.',
    ],
  ),
  Recipe(
    id: 'chicken_curry',
    name: 'Chicken Curry',
    origin: 'Indian',
    diet: Diet.meat,
    minutes: 50,
    servings: 4,
    ingredients: [
      _chicken(800, 'g'),
      _potato(2, 'pcs'),
      _onion(2, 'pcs'),
      _coconutMilk(200, 'ml'),
      _tomato(1, 'pcs'),
    ],
    staples: [
      Staple('Meat curry powder', 4, 'tbsp'),
      Staple('Garlic', 4, 'cloves'),
      Staple('Cooking oil', 3, 'tbsp'),
      Staple('Salt'),
    ],
    steps: [
      'Fry the onion and garlic until golden.',
      'Add the curry powder mixed with water and fry until the oil separates.',
      'Add the chicken and tomato and stir to coat.',
      'Add the potatoes and enough water to cover, then simmer for 25 minutes.',
      'Stir in the coconut milk and season.',
    ],
  ),
  Recipe(
    id: 'chana_masala',
    name: 'Chana Masala',
    origin: 'Indian',
    diet: Diet.vegan,
    minutes: 30,
    servings: 3,
    ingredients: [
      _chickpeas(400, 'g'),
      _onion(1, 'pcs'),
      _tomato(3, 'pcs'),
      _ginger(15, 'g'),
    ],
    staples: [
      Staple('Garam masala', 2, 'tsp'),
      Staple('Ground cumin', 1, 'tsp'),
      Staple('Garlic', 3, 'cloves'),
      Staple('Cooking oil', 2, 'tbsp'),
      Staple('Salt'),
    ],
    steps: [
      'Fry the onion until soft, then add the garlic and grated ginger.',
      'Add the spices and the chopped tomatoes and cook into a thick sauce.',
      'Add the drained chickpeas and a splash of water.',
      'Simmer for 10 minutes, mashing a few chickpeas to thicken.',
    ],
  ),

  // =========================== Thai ===========================
  Recipe(
    id: 'tom_yum',
    name: 'Tom Yum Soup',
    origin: 'Thai',
    diet: Diet.pescatarian,
    minutes: 25,
    servings: 3,
    ingredients: [
      _prawns(300, 'g'),
      _mushroom(150, 'g'),
      _lemongrass(2, 'pcs'),
      _tomato(1, 'pcs'),
      _lime(1, 'pcs'),
    ],
    staples: [
      Staple('Tom yum paste', 2, 'tbsp'),
      Staple('Fish sauce', 1, 'tbsp'),
      Staple('Sugar', 1, 'tsp'),
    ],
    steps: [
      'Bring 1 litre of water to the boil with the bruised lemongrass.',
      'Stir in the tom yum paste, then add the mushrooms and tomato.',
      'Add the prawns and cook until pink.',
      'Season with fish sauce, sugar and lime juice off the heat.',
    ],
  ),
  Recipe(
    id: 'pad_kra_pao',
    name: 'Pad Kra Pao (Basil Chicken)',
    origin: 'Thai',
    diet: Diet.meat,
    minutes: 15,
    servings: 2,
    ingredients: [
      _chicken(300, 'g'),
      _chili(3, 'pcs'),
      _longBeans(100, 'g'),
      _basil(1, 'pack'),
      _egg(2, 'pcs'),
    ],
    staples: [
      Staple('Oyster sauce', 1, 'tbsp'),
      Staple('Soy sauce', 1, 'tbsp'),
      Staple('Garlic', 3, 'cloves'),
      Staple('Sugar', 1, 'tsp'),
      Staple('Cooking oil', 3, 'tbsp'),
    ],
    steps: [
      'Fry the eggs in plenty of hot oil until crispy and set aside.',
      'Pound the garlic and chillies and fry for a few seconds.',
      'Add the chopped chicken and long beans and stir-fry until cooked.',
      'Season with the sauces and sugar, then toss in the basil.',
      'Serve over rice with the fried eggs.',
    ],
  ),
  Recipe(
    id: 'thai_green_curry_veg',
    name: 'Thai Green Curry with Tofu',
    origin: 'Thai',
    diet: Diet.pescatarian,
    minutes: 30,
    servings: 3,
    ingredients: [
      _eggplant(1, 'pcs'),
      _longBeans(100, 'g'),
      _coconutMilk(400, 'ml'),
      _tofu(1, 'pcs'),
      _basil(1, 'pack'),
    ],
    staples: [
      Staple('Green curry paste', 3, 'tbsp'),
      Staple('Sugar', 1, 'tsp'),
      Staple('Soy sauce', 1, 'tbsp'),
      Staple('Cooking oil', 1, 'tbsp'),
    ],
    steps: [
      'Fry the curry paste in oil with a splash of the coconut milk.',
      'Add the rest of the coconut milk and bring to a simmer.',
      'Add the eggplant and long beans and cook until tender.',
      'Add the cubed tofu, season with soy sauce and sugar, and finish with basil.',
    ],
  ),

  // =========================== Japanese ===========================
  Recipe(
    id: 'oyakodon',
    name: 'Oyakodon',
    origin: 'Japanese',
    diet: Diet.meat,
    minutes: 25,
    servings: 2,
    ingredients: [
      _chicken(300, 'g'),
      _egg(3, 'pcs'),
      _onion(1, 'pcs'),
      _rice(400, 'g'),
      _springOnion(1, 'pcs'),
    ],
    staples: [
      Staple('Soy sauce', 3, 'tbsp'),
      Staple('Honey', 1, 'tbsp'),
      Staple('Sugar', 1, 'tsp'),
    ],
    steps: [
      'Simmer the sliced onion in 150 ml water with the soy sauce, honey and sugar.',
      'Add bite-sized chicken pieces and cook for 6–7 minutes.',
      'Pour in the lightly beaten eggs, cover and cook until just set.',
      'Slide over bowls of hot rice and top with spring onion.',
    ],
  ),
  Recipe(
    id: 'miso_soup',
    name: 'Miso Soup',
    origin: 'Japanese',
    diet: Diet.vegan,
    minutes: 10,
    servings: 3,
    ingredients: [
      _tofu(1, 'pcs'),
      Ingredient('Seaweed (wakame)', ['seaweed', 'wakame', 'rumpai laut'],
          amount: 5, unit: 'g'),
      _springOnion(1, 'pcs'),
    ],
    staples: [
      Staple('Miso paste', 3, 'tbsp'),
      Staple('Vegetable stock', 750, 'ml'),
    ],
    steps: [
      'Soak the seaweed in water for 5 minutes and drain.',
      'Heat the stock until just below boiling.',
      'Whisk in the miso off the heat; do not let it boil.',
      'Add the cubed tofu and seaweed and top with spring onion.',
    ],
  ),
  Recipe(
    id: 'teriyaki_salmon',
    name: 'Teriyaki Salmon',
    origin: 'Japanese',
    diet: Diet.pescatarian,
    minutes: 20,
    servings: 2,
    ingredients: [_salmon(2, 'pcs'), _broccoli(200, 'g'), _rice(400, 'g')],
    staples: [
      Staple('Soy sauce', 3, 'tbsp'),
      Staple('Honey', 2, 'tbsp'),
      Staple('Cooking oil', 1, 'tbsp'),
      Staple('Sesame seeds', 1, 'tsp'),
    ],
    steps: [
      'Mix the soy sauce and honey with 2 tbsp water.',
      'Pan-fry the salmon skin-side down for 4 minutes, then flip.',
      'Pour in the sauce and spoon it over until sticky.',
      'Steam the broccoli and serve with rice and sesame seeds.',
    ],
  ),

  // =========================== Korean ===========================
  Recipe(
    id: 'kimchi_fried_rice',
    name: 'Kimchi Fried Rice',
    origin: 'Korean',
    diet: Diet.pescatarian,
    minutes: 15,
    servings: 2,
    ingredients: [
      _rice(400, 'g'),
      Ingredient('Kimchi', ['kimchi'], amount: 150, unit: 'g'),
      _egg(2, 'pcs'),
      _springOnion(1, 'pcs'),
    ],
    staples: [
      Staple('Gochujang', 1, 'tbsp'),
      Staple('Sesame oil', 1, 'tsp'),
      Staple('Cooking oil', 2, 'tbsp'),
    ],
    steps: [
      'Fry the chopped kimchi for 2 minutes until it caramelises.',
      'Add the rice and gochujang and stir-fry until evenly red.',
      'Drizzle with sesame oil.',
      'Top each bowl with a fried egg and spring onion.',
    ],
  ),

  // =========================== Italian ===========================
  Recipe(
    id: 'spaghetti_bolognese',
    name: 'Spaghetti Bolognese',
    origin: 'Italian',
    diet: Diet.meat,
    minutes: 40,
    servings: 3,
    ingredients: [
      _spaghetti(250, 'g'),
      _mincedBeef(400, 'g'),
      _tomato(4, 'pcs'),
      _onion(1, 'pcs'),
      _carrot(1, 'pcs'),
    ],
    staples: [
      Staple('Garlic', 2, 'cloves'),
      Staple('Olive oil', 2, 'tbsp'),
      Staple('Salt'),
      Staple('Dried herbs', 1, 'tsp'),
    ],
    steps: [
      'Fry the chopped onion, carrot and garlic until soft.',
      'Add the beef and brown it, breaking it up.',
      'Add the chopped tomatoes and herbs and simmer for 20 minutes.',
      'Cook the spaghetti, drain, and serve with the sauce.',
    ],
  ),
  Recipe(
    id: 'aglio_olio',
    name: 'Spaghetti Aglio e Olio',
    origin: 'Italian',
    diet: Diet.vegan,
    minutes: 15,
    servings: 2,
    ingredients: [_spaghetti(200, 'g'), _chili(1, 'pcs')],
    staples: [
      Staple('Garlic', 6, 'cloves'),
      Staple('Olive oil', 4, 'tbsp'),
      Staple('Dried parsley', 1, 'tsp'),
      Staple('Salt'),
    ],
    steps: [
      'Cook the spaghetti in well-salted water; keep a cup of the water.',
      'Gently fry the sliced garlic and chilli in olive oil until pale gold.',
      'Toss in the spaghetti with a splash of pasta water until glossy.',
      'Finish with parsley and season.',
    ],
  ),
  Recipe(
    id: 'penne_arrabbiata',
    name: 'Penne Arrabbiata',
    origin: 'Italian',
    diet: Diet.vegan,
    minutes: 25,
    servings: 3,
    ingredients: [
      Ingredient('Penne', ['penne', 'pasta'], amount: 250, unit: 'g'),
      _tomato(4, 'pcs'),
      _chili(2, 'pcs'),
      _onion(1, 'pcs'),
    ],
    staples: [
      Staple('Garlic', 3, 'cloves'),
      Staple('Olive oil', 2, 'tbsp'),
      Staple('Salt'),
    ],
    steps: [
      'Fry the onion, garlic and chilli in olive oil until soft.',
      'Add the chopped tomatoes and simmer for 15 minutes into a sauce.',
      'Cook the penne, drain, and toss in the sauce.',
    ],
  ),
  Recipe(
    id: 'mushroom_risotto',
    name: 'Mushroom Risotto',
    origin: 'Italian',
    diet: Diet.vegetarian,
    minutes: 40,
    servings: 3,
    ingredients: [
      Ingredient('Risotto rice', ['arborio', 'risotto rice', 'rice'],
          amount: 250, unit: 'g'),
      _mushroom(250, 'g'),
      _onion(1, 'pcs'),
      _butter(30, 'g'),
      _cheese(40, 'g'),
    ],
    staples: [
      Staple('Vegetable stock', 1, 'L'),
      Staple('Olive oil', 1, 'tbsp'),
      Staple('Salt'),
    ],
    steps: [
      'Fry the onion in oil, then add the sliced mushrooms until browned.',
      'Stir in the rice for a minute.',
      'Add hot stock a ladle at a time, stirring, until the rice is creamy (about 18 minutes).',
      'Beat in the butter and grated cheese and season.',
    ],
  ),
  Recipe(
    id: 'caprese_salad',
    name: 'Caprese Salad',
    origin: 'Italian',
    diet: Diet.vegetarian,
    minutes: 10,
    servings: 2,
    ingredients: [_tomato(3, 'pcs'), _cheese(125, 'g', label: 'Mozzarella'), _basil(1, 'pack')],
    staples: [
      Staple('Olive oil', 2, 'tbsp'),
      Staple('Salt'),
      Staple('Pepper'),
    ],
    steps: [
      'Slice the tomatoes and mozzarella.',
      'Layer them on a plate with basil leaves.',
      'Drizzle with olive oil and season with salt and pepper.',
    ],
  ),

  // =========================== British ===========================
  Recipe(
    id: 'tuna_sandwich',
    name: 'Tuna Sandwich',
    origin: 'British',
    diet: Diet.pescatarian,
    minutes: 10,
    servings: 2,
    ingredients: [
      _bread(4, 'pcs'),
      Ingredient('Canned tuna', ['tuna'], amount: 1, unit: 'pack'),
      _cucumber(0.5, 'pcs'),
      _lettuce(4, 'pcs'),
    ],
    staples: [Staple('Mayonnaise', 2, 'tbsp'), Staple('Pepper')],
    steps: [
      'Mix the drained tuna with mayonnaise and pepper.',
      'Layer lettuce, cucumber slices and the tuna on the bread.',
    ],
  ),
  Recipe(
    id: 'vegetable_soup',
    name: 'Vegetable Soup',
    origin: 'British',
    diet: Diet.vegan,
    minutes: 30,
    servings: 4,
    ingredients: [
      _carrot(2, 'pcs'),
      _potato(2, 'pcs'),
      _onion(1, 'pcs'),
      _cabbage(200, 'g'),
      _tomato(2, 'pcs'),
    ],
    staples: [
      Staple('Vegetable stock cube', 1, 'pcs'),
      Staple('Salt'),
      Staple('Pepper'),
    ],
    steps: [
      'Fry the onion until soft, then add the diced carrot and potato.',
      'Add water and the stock cube and simmer for 15 minutes.',
      'Add the cabbage and tomato and cook until everything is tender.',
      'Season with salt and pepper.',
    ],
  ),
  Recipe(
    id: 'cottage_pie',
    name: 'Cottage Pie',
    origin: 'British',
    diet: Diet.meat,
    minutes: 75,
    servings: 4,
    ingredients: [
      _mincedBeef(500, 'g'),
      _potato(6, 'pcs'),
      _onion(1, 'pcs'),
      _carrot(2, 'pcs'),
      _peas(100, 'g'),
      _butter(30, 'g'),
      _milk(100, 'ml'),
    ],
    staples: [
      Staple('Beef stock cube', 1, 'pcs'),
      Staple('Tomato paste', 1, 'tbsp'),
      Staple('Salt'),
      Staple('Pepper'),
    ],
    steps: [
      'Boil the potatoes until soft, then mash with the butter and milk.',
      'Brown the beef with the onion and diced carrot.',
      'Add the tomato paste, stock cube and a cup of water and simmer 15 minutes.',
      'Stir in the peas and spoon into a baking dish.',
      'Top with the mash and bake at 200°C for 25 minutes until golden.',
    ],
  ),
  Recipe(
    id: 'fish_and_chips',
    name: 'Oven Fish and Chips',
    origin: 'British',
    diet: Diet.pescatarian,
    minutes: 45,
    servings: 2,
    ingredients: [_fish(400, 'g'), _potato(4, 'pcs'), _egg(1, 'pcs'), _lemon(1, 'pcs')],
    staples: [
      Staple('Breadcrumbs', 60, 'g'),
      Staple('Flour', 2, 'tbsp'),
      Staple('Cooking oil', 3, 'tbsp'),
      Staple('Salt'),
    ],
    steps: [
      'Cut the potatoes into chips, toss with oil and salt, and bake at 220°C for 30 minutes.',
      'Coat the fish in flour, then beaten egg, then breadcrumbs.',
      'Add the fish to the oven for the last 15 minutes, turning once.',
      'Serve with lemon wedges.',
    ],
  ),
  Recipe(
    id: 'beans_on_toast',
    name: 'Beans on Toast',
    origin: 'British',
    diet: Diet.vegetarian,
    minutes: 10,
    servings: 2,
    ingredients: [_beans(1, 'pack', label: 'Baked beans'), _bread(4, 'pcs'), _butter(20, 'g')],
    staples: [Staple('Pepper')],
    steps: [
      'Warm the beans in a small pan.',
      'Toast and butter the bread.',
      'Spoon the beans over the toast and add pepper.',
    ],
  ),
  Recipe(
    id: 'scrambled_eggs_toast',
    name: 'Scrambled Eggs on Toast',
    origin: 'British',
    diet: Diet.vegetarian,
    minutes: 10,
    servings: 2,
    ingredients: [_egg(4, 'pcs'), _bread(2, 'pcs'), _butter(20, 'g'), _milk(50, 'ml')],
    staples: [Staple('Salt'), Staple('Pepper')],
    steps: [
      'Whisk the eggs with the milk and a pinch of salt.',
      'Melt half the butter on low heat and add the eggs.',
      'Stir gently until softly set, then take off the heat.',
      'Serve on buttered toast with pepper.',
    ],
  ),

  // =========================== American ===========================
  Recipe(
    id: 'banana_smoothie',
    name: 'Banana Smoothie',
    origin: 'American',
    diet: Diet.vegetarian,
    minutes: 5,
    servings: 2,
    ingredients: [_banana(2, 'pcs'), _milk(300, 'ml'), _yogurt(150, 'g')],
    staples: [Staple('Honey', 1, 'tbsp'), Staple('Ice', 1, 'cup')],
    steps: [
      'Blend the bananas, milk, yogurt and honey with ice until smooth.',
    ],
  ),
  Recipe(
    id: 'pancakes',
    name: 'Pancakes',
    origin: 'American',
    diet: Diet.vegetarian,
    minutes: 20,
    servings: 2,
    ingredients: [_egg(1, 'pcs'), _milk(250, 'ml'), _butter(30, 'g')],
    staples: [
      Staple('Flour', 150, 'g'),
      Staple('Sugar', 2, 'tbsp'),
      Staple('Baking powder', 2, 'tsp'),
    ],
    steps: [
      'Whisk the flour, sugar and baking powder together.',
      'Beat in the eggs, milk and melted butter to make a smooth batter.',
      'Cook ladlefuls in a buttered pan until bubbles form, then flip.',
    ],
  ),
  Recipe(
    id: 'mac_and_cheese',
    name: 'Mac and Cheese',
    origin: 'American',
    diet: Diet.vegetarian,
    minutes: 30,
    servings: 3,
    ingredients: [
      Ingredient('Macaroni', ['macaroni', 'pasta'], amount: 250, unit: 'g'),
      _cheese(150, 'g'),
      _milk(400, 'ml'),
      _butter(30, 'g'),
    ],
    staples: [
      Staple('Flour', 2, 'tbsp'),
      Staple('Salt'),
      Staple('Pepper'),
    ],
    steps: [
      'Cook the macaroni until just tender and drain.',
      'Melt the butter, stir in the flour, then whisk in the milk until thick.',
      'Take off the heat and stir in most of the grated cheese.',
      'Mix with the macaroni, top with the rest of the cheese, and grill until bubbling.',
    ],
  ),
  Recipe(
    id: 'beef_burger',
    name: 'Beef Burger',
    origin: 'American',
    diet: Diet.meat,
    minutes: 25,
    servings: 2,
    ingredients: [
      _mincedBeef(300, 'g'),
      Ingredient('Burger buns', ['burger bun', 'bun'], amount: 2, unit: 'pcs'),
      _lettuce(2, 'pcs'),
      _tomato(1, 'pcs'),
      _cheese(2, 'pcs', label: 'Cheese slices'),
    ],
    staples: [
      Staple('Salt'),
      Staple('Pepper'),
      Staple('Tomato ketchup', 2, 'tbsp'),
    ],
    steps: [
      'Season the beef and shape into two patties slightly wider than the buns.',
      'Cook in a hot pan for 4 minutes a side, adding cheese at the end.',
      'Toast the buns cut-side down.',
      'Build the burgers with lettuce, tomato and ketchup.',
    ],
  ),

  // =========================== Mexican ===========================
  Recipe(
    id: 'chicken_quesadilla',
    name: 'Chicken Quesadilla',
    origin: 'Mexican',
    diet: Diet.meat,
    minutes: 20,
    servings: 2,
    ingredients: [
      _tortilla(4, 'pcs'),
      _chicken(200, 'g'),
      _cheese(100, 'g'),
      _bellPepper(1, 'pcs'),
    ],
    staples: [
      Staple('Chilli powder', 1, 'tsp'),
      Staple('Cooking oil', 1, 'tbsp'),
      Staple('Salt'),
    ],
    steps: [
      'Fry thin strips of chicken and pepper with chilli powder and salt.',
      'Scatter cheese and the filling over half of each tortilla and fold.',
      'Toast in a dry pan for 2 minutes a side until the cheese melts.',
      'Cut into wedges.',
    ],
  ),
  Recipe(
    id: 'burrito_bowl',
    name: 'Bean Burrito Bowl',
    origin: 'Mexican',
    diet: Diet.vegan,
    minutes: 25,
    servings: 2,
    ingredients: [
      _rice(300, 'g'),
      _beans(1, 'pack', label: 'Kidney or black beans'),
      _tomato(2, 'pcs'),
      _corn(100, 'g'),
      _lime(1, 'pcs'),
      _onion(1, 'pcs'),
    ],
    staples: [
      Staple('Ground cumin', 1, 'tsp'),
      Staple('Chilli powder', 1, 'tsp'),
      Staple('Olive oil', 1, 'tbsp'),
      Staple('Salt'),
    ],
    steps: [
      'Warm the beans with cumin, chilli powder and a splash of water.',
      'Dice the tomato and half the onion and mix with lime juice and salt.',
      'Char the corn in a dry pan.',
      'Serve the rice topped with beans, corn and the tomato salsa.',
    ],
  ),

  // ======================= Middle Eastern =======================
  Recipe(
    id: 'hummus',
    name: 'Hummus',
    origin: 'Middle Eastern',
    diet: Diet.vegan,
    minutes: 10,
    servings: 4,
    ingredients: [_chickpeas(400, 'g'), _lemon(1, 'pcs')],
    staples: [
      Staple('Tahini', 2, 'tbsp'),
      Staple('Garlic', 1, 'cloves'),
      Staple('Olive oil', 3, 'tbsp'),
      Staple('Ground cumin', 0.5, 'tsp'),
      Staple('Salt'),
    ],
    steps: [
      'Drain the chickpeas, keeping some of the liquid.',
      'Blend with tahini, garlic, lemon juice, cumin and salt.',
      'Add chickpea liquid a spoon at a time until smooth.',
      'Serve drizzled with olive oil.',
    ],
  ),
  Recipe(
    id: 'shakshuka',
    name: 'Shakshuka',
    origin: 'Middle Eastern',
    diet: Diet.vegetarian,
    minutes: 30,
    servings: 2,
    ingredients: [
      _egg(4, 'pcs'),
      _tomato(5, 'pcs'),
      _onion(1, 'pcs'),
      _bellPepper(1, 'pcs'),
    ],
    staples: [
      Staple('Garlic', 2, 'cloves'),
      Staple('Paprika', 1, 'tsp'),
      Staple('Ground cumin', 1, 'tsp'),
      Staple('Olive oil', 2, 'tbsp'),
      Staple('Salt'),
    ],
    steps: [
      'Soften the onion and pepper in olive oil, then add garlic and spices.',
      'Add the chopped tomatoes and simmer into a thick sauce.',
      'Make four wells and crack in the eggs.',
      'Cover and cook until the whites are set but the yolks are soft.',
    ],
  ),

  // =========================== French ===========================
  Recipe(
    id: 'french_omelette',
    name: 'French Omelette',
    origin: 'French',
    diet: Diet.vegetarian,
    minutes: 10,
    servings: 1,
    ingredients: [_egg(3, 'pcs'), _butter(15, 'g'), _cheese(30, 'g')],
    staples: [Staple('Salt'), Staple('Pepper')],
    steps: [
      'Beat the eggs well with salt and pepper.',
      'Melt the butter on medium heat and add the eggs.',
      'Stir quickly with a fork, then let the base set.',
      'Add grated cheese, roll the omelette and slide onto a plate.',
    ],
  ),
  Recipe(
    id: 'ratatouille',
    name: 'Ratatouille',
    origin: 'French',
    diet: Diet.vegan,
    minutes: 50,
    servings: 4,
    ingredients: [
      _eggplant(1, 'pcs'),
      _zucchini(1, 'pcs'),
      _bellPepper(2, 'pcs'),
      _tomato(4, 'pcs'),
      _onion(1, 'pcs'),
    ],
    staples: [
      Staple('Garlic', 3, 'cloves'),
      Staple('Olive oil', 4, 'tbsp'),
      Staple('Dried herbs', 1, 'tsp'),
      Staple('Salt'),
    ],
    steps: [
      'Cut all the vegetables into similar-sized chunks.',
      'Fry the onion, pepper and garlic in olive oil until soft.',
      'Add the eggplant and zucchini and cook for 10 minutes.',
      'Add the tomatoes and herbs, cover and simmer for 25 minutes.',
    ],
  ),
];

/// Every origin in the database, most recipes first, for the filter chips.
final List<String> recipeOrigins = () {
  final counts = <String, int>{};
  for (final r in recipeDatabase) {
    counts[r.origin] = (counts[r.origin] ?? 0) + 1;
  }
  final list = counts.keys.toList()
    ..sort((a, b) {
      final c = counts[b]!.compareTo(counts[a]!);
      return c != 0 ? c : a.compareTo(b);
    });
  return list;
}();
