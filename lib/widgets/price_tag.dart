import 'package:flutter/material.dart';
import 'package:meal_app/config.dart';
import 'package:meal_app/models/meal.dart';
import 'package:meal_app/services/price_service.dart';

/// Shows a meal's current price and updates live when an admin changes it.
class PriceTag extends StatelessWidget {
  const PriceTag({super.key, required this.meal, this.style});

  final Meal meal;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: PriceService.prices,
      builder: (ctx, _, _) =>
          Text('$kCurrency${PriceService.priceOf(meal)}', style: style),
    );
  }
}
