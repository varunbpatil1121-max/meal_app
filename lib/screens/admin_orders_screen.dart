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
  var _pendingOnly = true;

  Future<void> _setStatus(MealOrder order, OrderStatus status) async {
    try {
      await OrderService.setStatus(order.id, status);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not update order: $e')));
    }
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
              label: const Text('Pending only'),
              selected: _pendingOnly,
              onSelected: (value) => setState(() { _pendingOnly = value; }),
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
          final orders = _pendingOnly
              ? snapshot.data!.where((o) => o.status == OrderStatus.pending).toList()
              : snapshot.data!;
          if (orders.isEmpty) {
            return Center(
              child: Text(_pendingOnly ? 'No pending orders.' : 'No orders yet.'),
            );
          }
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              for (final order in orders)
                OrderTile(
                  order: order,
                  showCustomer: true,
                  actions: order.status != OrderStatus.pending
                      ? null
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton.icon(
                              onPressed: () => _setStatus(order, OrderStatus.rejected),
                              icon: const Icon(Icons.close),
                              label: const Text('Reject'),
                            ),
                            const SizedBox(width: 8),
                            FilledButton.icon(
                              onPressed: () => _setStatus(order, OrderStatus.confirmed),
                              icon: const Icon(Icons.check),
                              label: const Text('Confirm'),
                            ),
                          ],
                        ),
                ),
            ],
          );
        },
      ),
    );
  }
}
