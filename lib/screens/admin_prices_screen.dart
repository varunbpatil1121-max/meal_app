import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:meal_app/config.dart';
import 'package:meal_app/models/meal.dart';
import 'package:meal_app/services/meal_service.dart';
import 'package:meal_app/services/price_service.dart';
import 'package:meal_app/widgets/price_tag.dart';

class AdminPricesScreen extends StatelessWidget {
  const AdminPricesScreen({super.key});

  Future<void> _editPrice(BuildContext context, Meal meal) async {
    final controller =
        TextEditingController(text: PriceService.priceOf(meal).toString());
    final newPrice = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(meal.title),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(prefixText: kCurrency, labelText: 'New price'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final value = int.tryParse(controller.text);
              if (value != null && value > 0) Navigator.pop(ctx, value);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (newPrice == null) return;

    try {
      await PriceService.setPrice(meal.id, newPrice);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${meal.title} is now $kCurrency$newPrice')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not save price: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Prices')),
      body: ValueListenableBuilder(
        valueListenable: MealService.meals,
        builder: (ctx, meals, _) => ListView(
          children: [
            for (final meal in meals)
              ListTile(
                title: Text(meal.title),
                subtitle: PriceTag(meal: meal),
                trailing: const Icon(Icons.edit),
                onTap: () => _editPrice(context, meal),
              ),
          ],
        ),
      ),
    );
  }
}
