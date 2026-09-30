import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class MainDrawer extends StatelessWidget {
  const MainDrawer({super.key, required this.onSelectScreen, required this.isAdmin});

  final void Function(String identifier) onSelectScreen;
  final bool isAdmin;

  Widget _item(IconData icon, String title, String identifier) => ListTile(
        leading: Icon(icon, size: 26),
        title: Text(title, style: const TextStyle(fontSize: 20)),
        onTap: () => onSelectScreen(identifier),
      );

  @override
  Widget build(BuildContext context) {
    final email = FirebaseAuth.instance.currentUser?.email ?? '';
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primaryContainer,
                  Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.fastfood, size: 48, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cooking Up!',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      Text(email, overflow: TextOverflow.ellipsis),
                      if (isAdmin) const Text('Admin'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _item(Icons.restaurant, 'Meals', 'meals'),
          _item(Icons.settings, 'Filters', 'filters'),
          _item(Icons.receipt_long, 'My Orders', 'my-orders'),
          if (isAdmin) ...[
            const Divider(),
            _item(Icons.fact_check, 'Manage Orders', 'admin-orders'),
            _item(Icons.restaurant_menu, 'Manage Meals', 'admin-meals'),
            _item(Icons.sell, 'Manage Prices', 'admin-prices'),
          ],
          const Spacer(),
          _item(Icons.logout, 'Log out', 'logout'),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
