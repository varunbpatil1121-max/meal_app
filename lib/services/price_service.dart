import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:meal_app/config.dart';
import 'package:meal_app/data/dummy_data.dart';
import 'package:meal_app/models/meal.dart';

/// Live meal prices from Firestore (`meal_prices/{mealId}` → `{price: int}`).
/// Falls back to the default price in dummy_data until a price is set.
class PriceService {
  static final _prices = FirebaseFirestore.instance.collection('${kCollectionPrefix}prices');
  static final ValueNotifier<Map<String, int>> prices = ValueNotifier({});
  static StreamSubscription? _sub;

  static void start() {
    _sub ??= _prices.snapshots().listen((snap) {
      prices.value = {
        for (final doc in snap.docs) doc.id: doc.data()['price'] as int,
      };
    });
  }

  static Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    prices.value = {};
  }

  static int priceOf(Meal meal) => prices.value[meal.id] ?? meal.price;

  static Future<void> setPrice(String mealId, int price) =>
      _prices.doc(mealId).set({'price': price});

  /// Writes the default price for any meal that has no price document yet.
  /// Orders are only accepted for meals with a price document, so this runs
  /// whenever an admin signs in.
  static Future<void> seedMissingPrices() async {
    final existing = await _prices.get();
    final ids = existing.docs.map((d) => d.id).toSet();
    final batch = FirebaseFirestore.instance.batch();
    var changed = false;
    for (final meal in dummyMeals) {
      if (ids.contains(meal.id)) continue;
      batch.set(_prices.doc(meal.id), {'price': meal.price});
      changed = true;
    }
    if (changed) await batch.commit();
  }
}
