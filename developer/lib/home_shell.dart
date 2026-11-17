import 'package:flutter/material.dart';

import 'grocery_screen.dart';
import 'inventory_screen.dart';
import 'meal_screen.dart';
import 'notification_service.dart';
import 'profile.dart';
import 'theme.dart';

/// Signed-in home: bottom navigation between the fridge, meal ideas and the
/// grocery list.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  late final Stream<int> _toBuy = groceryToBuyCount();

  @override
  void initState() {
    super.initState();
    NotificationService.openItem.addListener(_openFromNotification);
    // Use the reminder time saved on the profile.
    applySavedReminderTime();
    // A reminder may have launched the app before this screen existed.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _openFromNotification(),
    );
  }

  @override
  void dispose() {
    NotificationService.openItem.removeListener(_openFromNotification);
    super.dispose();
  }

  /// Tapping an expiry reminder opens recipes that use that item.
  void _openFromNotification() {
    final item = NotificationService.openItem.value;
    if (item == null || !mounted) return;
    NotificationService.openItem.value = null;
    setState(() => _index = 1); // Meals tab underneath
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => IngredientRecipesScreen(itemName: item),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack keeps each tab's state (and Firestore stream) alive.
      body: IndexedStack(
        index: _index,
        children: const [InventoryScreen(), MealScreen(), GroceryScreen()],
      ),
      // Floating pill navigation (design C · Shelves).
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: StreamBuilder<int>(
          stream: _toBuy,
          builder: (context, snap) {
            final count = snap.data ?? 0;
            return Container(
              height: 68,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: context.palette.hero,
                borderRadius: BorderRadius.circular(34),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x4012332D),
                    blurRadius: 24,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _NavItem(
                    icon: Icons.kitchen_outlined,
                    activeIcon: Icons.kitchen,
                    label: 'Fridge',
                    active: _index == 0,
                    onTap: () => setState(() => _index = 0),
                  ),
                  _NavItem(
                    icon: Icons.restaurant_menu_outlined,
                    activeIcon: Icons.restaurant_menu,
                    label: 'Meals',
                    active: _index == 1,
                    onTap: () => setState(() => _index = 1),
                  ),
                  _NavItem(
                    icon: Icons.shopping_cart_outlined,
                    activeIcon: Icons.shopping_cart,
                    label: 'Groceries',
                    badge: count,
                    active: _index == 2,
                    onTap: () => setState(() => _index = 2),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// One tab in the pill bar: an icon, which grows into a leaf-green pill
/// with its label when active.
class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool active;
  final int badge;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.active,
    required this.onTap,
    this.badge = 0,
  });

  @override
  Widget build(BuildContext context) {
    final iconWidget = Badge(
      isLabelVisible: badge > 0,
      label: Text('$badge'),
      backgroundColor: urgentSoft,
      textColor: brandForest,
      child: Icon(
        active ? activeIcon : icon,
        color: active ? inkOnLeaf : forestLight,
      ),
    );
    return Semantics(
      button: true,
      selected: active,
      label: badge > 0 ? '$label, $badge to buy' : label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(26),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          height: 52,
          constraints: const BoxConstraints(minWidth: 52),
          padding: EdgeInsets.symmetric(horizontal: active ? 18 : 14),
          decoration: BoxDecoration(
            color: active ? brandLeaf : Colors.transparent,
            borderRadius: BorderRadius.circular(26),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              iconWidget,
              if (active) ...[
                const SizedBox(width: 8),
                Text(
                  label,
                  style: appFont(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: inkOnLeaf,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
