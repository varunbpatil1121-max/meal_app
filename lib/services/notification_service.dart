import 'dart:async';

import 'package:flutter/material.dart';
import 'package:meal_app/config.dart';
import 'package:meal_app/models/order.dart';
import 'package:meal_app/screens/admin_orders_screen.dart';
import 'package:meal_app/screens/my_orders_screen.dart';
import 'package:meal_app/services/order_service.dart';
import 'package:meal_app/widgets/notification_banner.dart';

/// Let the app show messages and open screens from anywhere.
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
final navigatorKey = GlobalKey<NavigatorState>();

/// In-app order notifications, driven by live Firestore updates:
/// - customers get a popup when an admin confirms or rejects their order
///   (shown the next time they open the app if they weren't in it), and
/// - admins get a popup whenever a new order comes in.
class NotificationService {
  static StreamSubscription? _userSub;
  static StreamSubscription? _adminSub;
  static final _shownToUser = <String>{};

  static void startForUser(String uid) {
    _userSub ??= OrderService.watchMyOrders(uid).listen((orders) {
      for (final order in orders.reversed) {
        if (order.status == OrderStatus.pending || order.userNotified) continue;
        if (!_shownToUser.add(order.id)) continue;

        final confirmed = order.status == OrderStatus.confirmed;
        _show(
          confirmed ? 'Order confirmed! 🎉' : 'Order rejected',
          confirmed
              ? 'Your ${order.quantity} × ${order.mealTitle} ($kCurrency${order.total}) is confirmed.'
              : 'Sorry, your order for ${order.mealTitle} was rejected.',
          const MyOrdersScreen(),
          icon: confirmed ? Icons.check_circle : Icons.cancel,
          color: confirmed ? Colors.green : Colors.red,
        );
        OrderService.markUserNotified(order.id);
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
