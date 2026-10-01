import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:meal_app/screens/order_tracker_screen.dart';
import 'package:meal_app/services/order_service.dart';
import 'package:meal_app/widgets/order_tile.dart';

class MyOrdersScreen extends StatelessWidget {
  const MyOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return Scaffold(
      appBar: AppBar(title: const Text('My Orders')),
      body: StreamBuilder(
        stream: OrderService.watchMyOrders(uid),
        builder: (ctx, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Could not load orders: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final orders = snapshot.data!;
          if (orders.isEmpty) {
            return const Center(child: Text('No orders yet. Open a meal and tap "Order".'));
          }
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              for (final order in orders)
                OrderTile(
                  order: order,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (ctx) => OrderTrackerScreen(orderId: order.id),
                  )),
                ),
            ],
          );
        },
      ),
    );
  }
}
