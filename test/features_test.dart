import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:meal_app/data/dummy_data.dart';
import 'package:meal_app/main.dart';
import 'package:meal_app/models/meal.dart';
import 'package:meal_app/screens/auth_screen.dart';
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
}
