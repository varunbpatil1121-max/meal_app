import 'package:flutter/material.dart';
import 'package:meal_app/config.dart';
import 'package:meal_app/models/order.dart';

class OrderTile extends StatelessWidget {
  const OrderTile({
    super.key,
    required this.order,
    this.showCustomer = false,
    this.actions,
    this.onTap,
  });

  final MealOrder order;
  final bool showCustomer;
  final Widget? actions;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final label = order.status.label;
    final (color, icon) = switch (order.status) {
      OrderStatus.pending => (Colors.amber, Icons.hourglass_top),
      OrderStatus.confirmed => (Colors.green, Icons.check_circle),
      OrderStatus.cooking => (Colors.orange, Icons.soup_kitchen),
      OrderStatus.pickedUp => (Colors.orange, Icons.shopping_bag),
      OrderStatus.onTheWay => (Colors.lightBlue, Icons.delivery_dining),
      OrderStatus.delivered => (Colors.green, Icons.home),
      OrderStatus.rejected => (Colors.red, Icons.cancel),
    };
    final created = order.createdAt;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${order.quantity} × ${order.mealTitle}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Chip(
                    avatar: Icon(icon, color: color, size: 18),
                    label: Text(label),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              Text(
                'Total: $kCurrency${order.total}  ($kCurrency${order.unitPrice} each)',
              ),
              if (showCustomer) Text('Customer: ${order.userEmail}'),
              if (created != null)
                Text(
                  '${created.day}/${created.month}/${created.year} '
                  '${created.hour.toString().padLeft(2, '0')}:'
                  '${created.minute.toString().padLeft(2, '0')}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              if (actions != null) ...[const SizedBox(height: 8), actions!],
            ],
          ),
        ),
      ),
    );
  }
}
