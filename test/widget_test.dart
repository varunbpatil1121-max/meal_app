import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:meal_app/main.dart';
import 'package:meal_app/screens/tabs_screen.dart';

void main() {
  testWidgets('Starring a meal adds it to Favorites', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(theme: theme, home: const TabsScreen()));

    await tester.tap(find.text('Hamburgers'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Classic Hamburger'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.star_border));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.star), findsOneWidget);
    expect(find.text('₹249'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Favorites'));
    await tester.pumpAndSettle();

    expect(find.text('Classic Hamburger'), findsOneWidget);
  });
}
