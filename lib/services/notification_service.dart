import 'dart:async';

import 'package:flutter/material.dart';
import 'package:meal_app/config.dart';
import 'package:meal_app/models/order.dart';
import 'package:meal_app/screens/admin_orders_screen.dart';
import 'package:meal_app/screens/order_tracker_screen.dart';
import 'package:meal_app/services/order_service.dart';
import 'package:meal_app/widgets/notification_banner.dart';

/// Let the app show messages and open screens from anywhere.
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
final navigatorKey = GlobalKey<NavigatorState>();

/// In-app order notifications, driven by live Firestore updates:
/// - customers get a popup each time an admin moves their order to the next
///   step (shown the next time they open the app if they weren't in it), and
/// - admins get a popup whenever a new order comes in.
class NotificationService {
  static StreamSubscription? _userSub;
  static StreamSubscription? _adminSub;
  static final _shownToUser = <String>{};

  /// The order whose tracker is on screen; its updates need no popup.
  static String? visibleOrderId;

  static void startForUser(String uid) {
    _userSub ??= OrderService.watchMyOrders(uid).listen((orders) {
      for (final order in orders.reversed) {
        final status = order.status;
        if (status == OrderStatus.pending || order.notifiedStatus == status.name) continue;
        if (!_shownToUser.add('${order.id}:${status.name}')) continue;
        OrderService.markUserNotified(order.id, status);
        if (order.id == visibleOrderId) continue;

        final meal = order.mealTitle;
        final (title, body, icon, color) = switch (status) {
          OrderStatus.confirmed => ('Order confirmed! ✅', 'Your $meal is confirmed.', Icons.check_circle, Colors.green),
          OrderStatus.cooking => ('Cooking now 🧑‍🍳', 'The chef has started on your $meal.', Icons.soup_kitchen, Colors.orange),
          OrderStatus.pickedUp => ('Picked up 🛍️', 'A rider has collected your $meal.', Icons.shopping_bag, Colors.orange),
          OrderStatus.onTheWay => ('On the way 🛵', 'Your $meal is on its way to you.', Icons.delivery_dining, Colors.blue),
          OrderStatus.delivered => ('Delivered! 😋', 'Enjoy your $meal ($kCurrency${order.total}).', Icons.home, Colors.green),
          _ => ('Order rejected', 'Sorry, your order for $meal was rejected.', Icons.cancel, Colors.red),
        };
        _show(title, '$body Tap to watch.', OrderTrackerScreen(orderId: order.id), icon: icon, color: color);
      }
    });
  }

  static void startForAdmin() {
    Set<String>? knownIds;
    _adminSub ??= OrderService.watchAllOrders().listen((orders) {
      final ids = orders.map((o) => o.id).toSet();
      // The first update is the existing orders; only announce later ones.
      if (knownIds != null) {
        for (final order in orders) {
          if (knownIds!.contains(order.id) || order.status != OrderStatus.pending) continue;
          _show(
            'New order',
            '${order.userEmail} ordered ${order.quantity} × ${order.mealTitle} '
                '($kCurrency${order.total})',
            const AdminOrdersScreen(),
            icon: Icons.shopping_bag,
          );
        }
      }
      knownIds = ids;
    });
  }

  static Future<void> stopAdmin() async {
    await _adminSub?.cancel();
    _adminSub = null;
  }

  static Future<void> stop() async {
    await _userSub?.cancel();
    _userSub = null;
    _shownToUser.clear();
    await stopAdmin();
  }

  static void _show(String title, String body, Widget screen,
      {IconData icon = Icons.notifications, Color color = Colors.orange}) {
    NotificationBanner.show(
      navigatorKey.currentState?.overlay,
      title: title,
      body: body,
      icon: icon,
      color: color,
      onTap: () => navigatorKey.currentState
          ?.push(MaterialPageRoute(builder: (ctx) => screen)),
    );
  }
}
