// Favourite recipes, stored per user in Firestore as
// users/{uid}/favourites/{recipeId} so they follow the user across devices.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

CollectionReference<Map<String, dynamic>> _favCol() {
  final uid = FirebaseAuth.instance.currentUser!.uid;
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('favourites');
}

/// Live set of favourite recipe ids.
Stream<Set<String>> favouriteIds() =>
    _favCol().snapshots().map((s) => s.docs.map((d) => d.id).toSet());

/// Adds or removes a favourite.
Future<void> setFavourite(String recipeId, bool favourite) => favourite
    ? _favCol().doc(recipeId).set({'addedAt': FieldValue.serverTimestamp()})
    : _favCol().doc(recipeId).delete();

/// Heart button that toggles a recipe's favourite state and confirms with a
/// short message (with Undo when removing).
class FavouriteButton extends StatelessWidget {
  final String recipeId;
  final String recipeName;
  final bool isFavourite;
  final bool compact;

  const FavouriteButton({
    super.key,
    required this.recipeId,
    required this.recipeName,
    required this.isFavourite,
    this.compact = false,
  });

  Future<void> _toggle(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final next = !isFavourite;
    try {
      await setFavourite(recipeId, next);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          duration: const Duration(seconds: 2),
          content: Text(next
              ? 'Added $recipeName to favourites'
              : 'Removed $recipeName from favourites'),
          action: next
              ? null
              : SnackBarAction(
                  label: 'Undo',
                  onPressed: () => setFavourite(recipeId, true),
                ),
        ));
    } catch (e) {
      messenger.showSnackBar(
          SnackBar(content: Text('Could not update favourites: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      visualDensity: compact ? VisualDensity.compact : null,
      tooltip: isFavourite ? 'Remove from favourites' : 'Add to favourites',
      isSelected: isFavourite,
      icon: const Icon(Icons.favorite_border),
      selectedIcon: Icon(Icons.favorite, color: Colors.red.shade400),
      onPressed: () => _toggle(context),
    );
  }
}
