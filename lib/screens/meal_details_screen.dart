import 'package:flutter/material.dart';
import 'package:meal_app/config.dart';
import 'package:meal_app/models/meal.dart';
import 'package:meal_app/screens/order_journey_screen.dart';
import 'package:meal_app/services/order_service.dart';
import 'package:meal_app/services/price_service.dart';
import 'package:meal_app/widgets/price_tag.dart';

class MealDetailsScreen extends StatefulWidget {
  const MealDetailsScreen({
    super.key,
    required this.meal,
    required this.onToggleFavorite,
    required this.initiallyFavorite,
  });

  final Meal meal;
  final void Function(Meal meal) onToggleFavorite;
  final bool initiallyFavorite;

  @override
  State<MealDetailsScreen> createState() => _MealDetailsScreenState();
}

class _MealDetailsScreenState extends State<MealDetailsScreen> {
  late var _isFavorite = widget.initiallyFavorite;

  void _toggleFavorite() {
    widget.onToggleFavorite(widget.meal);
    setState(() { _isFavorite = !_isFavorite; });
  }

  Future<void> _openOrderSheet() async {
    final quantity = await showModalBottomSheet<int>(
      context: context,
      builder: (ctx) => _OrderSheet(meal: widget.meal),
    );
    if (quantity == null || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final total = await OrderService.placeOrder(widget.meal, quantity);
      navigator.push(MaterialPageRoute(
        builder: (ctx) => OrderJourneyScreen(meal: widget.meal, quantity: quantity, total: total),
      ));
    } catch (e) {
      messenger
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text('Could not place order: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final meal = widget.meal;
    return Scaffold(
      appBar: AppBar(
        title: Text(meal.title),
        actions: [
          IconButton(
            onPressed: _toggleFavorite,
            icon: Icon(_isFavorite ? Icons.star : Icons.star_border),
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Image.network(
              meal.imageUrl,
              height: 300,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (ctx, error, stackTrace) => const SizedBox(
                height: 300,
                child: Center(child: Icon(Icons.broken_image, size: 64)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Row(
                children: [
                  PriceTag(
                    meal: meal,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: _openOrderSheet,
                    icon: const Icon(Icons.shopping_bag),
                    label: const Text('Order'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Text('Ingredients', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.orange)),
            const SizedBox(height: 14),
            for (final ingredient in meal.ingredients) Text(ingredient, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 24),
            const Text('Steps', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.orange)),
            const SizedBox(height: 14),
            for (final step in meal.steps) Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Text(step, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet for choosing a quantity. Pops with the chosen quantity.
class _OrderSheet extends StatefulWidget {
  const _OrderSheet({required this.meal});

  final Meal meal;

  @override
  State<_OrderSheet> createState() => _OrderSheetState();
}

class _OrderSheetState extends State<_OrderSheet> {
  static const _maxQuantity = 20;
  var _quantity = 1;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ValueListenableBuilder(
          valueListenable: PriceService.prices,
          builder: (ctx, _, _) {
            final price = PriceService.priceOf(widget.meal);
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(widget.meal.title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text('$kCurrency$price each'),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton.outlined(
                      onPressed: _quantity > 1 ? () => setState(() { _quantity--; }) : null,
                      icon: const Icon(Icons.remove),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text('$_quantity', style: Theme.of(context).textTheme.headlineMedium),
                    ),
                    IconButton.outlined(
                      onPressed: _quantity < _maxQuantity
                          ? () => setState(() { _quantity++; })
                          : null,
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, _quantity),
                    child: Text('Place order · $kCurrency${price * _quantity}'),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
