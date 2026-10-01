import 'package:flutter/material.dart';
import 'package:meal_app/models/order.dart';
import 'package:meal_app/services/order_service.dart';
import 'package:meal_app/widgets/order_tile.dart';

class AdminOrdersScreen extends StatefulWidget {
  const AdminOrdersScreen({super.key});

  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> {
  final _stream = OrderService.watchAllOrders();
  var _activeOnly = true;

  Future<void> _setStatus(MealOrder order, OrderStatus status) async {
    try {
      await OrderService.setStatus(order.id, status);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not update order: $e')));
    }
  }

  /// One button to move the order to its next step; pending orders can also
  /// be rejected.
  Widget? _nextStepButtons(MealOrder order) {
    final next = order.status.next;
    if (next == null) return null;
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (order.status == OrderStatus.pending) ...[
          TextButton.icon(
            onPressed: () => _setStatus(order, OrderStatus.rejected),
            icon: const Icon(Icons.close),
            label: const Text('Reject'),
          ),
          const SizedBox(width: 8),
        ],
        FilledButton.icon(
          onPressed: () => _setStatus(order, next),
          icon: Icon(switch (next) {
            OrderStatus.confirmed => Icons.check,
            OrderStatus.cooking => Icons.soup_kitchen,
            OrderStatus.pickedUp => Icons.shopping_bag,
            OrderStatus.onTheWay => Icons.delivery_dining,
            _ => Icons.home,
          }),
          label: Text(next.actionLabel),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Orders'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilterChip(
              label: const Text('Active only'),
              selected: _activeOnly,
              onSelected: (value) => setState(() { _activeOnly = value; }),
            ),
          ),
        ],
      ),
      body: StreamBuilder(
        stream: _stream,
        builder: (ctx, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Could not load orders: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final orders = _activeOnly
              ? snapshot.data!.where((o) => o.status.isActive).toList()
              : snapshot.data!;
          if (orders.isEmpty) {
            return Center(
              child: Text(_activeOnly ? 'No active orders.' : 'No orders yet.'),
            );
          }
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              for (final order in orders)
                OrderTile(
                  order: order,
                  showCustomer: true,
                  actions: _nextStepButtons(order),
                ),
            ],
          );
        },
      ),
    );
  }
}
