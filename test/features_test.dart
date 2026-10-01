import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:meal_app/data/dummy_data.dart';
import 'package:meal_app/main.dart';
import 'package:meal_app/models/meal.dart';
import 'package:meal_app/screens/auth_screen.dart';
import 'package:meal_app/models/order.dart';
import 'package:meal_app/screens/order_tracker_screen.dart';
import 'package:meal_app/widgets/notification_banner.dart';

void main() {
  testWidgets('Sign-in screen offers User and Admin roles', (tester) async {
    await tester.pumpWidget(MaterialApp(theme: theme, home: const AuthScreen()));
    expect(find.text('New here? Create an account'), findsOneWidget);

    await tester.tap(find.byTooltip('Choose how to sign in'));
    await tester.pumpAndSettle();
    expect(find.text('User'), findsWidgets);
    expect(find.text('Admin'), findsOneWidget);

    await tester.tap(find.text('Admin'));
    await tester.pumpAndSettle();
    expect(find.text('Admin sign in'), findsOneWidget);
    // Admins can't sign up from the app.
    expect(find.text('New here? Create an account'), findsNothing);
  });

  testWidgets('Notification banner slides in and can be swiped away', (tester) async {
    final navKey = GlobalKey<NavigatorState>();
    var tapped = false;
    await tester.pumpWidget(MaterialApp(
      theme: theme,
      navigatorKey: navKey,
      home: const Scaffold(body: SizedBox.expand()),
    ));

    NotificationBanner.show(navKey.currentState!.overlay,
        title: 'Order confirmed!', body: 'Your meal is confirmed.', onTap: () => tapped = true);
    await tester.pumpAndSettle();
    expect(find.text('Order confirmed!'), findsOneWidget);

    await tester.drag(find.text('Order confirmed!'), const Offset(500, 0));
    await tester.pumpAndSettle();
    expect(find.text('Order confirmed!'), findsNothing);
    expect(tapped, isFalse);

    // A second banner auto-hides after a few seconds.
    NotificationBanner.show(navKey.currentState!.overlay, title: 'New order', body: 'x');
    await tester.pumpAndSettle();
    expect(find.text('New order'), findsOneWidget);
    await tester.pump(const Duration(seconds: 7));
    await tester.pumpAndSettle();
    expect(find.text('New order'), findsNothing);
  });

  test('Meal survives a save/load round trip', () {
    final meal = dummyMeals.first;
    final copy = Meal.fromMap(meal.id, meal.toMap());
    expect(copy, meal);
    expect(copy.title, meal.title);
    expect(copy.price, meal.price);
    expect(copy.steps, meal.steps);
    expect(copy.complexity, meal.complexity);
  });

  test('Orders move forward one step at a time', () {
    final chain = <OrderStatus>[];
    for (OrderStatus? s = OrderStatus.pending; s != null; s = s.next) {
      chain.add(s);
    }
    expect(chain, [
      OrderStatus.pending,
      OrderStatus.confirmed,
      OrderStatus.cooking,
      OrderStatus.pickedUp,
      OrderStatus.onTheWay,
      OrderStatus.delivered,
    ]);
    expect(OrderStatus.rejected.next, isNull);
  });

  testWidgets('Tracker only animates as far as the admin has confirmed', (tester) async {
    final orders = StreamController<MealOrder?>();
    MealOrder order(OrderStatus status) => MealOrder(
          id: 'o1',
          userId: 'u1',
          userEmail: 'a@b.c',
          mealId: dummyMeals.first.id,
          mealTitle: dummyMeals.first.title,
          quantity: 2,
          unitPrice: 199,
          total: 398,
          status: status,
          createdAt: DateTime(2026),
          notifiedStatus: status.name,
        );
    Future<void> wait(int seconds) async {
      for (var i = 0; i < seconds * 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    await tester.pumpWidget(MaterialApp(
      theme: theme,
      home: OrderTrackerScreen(orderId: 'o1', orderStream: orders.stream),
    ));

    orders.add(order(OrderStatus.pending));
    await wait(5);
    expect(find.text('Waiting for the restaurant'), findsOneWidget);

    orders.add(order(OrderStatus.confirmed));
    await wait(3);
    expect(find.text('Order confirmed!'), findsOneWidget);

    orders.add(order(OrderStatus.cooking));
    await wait(10); // the chef keeps cooking until the admin moves on
    expect(find.text('The chef is cooking'), findsOneWidget);

    orders.add(order(OrderStatus.pickedUp));
    await wait(4);
    expect(find.text('Rider picked up your order'), findsOneWidget);

    orders.add(order(OrderStatus.onTheWay));
    await wait(10); // the rider keeps riding until delivered
    expect(find.text('On the way to you'), findsOneWidget);
    expect(find.text('Replay'), findsNothing);

    orders.add(order(OrderStatus.delivered));
    await wait(8);
    expect(find.text('Delivered! Enjoy your meal'), findsOneWidget);
    expect(find.text('Replay'), findsOneWidget);

    await orders.close();
  });

  testWidgets('Tracker shows rejected orders', (tester) async {
    final orders = StreamController<MealOrder?>();
    await tester.pumpWidget(MaterialApp(
      theme: theme,
      home: OrderTrackerScreen(orderId: 'o1', orderStream: orders.stream),
    ));
    orders.add(MealOrder(
      id: 'o1',
      userId: 'u1',
      userEmail: 'a@b.c',
      mealId: 'm1',
      mealTitle: 'Spaghetti',
      quantity: 1,
      unitPrice: 199,
      total: 199,
      status: OrderStatus.rejected,
      createdAt: null,
      notifiedStatus: 'rejected',
    ));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Order rejected'), findsOneWidget);
    await orders.close();
  });
}
