import 'package:flutter/material.dart';
import 'package:meal_app/models/meal.dart';
import 'package:meal_app/screens/add_meal_screen.dart';
import 'package:meal_app/services/meal_service.dart';
import 'package:meal_app/widgets/price_tag.dart';

class AdminMealsScreen extends StatelessWidget {
  const AdminMealsScreen({super.key});

  Future<bool> _confirmDelete(BuildContext context, Meal meal) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete meal?'),
        content: Text('"${meal.title}" will be removed for everyone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return false;

    try {
      await MealService.deleteMeal(meal);
      return true;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not delete meal: $e')));
      }
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Meals')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (ctx) => const AddMealScreen())),
        icon: const Icon(Icons.add),
        label: const Text('Add meal'),
      ),
      body: ValueListenableBuilder(
        valueListenable: MealService.meals,
        builder: (ctx, meals, _) => ListView(
          padding: const EdgeInsets.only(bottom: 88),
          children: [
            for (final meal in meals)
              MealService.isAddedByAdmin(meal)
                  ? Dismissible(
                      key: ValueKey(meal.id),
                      direction: DismissDirection.endToStart,
                      confirmDismiss: (_) => _confirmDelete(context, meal),
                      background: Container(
                        color: Colors.red.shade700,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 24),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      child: _MealTile(
                        meal: meal,
                        trailing: IconButton(
                          tooltip: 'Delete',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _confirmDelete(context, meal),
                        ),
                      ),
                    )
                  : _MealTile(meal: meal, trailing: const Text('Built-in')),
          ],
        ),
      ),
    );
  }
}

class _MealTile extends StatelessWidget {
  const _MealTile({required this.meal, required this.trailing});

  final Meal meal;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          meal.imageUrl,
          width: 56,
          height: 56,
          fit: BoxFit.cover,
          errorBuilder: (ctx, error, stackTrace) =>
              const SizedBox(width: 56, height: 56, child: Icon(Icons.broken_image)),
        ),
      ),
      title: Text(meal.title),
      subtitle: PriceTag(meal: meal),
      trailing: trailing,
    );
  }
}
